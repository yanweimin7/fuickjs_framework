import { useCallback, useEffect, useReducer } from 'react';
import { i18n, type InterpolationParams, type TranslateOptions } from './i18n';

export interface UseTranslationResult {
  /** 翻译函数，语言变更时引用稳定但结果实时。 */
  t: (key: string, params?: InterpolationParams, options?: TranslateOptions) => string;
  /** 当前语言（归一化后）。 */
  locale: string;
  /** 切换语言，触发使用该 hook 的组件重渲染。 */
  setLocale: (locale: string) => void;
  /** 已注册资源的语言列表。 */
  locales: string[];
}

/**
 * 订阅语言变更的翻译 hook。语言切换时，所有使用该 hook 的组件自动重渲染。
 *
 * @example
 * function Title() {
 *   const { t, setLocale } = useTranslation();
 *   return <Text text={t('home.title')} onTap={() => setLocale('zh-CN')} />;
 * }
 */
export function useTranslation(): UseTranslationResult {
  const [, forceUpdate] = useReducer((c: number) => c + 1, 0);

  useEffect(() => i18n.subscribe(() => forceUpdate()), []);

  const t = useCallback(
    (key: string, params?: InterpolationParams, options?: TranslateOptions) => i18n.t(key, params, options),
    [],
  );

  return {
    t,
    locale: i18n.getLocale(),
    setLocale: (locale: string) => i18n.setLocale(locale),
    locales: i18n.getAvailableLocales(),
  };
}

/**
 * 仅关心当前语言与切换语言时使用。
 * @returns `[locale, setLocale]`
 */
export function useLocale(): [string, (locale: string) => void] {
  const [, forceUpdate] = useReducer((c: number) => c + 1, 0);

  useEffect(() => i18n.subscribe(() => forceUpdate()), []);

  return [i18n.getLocale(), (locale: string) => i18n.setLocale(locale)];
}
