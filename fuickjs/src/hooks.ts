import { useContext, useEffect } from 'react';
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
    pop: (rootNavigator?: boolean, result?: unknown) => NavigatorService.pop(pageId, rootNavigator, result),
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
