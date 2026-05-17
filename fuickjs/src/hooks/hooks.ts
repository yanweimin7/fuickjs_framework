import React, { useContext, useEffect } from 'react';
import { PageContext } from '../core/PageContext';
import * as PageRender from '../core/page_render';

import { NavigatorService } from '../services/NavigatorService';
import { NativeEvent } from '../runtime/NativeEvent';

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

  useEffect(() => {
    const container = PageRender.getContainer(pageId);
    if (container) {
      container.registerVisibleCallback(callback);
    }
    return () => {
      const container = PageRender.getContainer(pageId);
      if (container) {
        container.unregisterVisibleCallback(callback);
      }
    };
  }, [pageId, callback]);
}

export function useInvisible(callback: () => void) {
  const { pageId } = useContext(PageContext);

  useEffect(() => {
    const container = PageRender.getContainer(pageId);
    if (container) {
      container.registerInvisibleCallback(callback);
    }
    return () => {
      const container = PageRender.getContainer(pageId);
      if (container) {
        container.unregisterInvisibleCallback(callback);
      }
    };
  }, [pageId, callback]);
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
