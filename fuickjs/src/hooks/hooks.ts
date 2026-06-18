import React, { useContext, useEffect, useState, useRef } from 'react';
import { PageContext } from '../core/PageContext';
import * as PageRender from '../core/page_render';

import { NavigatorService } from '../services/NavigatorService';
import { NativeEvent } from '../runtime/NativeEvent';
import { LifecycleService } from '../services/LifecycleService';

export function usePageId() {
  const { pageId } = useContext(PageContext);
  return pageId;
}

export function useNavigator() {
  const pageId = usePageId();
  return {
    push: (path: string, params?: unknown, rootNavigator?: boolean, prewarmMs?: number) =>
      NavigatorService.push(path, params, pageId, rootNavigator, prewarmMs),
    pushReplace: (path: string, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.pushReplace(path, params, pageId, rootNavigator),
    showBottomSheet: (
      component: React.ReactNode,
      options?: { minHeight?: number; maxHeight?: number; backgroundColor?: string },
      rootNavigator?: boolean,
    ) => NavigatorService.showBottomSheet(component, options, pageId, rootNavigator),
    showDialog: (component: React.ReactNode, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.showDialog(component, params, pageId, rootNavigator),
    pop: (result?: unknown) => {
      return NavigatorService.pop(pageId, false, result);
    },
  };
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
