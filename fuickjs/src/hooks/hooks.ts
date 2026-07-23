import React, { useContext, useEffect, useState, useRef } from 'react';
import { PageContext } from '../core/PageContext';
import * as PageRender from '../core/page_render';
import * as Router from '../router/router';
import type { RouteLocation } from '../router/router';

import { NavigatorService } from '../services/NavigatorService';
import { NativeEvent } from '../runtime/NativeEvent';
import { LifecycleService } from '../services/LifecycleService';
import { UIService } from '../services/UIService';

export function usePageId() {
  const { pageId } = useContext(PageContext);
  return pageId;
}

export function useNavigator() {
  const pageId = usePageId();
  return {
    /**
     * 跳转，等待目标页面 pop(result) 后返回。
     * 守卫拒绝时 resolve 为 null。
     */
    push: (path: string, params?: unknown, rootNavigator?: boolean, prewarmMs?: number) =>
      NavigatorService.push(path, params, pageId, rootNavigator, prewarmMs),
    /** @deprecated push 本身已等待返回；保留为别名。 */
    pushAndWait: (path: string, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.pushAndWait(path, params, pageId, rootNavigator),
    pushReplace: (path: string, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.pushReplace(path, params, pageId, rootNavigator),
    /** pushReplace 语义化别名 */
    replace: (path: string, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.replace(path, params, pageId, rootNavigator),
    /** 重定向（替换当前路由，不可返回） */
    redirect: (path: string, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.redirect(path, params, pageId, rootNavigator),
    /** 通过命名路由跳转 */
    pushByName: (name: string, params?: unknown, rootNavigator?: boolean, prewarmMs?: number) =>
      NavigatorService.pushByName(name, params, pageId, rootNavigator, prewarmMs),
    pop: (result?: unknown) => NavigatorService.pop(pageId, false, result),
    /** 弹出到指定路由（按 path 匹配） */
    popTo: (name: string) => NavigatorService.popTo(name, pageId),
    /** 弹出所有路由回到根页面 */
    popAll: () => NavigatorService.popAll(pageId),
    prewarm: (path: string, params?: unknown, prewarmMs?: number) =>
      NavigatorService.prewarm(path, params, pageId, prewarmMs),
    cancelPrewarm: (path: string) => NavigatorService.cancelPrewarm(path),
    showBottomSheet: (
      component: React.ReactNode,
      options?: { minHeight?: number; maxHeight?: number; backgroundColor?: string },
      rootNavigator?: boolean,
    ) => NavigatorService.showBottomSheet(component, options, pageId, rootNavigator),
    showDialog: (component: React.ReactNode, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.showDialog(component, params, pageId, rootNavigator),
  };
}

/**
 * 获取当前页面的路由位置信息（path / params / name / meta）。
 *
 * 在守卫通过后、组件渲染前记录，因此组件首次渲染时即可读取。
 * 若页面未通过守卫（渲染了 fallback），返回 null。
 *
 * @example
 * ```tsx
 * const route = useRoute();
 * if (route) {
 *   console.log(route.path, route.params, route.meta);
 * }
 * ```
 */
export function useRoute(): RouteLocation | null {
  const pageId = usePageId();
  return Router.getLocation(pageId);
}

export function useVisible(callback: () => void) {
  const { pageId } = useContext(PageContext);

  // Use a ref to hold the latest callback so that changes do not trigger
  // re-registration. registerVisibleCallback fires immediately when the
  // page is already visible; if the callback also triggers a re-render
  // (e.g. via setState), passing a new anonymous function each render
  // would cause an infinite loop.
  const cbRef = useRef(callback);
  cbRef.current = callback;

  useEffect(() => {
    const stableFn = () => cbRef.current();
    const container = PageRender.getContainer(pageId);
    if (container) {
      container.registerVisibleCallback(stableFn);
    }
    return () => {
      const container = PageRender.getContainer(pageId);
      if (container) {
        container.unregisterVisibleCallback(stableFn);
      }
    };
  }, [pageId]);
}

export function useInvisible(callback: () => void) {
  const { pageId } = useContext(PageContext);

  const cbRef = useRef(callback);
  cbRef.current = callback;

  useEffect(() => {
    const stableFn = () => cbRef.current();
    const container = PageRender.getContainer(pageId);
    if (container) {
      container.registerInvisibleCallback(stableFn);
    }
    return () => {
      const container = PageRender.getContainer(pageId);
      if (container) {
        container.unregisterInvisibleCallback(stableFn);
      }
    };
  }, [pageId]);
}

export function usePageConfig(config: { incrementalMode?: boolean; dslCacheEnabled?: boolean }) {
  const { pageId } = useContext(PageContext);

  useEffect(() => {
    const container = PageRender.getContainer(pageId);
    if (container) {
      if (config.incrementalMode !== undefined) {
        container.setIncrementalMode(config.incrementalMode);
      }
      if (config.dslCacheEnabled !== undefined) {
        container.setDslCacheEnabled(config.dslCacheEnabled);
      }
    }
  }, [pageId, config.incrementalMode, config.dslCacheEnabled]);
}

export interface RouteTransitionResult {
  pageId: number;
  path: string;
}

export function useRouteTransitionComplete(callback: (result: RouteTransitionResult) => void) {
  const { pageId } = useContext(PageContext);

  useEffect(() => {
    const handler = (data: unknown) => {
      if (data && typeof data === 'object' && 'pageId' in data) {
        callback(data as RouteTransitionResult);
      }
    };
    NativeEvent.on('routeTransitionComplete', handler);
    return () => {
      NativeEvent.off('routeTransitionComplete', handler);
    };
  }, [pageId, callback]);
}

/**
 * Subscribe to app-level foreground/background state changes.
 *
 * Returns `{ isInBackground: boolean }` that updates reactively whenever the
 * app enters the background or returns to the foreground.
 *
 * Unlike [useVisible] / [useInvisible] which fire per-page, this hook is
 * page-independent and fires on every app state transition.
 *
 * @example
 * ```tsx
 * const { isInBackground } = useAppState();
 * useEffect(() => {
 *   if (isInBackground) {
 *     // Pause animations, stop polling, etc.
 *   } else {
 *     // Resume work.
 *   }
 * }, [isInBackground]);
 * ```
 */
export function useAppState(): { isInBackground: boolean } {
  const [isInBackground, setIsInBackground] = useState(() => LifecycleService.isInBackground);

  useEffect(() => {
    const unsubscribe = LifecycleService.onChange((state) => {
      setIsInBackground(state === 'background');
    });
    return unsubscribe;
  }, []);

  return { isInBackground };
}

/**
 * 主题快照结构（与 Flutter 端 FuickThemeData.toMap() 对齐）。
 */
export interface FuickThemeData {
  /** 'light' | 'dark' */
  brightness: 'light' | 'dark';
  isDark: boolean;
  /** '#AARRGGBB' 格式 */
  primaryColor: string;
  scaffoldBackgroundColor: string;
  surfaceColor: string;
  textColor?: string;
  secondaryTextColor?: string;
  borderRadius: number;
}

const EMPTY_THEME: FuickThemeData = {
  brightness: 'light',
  isDark: false,
  primaryColor: '#FF2196F3',
  scaffoldBackgroundColor: '#FFFFFFFF',
  surfaceColor: '#FFFFFFFF',
  textColor: '#FF000000',
  secondaryTextColor: '#FF757575',
  borderRadius: 8.0,
};

/**
 * 读取宿主 [Theme] 当前快照，并在主题变化时触发组件重渲染。
 *
 * 主题切换由 Flutter 端 [FuickThemeProvider] 在 build 时下推；
 * 当宿主调用 `MaterialApp.theme` / 暗黑模式切换时，根 Widget 重建，
 * Provider 中的 [FuickThemeData] 也随之更新并触发 'themeChange' 事件，
 * 本 hook 监听该事件并刷新 state。
 *
 * @example
 * ```tsx
 * const theme = useTheme();
 * return <Container color={theme.isDark ? '#FF000000' : '#FFFFFFFF'} />;
 * ```
 */
export function useTheme(): FuickThemeData {
  const pageId = usePageId();
  // worker isolate 中 UIService.getTheme 走 dartCallNativeAsync,初始必须用占位符,
  // 不能在 useState 初始化里 await,否则会卡住渲染。
  const [theme, setTheme] = useState<FuickThemeData>(EMPTY_THEME);

  useEffect(() => {
    let cancelled = false;
    UIService.getTheme(pageId)
      .then((raw) => {
        if (cancelled || !raw) return;
        setTheme(raw as unknown as FuickThemeData);
      })
      .catch(() => {
        /* ignore */
      });
    const unsubscribe = NativeEvent.on(
      'themeChange',
      (data) => {
        if (data && typeof data === 'object') {
          setTheme(data as FuickThemeData);
        }
      },
      pageId,
    );
    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [pageId]);

  return theme;
}

/**
 * MediaQuery 快照结构（与 Flutter 端 FuickMediaQueryData.toMap() 对齐）。
 */
export interface FuickMediaQueryData {
  screenWidth: number;
  screenHeight: number;
  pixelRatio: number;
  /** 'light' | 'dark' */
  platformBrightness: 'light' | 'dark';
  isDark: boolean;
  textScaleFactor: number;
  viewPadding: { top: number; bottom: number; left: number; right: number };
  viewInsets: { top: number; bottom: number; left: number; right: number };
}

const EMPTY_MEDIA_QUERY: FuickMediaQueryData = {
  screenWidth: 0,
  screenHeight: 0,
  pixelRatio: 1.0,
  platformBrightness: 'light',
  isDark: false,
  textScaleFactor: 1.0,
  viewPadding: { top: 0, bottom: 0, left: 0, right: 0 },
  viewInsets: { top: 0, bottom: 0, left: 0, right: 0 },
};

/**
 * 读取宿主 [MediaQuery] 当前快照，并在屏幕尺寸、方向、暗黑模式等变化时重渲染。
 *
 * - 屏幕旋转、键盘弹起、暗黑模式切换都会触发 'mediaQueryChange' 事件。
 * - 首次挂载时同步调用 `UIService.getMediaQuery(pageId)` 拿当前值。
 *
 * @example
 * ```tsx
 * const mq = useMediaQuery();
 * const isLandscape = mq.screenWidth > mq.screenHeight;
 * ```
 */
export function useMediaQuery(): FuickMediaQueryData {
  const pageId = usePageId();
  // worker isolate 中 UIService.getMediaQuery 走 dartCallNativeAsync,初始必须用占位符,
  // 不能在 useState 初始化里 await,否则会卡住渲染。
  const [mq, setMq] = useState<FuickMediaQueryData>(EMPTY_MEDIA_QUERY);

  useEffect(() => {
    let cancelled = false;
    UIService.getMediaQuery(pageId)
      .then((raw) => {
        if (cancelled || !raw) return;
        setMq(raw as unknown as FuickMediaQueryData);
      })
      .catch(() => {
        /* ignore */
      });
    const unsubscribe = NativeEvent.on(
      'mediaQueryChange',
      (data) => {
        if (data && typeof data === 'object') {
          setMq(data as FuickMediaQueryData);
        }
      },
      pageId,
    );
    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [pageId]);

  return mq;
}
