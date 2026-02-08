import React, { useContext, useEffect } from 'react';
import { PageContext } from './PageContext';
import * as PageRender from './page_render';

import { NavigatorService } from './services/NavigatorService';

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
