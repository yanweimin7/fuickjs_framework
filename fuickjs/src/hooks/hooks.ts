import React, { useContext, useEffect } from 'react';
import { PageContext } from '../core/PageContext';
import * as PageRender from '../core/page_render';

import { NavigatorService } from '../services/NavigatorService';
import { DialogService } from '../services/DialogService';

export function usePageId() {
  const { pageId } = useContext(PageContext);
  return pageId;
}

export function useNavigator() {
  const pageId = usePageId();
  return {
    push: (path: string, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.push(path, params, pageId, rootNavigator),
    pushReplace: (path: string, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.pushReplace(path, params, pageId, rootNavigator),
    showModal: (path: string, params?: unknown, options?: { minHeight?: number, maxHeight?: number }, rootNavigator?: boolean) =>
      NavigatorService.showModal(path, params, options, pageId, rootNavigator),
    showDialog: (pathOrComponent: string | React.ReactNode, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.showDialog(pathOrComponent, params, pageId, rootNavigator),
    showComponentDialog: (path: string, component: React.ReactNode, params?: unknown, rootNavigator?: boolean) =>
      NavigatorService.showComponentDialog(path, component, params, pageId, rootNavigator),
    pop: (result?: unknown) => {
      return NavigatorService.pop(pageId, false, result);
    },
  };
}

export function useDialog() {
  const pageId = usePageId();
  return {
    show: (content: React.ReactNode, options?: { barrierDismissible?: boolean; barrierColor?: string }) =>
      DialogService.show(content, { ...options, pageId }),
    dismiss: (result?: any) => DialogService.dismiss(result),
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
