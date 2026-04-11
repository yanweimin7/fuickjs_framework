import ReactReconciler from 'react-reconciler';
import React from 'react';
import { createHostConfig } from './hostConfig';
import { PageContainer } from './PageContainer';
import { ErrorHandler } from './ErrorHandler';

export interface Renderer {
  update(element: React.ReactNode, pageId: number): void;
  destroy(pageId: number): void;
  dispatchEvent(eventObj: unknown, payload: unknown): void;
  getItemDSL(pageId: number, refId: string, index: number): unknown;
  notifyLifecycle(pageId: number, type: 'visible' | 'invisible'): void;
  elementToDsl(pageId: number, element: React.ReactNode): unknown;
  getContainer(pageId: number): PageContainer | undefined;
}

const containers: Record<number, PageContainer> = {};
const roots: Record<number, unknown> = {};

export function dispatchEvent(eventObj: unknown, payload: unknown) {
  try {
    const evt = eventObj as {
      pageId: number;
      nodeId?: number;
      id?: number;
      eventKey: string;
    };
    const pageId = evt?.pageId;
    const nodeId: number = Number(evt?.nodeId || evt?.id);
    const eventKey = evt?.eventKey;

    // 优先从正常页面容器查找
    let container = containers[pageId];

    // 兼容性：如果容器不存在（可能是 Dialog/Overlay 使用了临时 pageId 且已销毁或未注册），
    // 尝试从其他活跃容器中查找（针对全局/跨页面事件）
    if (!container) {
      // 如果是 Dialog/Overlay 常用的 -1，或者找不到容器，尝试遍历所有容器
      // 注意：这仅作为兜底逻辑
      for (const id in containers) {
        const c = containers[id];
        if (c.getCallback(nodeId, eventKey)) {
          container = c;
          break;
        }
      }
    }

    if (container) {
      const fn = container.getCallback(nodeId, eventKey);
      if (typeof fn === 'function') {
        fn(payload);
      } else {
        console.warn(
          `[Renderer] Callback not found for nodeId=${nodeId}, eventKey=${eventKey} in pageId=${container.pageId}`,
        );
      }
    } else {
      console.warn(
        `[Renderer] Container not found for pageId=${pageId}. Available: ${Object.keys(containers).join(',')}`,
      );
    }
  } catch (e) {
    console.error(`[Renderer] Error in dispatchEvent:`, e);
    ErrorHandler.notify(e, 'event', { eventObj, payload });
  }
}

/**
 * React Reconciler "render in progress" 错误检测。
 * React 18 flushSync 内嵌套更新时会抛出错误码 327 或类似提示。
 * 使用独立函数集中维护检测逻辑，避免散落的魔法字符串。
 */
function isRenderInProgressError(msg: string): boolean {
  // React 18 错误码 327: "flushSync was called from inside a lifecycle method"
  // React 内部 "already working" 提示
  return msg.includes('327') || msg.includes('already being rendered') || msg.includes('working');
}

export function createRenderer(): Renderer {
  const reconciler = ReactReconciler(createHostConfig());
  const handleRecoverableError = (error: unknown, errorInfo: unknown) => {
    ErrorHandler.notify(error, 'render', errorInfo);
  };

  function ensureRoot(pageId: number) {
    if (roots[pageId]) return roots[pageId];

    // Reuse existing container if it was created by elementToDsl or previous attempts
    let container = containers[pageId];
    if (!container) {
      container = new PageContainer(pageId);
      containers[pageId] = container;
    }

    // container.setIncrementalMode(false);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const root = (reconciler as any).createContainer(container, 1, null, false, null, '', handleRecoverableError, null);
    roots[pageId] = root;
    return root;
  }

  // Track rendered pages to avoid flushSync after first render
  const renderedPages = new Set<number>();

  return {
    update(element: React.ReactNode, pageId: number) {
      const root = ensureRoot(pageId);
      const isFirstRender = !renderedPages.has(pageId);
      let retryCount = 0;
      const maxRetries = 100; // Prevent infinite loop

      const performUpdate = () => {
        try {
          if (isFirstRender) {
            // Use flushSync for first render to ensure page is displayed immediately
            reconciler.flushSync(() => {
              reconciler.updateContainer(element, root, null, null);
            });
            renderedPages.add(pageId);
          } else {
            // Use async rendering for subsequent updates
            reconciler.updateContainer(element, root, null, null);
          }
          retryCount = 0; // Reset on success
        } catch (e: unknown) {
          const msg = (e as Error).message || String(e);
          console.error(`[Renderer] Error in updateContainer for page ${pageId}:`, msg);
          if (isRenderInProgressError(msg) && retryCount < maxRetries) {
            retryCount++;
            globalThis.setTimeout(performUpdate, 16);
          } else {
            if (retryCount >= maxRetries) {
              console.error(`[Renderer] Max retries exceeded for page ${pageId}`);
            }
            console.error(`[Renderer] Error updating page ${pageId}:`, e);
            ErrorHandler.notify(e, 'render', { pageId });
          }
        }
      };

      performUpdate();
    },

    destroy(pageId: number) {
      const root = roots[pageId];
      if (root) {
        let retryCount = 0;
        const maxRetries = 100; // Prevent infinite loop

        const performDestroy = () => {
          try {
            reconciler.updateContainer(null, root, null, null);
            delete roots[pageId];
            delete containers[pageId];
          } catch (e: unknown) {
            const msg = (e as Error).message || String(e);
            if (isRenderInProgressError(msg) && retryCount < maxRetries) {
              retryCount++;
              globalThis.setTimeout(performDestroy, 16);
            } else {
              if (retryCount >= maxRetries) {
                console.error(`[Renderer] Max retries exceeded for destroying page ${pageId}`);
              }
              console.error(`[Renderer] Error destroying page ${pageId}:`, e);
              ErrorHandler.notify(e, 'render', { pageId });
              delete roots[pageId];
              delete containers[pageId];
            }
          }
        };
        performDestroy();
      } else {
        // Even if no root, check if we have a temporary container to cleanup
        if (containers[pageId]) {
          delete containers[pageId];
        }
      }
    },

    dispatchEvent,
    getItemDSL(pageId: number, refId: string, index: number) {
      const container = containers[pageId];
      if (container) {
        return container.getItemDSL(refId, index);
      }
      return null;
    },
    elementToDsl(pageId: number, element: React.ReactNode) {
      let container = containers[pageId];
      if (!container) {
        // Create a temporary container for preloading or conversion
        container = new PageContainer(pageId);
        containers[pageId] = container;
      }
      return container.elementToDsl(element);
    },
    notifyLifecycle(pageId: number, type: 'visible' | 'invisible') {
      const container = containers[pageId];
      if (container) {
        if (type === 'visible') {
          container.notifyVisible();
        } else if (type === 'invisible') {
          container.notifyInvisible();
        }
      }
    },
    getContainer(pageId: number) {
      return containers[pageId];
    },
  };
}
