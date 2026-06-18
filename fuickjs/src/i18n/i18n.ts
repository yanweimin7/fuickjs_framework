import { DeviceInfoService } from '../services/DeviceInfoService';
import { LocalStorageService } from '../services/LocalStorageService';
import { NativeEvent } from '../runtime/NativeEvent';

/** 翻译资源的值：字符串，或用于复数/嵌套的对象。 */
export type TranslationValue = string | { [key: string]: TranslationValue };

/** 单个语言的资源树，支持点号路径嵌套。 */
export type TranslationResources = { [key: string]: TranslationValue };

/** 插值变量，形如 `t('hello', { name: 'Tom' })` 替换 `{name}`。 */
export type InterpolationParams = Record<string, string | number | boolean | null | undefined>;

export interface I18nConfigureOptions {
  /** 资源表：`{ 'en': {...}, 'zh-CN': {...} }`。locale 不区分大小写、`_`/`-` 等价。 */
  resources?: Record<string, TranslationResources>;
  /** 初始语言。不传则等待 `init()` 从持久化/系统语言推断，再回退到 `fallbackLocale`。 */
  locale?: string;
  /** 兜底语言，找不到 key 时按此语言再查一次。默认 `'en'`。 */
  fallbackLocale?: string;
  /** 是否把用户选择的语言持久化到 LocalStorage。默认 `true`。 */
  persist?: boolean;
  /** 持久化存储的 key。默认 `'fuickjs.locale'`。 */
  persistKey?: string;
  /** 缺失 key 时的回调，便于上报。 */
  missingKeyHandler?: (locale: string, key: string) => void;
}

export interface TranslateOptions {
  /** 复数计数，配合 `{ one, other, zero, ... }` 形式的资源使用。 */
  count?: number;
  /** key 缺失时的兜底文案，优先级高于「返回 key 本身」。 */
  defaultValue?: string;
  /** 本次翻译临时使用的语言，覆盖当前语言。 */
  locale?: string;
}

type Listener = (locale: string) => void;

/** locale 变更事件名，Native 侧可通过 NativeEventService 监听。 */
export const LOCALE_CHANGED_EVENT = 'localeChanged';

const DEFAULT_PERSIST_KEY = 'fuickjs.locale';

/** 归一化 locale：小写、`_` 转 `-`，去除空白。`zh_CN` 与 `zh-cn` 视为同一语言。 */
function normalizeLocale(locale: string): string {
  return locale.trim().toLowerCase().replace(/_/g, '-');
}

/** 取语言主码：`zh-cn` → `zh`。 */
function languageOf(locale: string): string {
  return normalizeLocale(locale).split('-')[0];
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 深合并资源树，已有 key 被新值覆盖。 */
function deepMerge(target: TranslationResources, source: TranslationResources): TranslationResources {
  for (const key of Object.keys(source)) {
    const next = source[key];
    const prev = target[key];
    if (isPlainObject(next) && isPlainObject(prev)) {
      deepMerge(prev as TranslationResources, next as TranslationResources);
    } else {
      target[key] = next;
    }
  }
  return target;
}

/** 按点号路径在资源树中取值。 */
function resolvePath(tree: TranslationResources | undefined, key: string): TranslationValue | undefined {
  if (!tree) return undefined;
  if (Object.prototype.hasOwnProperty.call(tree, key)) return tree[key];
  let cur: TranslationValue | undefined = tree;
  for (const part of key.split('.')) {
    if (!isPlainObject(cur)) return undefined;
    cur = (cur as TranslationResources)[part];
    if (cur === undefined) return undefined;
  }
  return cur;
}

/** 依据 count 选择复数类别。仅做 en 风格的 one/other 区分，外加显式 zero。 */
function pluralCategory(count: number): 'zero' | 'one' | 'other' {
  if (count === 0) return 'zero';
  if (count === 1) return 'one';
  return 'other';
}

/** 用 `{name}` 占位语法做插值。 */
function interpolate(template: string, params?: InterpolationParams): string {
  if (!params) return template;
  return template.replace(/\{(\w+)\}/g, (match, name: string) => {
    const value = params[name];
    return value === undefined || value === null ? match : String(value);
  });
}

class I18n {
  private resources: Record<string, TranslationResources> = {};
  private locale = 'en';
  private fallbackLocale = 'en';
  private persist = true;
  private persistKey = DEFAULT_PERSIST_KEY;
  private missingKeyHandler?: (locale: string, key: string) => void;
  private listeners = new Set<Listener>();
  private initialized = false;

  /**
   * 配置 i18n。可重复调用，资源会累积合并。
   * 通常在 App 入口同步调用一次，再 `await i18n.init()` 推断系统/持久化语言。
   */
  configure(options: I18nConfigureOptions): void {
    if (options.fallbackLocale) this.fallbackLocale = normalizeLocale(options.fallbackLocale);
    if (options.persist !== undefined) this.persist = options.persist;
    if (options.persistKey) this.persistKey = options.persistKey;
    if (options.missingKeyHandler) this.missingKeyHandler = options.missingKeyHandler;
    if (options.resources) {
      for (const [loc, res] of Object.entries(options.resources)) {
        this.addResources(loc, res);
      }
    }
    if (options.locale) {
      this.setLocale(options.locale, { persist: false, silent: !this.initialized });
    }
  }

  /** 追加/合并某语言的资源。 */
  addResources(locale: string, resources: TranslationResources): void {
    const key = normalizeLocale(locale);
    if (!this.resources[key]) this.resources[key] = {};
    deepMerge(this.resources[key], resources);
  }

  /**
   * 初始化当前语言：优先持久化偏好 → 系统语言 → 已配置 locale/fallback。
   * 依赖 Native 服务，故为异步。重复调用安全。
   */
  async init(): Promise<string> {
    try {
      if (this.persist) {
        const saved = await LocalStorageService.getItem(this.persistKey);
        if (saved && this.hasLocale(saved)) {
          this.applyLocale(saved);
          this.initialized = true;
          this.notify();
          return this.locale;
        }
      }
      const info = await DeviceInfoService.getDeviceInfo();
      const system = info?.locale;
      if (system && this.hasLocale(system)) {
        this.applyLocale(system);
      }
    } catch {
      // 取系统语言失败时静默保持当前 locale，不阻塞渲染。
    }
    this.initialized = true;
    this.notify();
    return this.locale;
  }

  /** 当前生效的语言（归一化后）。 */
  getLocale(): string {
    return this.locale;
  }

  /** 已注册资源的语言列表。 */
  getAvailableLocales(): string[] {
    return Object.keys(this.resources);
  }

  /** 是否存在该语言（精确或语言主码）的资源。 */
  hasLocale(locale: string): boolean {
    const norm = normalizeLocale(locale);
    if (this.resources[norm]) return true;
    return Boolean(this.resources[languageOf(norm)]);
  }

  /**
   * 切换语言，触发所有订阅者（含 React 组件）重渲染，
   * 并通过 NativeEvent 广播 `localeChanged` 给 Native 侧。
   */
  setLocale(locale: string, options?: { persist?: boolean; silent?: boolean }): void {
    const norm = normalizeLocale(locale);
    if (norm === this.locale && this.initialized) return;
    this.applyLocale(locale);

    const shouldPersist = options?.persist ?? this.persist;
    if (shouldPersist) {
      LocalStorageService.setItem(this.persistKey, this.locale).catch(() => {
        /* 持久化失败不影响切换 */
      });
    }
    if (!options?.silent) {
      this.notify();
      NativeEvent.emit(LOCALE_CHANGED_EVENT, { locale: this.locale });
    }
  }

  /**
   * 翻译。
   * @example t('greeting', { name: 'Tom' })
   * @example t('items', { count: 3 }, { count: 3 })  // 复数
   */
  t(key: string, params?: InterpolationParams, options?: TranslateOptions): string {
    const targetLocale = options?.locale ? normalizeLocale(options.locale) : this.locale;
    const count = options?.count ?? (typeof params?.count === 'number' ? (params.count as number) : undefined);

    const raw = this.lookup(targetLocale, key, count) ?? this.lookup(this.fallbackLocale, key, count);

    if (raw === undefined) {
      this.missingKeyHandler?.(targetLocale, key);
      return interpolate(options?.defaultValue ?? key, params);
    }
    return interpolate(raw, params);
  }

  /** 订阅语言变更，返回取消函数。 */
  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private applyLocale(locale: string): void {
    this.locale = normalizeLocale(locale);
  }

  private notify(): void {
    for (const listener of [...this.listeners]) {
      try {
        listener(this.locale);
      } catch (e) {
        console.error('[i18n] listener error:', e);
      }
    }
  }

  /** 在指定语言里查找 key，命中后做复数选择。语言主码作为二级回退。 */
  private lookup(locale: string, key: string, count?: number): string | undefined {
    const norm = normalizeLocale(locale);
    const candidates = norm === languageOf(norm) ? [norm] : [norm, languageOf(norm)];
    for (const cand of candidates) {
      const value = resolvePath(this.resources[cand], key);
      const resolved = this.selectValue(value, count);
      if (resolved !== undefined) return resolved;
    }
    return undefined;
  }

  /** 把资源值收敛为字符串：字符串直接用；对象按复数类别取。 */
  private selectValue(value: TranslationValue | undefined, count?: number): string | undefined {
    if (typeof value === 'string') return value;
    if (isPlainObject(value) && count !== undefined) {
      const category = pluralCategory(count);
      const picked = value[category] ?? value.other;
      if (typeof picked === 'string') return picked;
    }
    return undefined;
  }
}

/** 全局唯一 i18n 实例。 */
export const i18n = new I18n();

/** 绑定到实例的便捷翻译函数，可直接解构使用：`import { t } from 'fuickjs'`。 */
export function t(key: string, params?: InterpolationParams, options?: TranslateOptions): string {
  return i18n.t(key, params, options);
}

export type { I18n };
