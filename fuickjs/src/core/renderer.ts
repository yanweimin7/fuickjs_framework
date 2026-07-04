import ReactReconciler from 'react-reconciler';
import React from 'react';
import { createHostConfig } from './hostConfig';
import { PageContainer } from './PageContainer';
import { ErrorHandler } from './ErrorHandler';
import { ListItemManager } from './ListItemManager';
import { perfLog } from '../utils/log';

export interface Renderer {
  update(element: React.ReactNode, pageId: number): void;
  destroy(pageId: number): void;
  dispatchEvent(eventObj: unknown, payload: unknown): void;
  getItemDSL(pageId: number, refId: string, index: number): unknown;
  disposeItem(pageId: number, refId: string, index: number): void;
  notifyLifecycle(pageId: number, type: 'visible' | 'invisible'): void;
  elementToDsl(pageId: number, element: React.ReactNode): unknown;
  getContainer(pageId: number): PageContainer | undefined;
}

const containers: Record<number, PageContainer> = {};
const roots: Record<number, unknown> = {};
// pageId 处于 destroying 状态时拒绝 update，防止 destroy retry 期间被并发 update 复用旧 root。
const destroyingPages: Set<number> = new Set();

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

    const container = containers[pageId];

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
    ErrorHandler.notify(e, 'event', { eventObj, payload });
  }
}

/**
 * React Reconciler "render in progress" 错误检测。
 * flushSync 内嵌套更新时会抛出错误码 327 或类似提示。
 * 使用独立函数集中维护检测逻辑，避免散落的魔法字符串。
 */
function isRenderInProgressError(msg: string): boolean {
  return msg.includes('327') || msg.includes('already being rendered') || msg.includes('working');
}

export function createRenderer(): Renderer {
  const reconciler = ReactReconciler(createHostConfig());
  const handleRecoverableError = (error: unknown, errorInfo: unknown) => {
    ErrorHandler.notify(error, 'render', errorInfo);
  };

  // ListItemManager 管理 getItemDSL 渲染的列表项的 reconciler sub-root，
  // 使列表项拥有完整的 React 生命周期（useState, useEffect 等）。
  const listItemManager = new ListItemManager(reconciler, handleRecoverableError);

  function ensureRoot(pageId: number) {
    if (roots[pageId]) return roots[pageId];

    // Reuse existing container if it was created by elementToDsl or previous attempts
    let container = containers[pageId];
    if (!container) {
      container = new PageContainer(pageId);
      containers[pageId] = container;
    }

    // container.setIncrementalMode(false);

    // React 19: createContainer 新增 onUncaughtError/onCaughtError/onDefaultTransitionIndicator，
    // onRecoverableError 从第 7 位移至第 9 位。
    const root = (reconciler as any).createContainer(
      container,
      1,
      null,
      false,
      null,
      '',
      null,
      null,
      handleRecoverableError,
      () => {},
    );
    roots[pageId] = root;
    return root;
  }

  // Track rendered pages to avoid flushSync after first render
  const renderedPages = new Set<number>();

  return {
    update(element: React.ReactNode, pageId: number) {
      if (destroyingPages.has(pageId)) {
        console.warn(`[Renderer] update() ignored: pageId=${pageId} is destroying.`);
        return;
      }
      const root = ensureRoot(pageId);
      const isFirstRender = !renderedPages.has(pageId);
      perfLog(
        `[Renderer] update() called for pageId=${pageId}, isFirstRender=${isFirstRender}, roots=${Object.keys(roots).join(',')}`,
      );
      let retryCount = 0;
      const maxRetries = 100;

      const performUpdate = () => {
        const updateStart = Date.now();
        try {
          if (isFirstRender) {
            // React 19 compatible: try flushSyncFromReconciler, fallback to flushSync
            if ((reconciler as any).flushSyncFromReconciler) {
              (reconciler as any).flushSyncFromReconciler(() => {
                reconciler.updateContainer(element, root, null, null);
              });
            } else if ((reconciler as any).flushSync) {
              (reconciler as any).flushSync(() => {
                reconciler.updateContainer(element, root, null, null);
              });
            } else {
              // Fallback: direct call without flushSync
              reconciler.updateContainer(element, root, null, null);
            }
            renderedPages.add(pageId);
          } else {
            reconciler.updateContainer(element, root, null, null);
          }
          const updateEnd = Date.now();

          retryCount = 0;
        } catch (e: unknown) {
          const msg = (e as Error).message || String(e);
          console.error(`[Renderer] Error in updateContainer for page ${pageId}:`, msg);
          if (isRenderInProgressError(msg) && retryCount < maxRetries) {
            retryCount++;
            if (retryCount <= 3 || retryCount % 10 === 0) {
              console.warn(`[Renderer] Retrying update for pageId=${pageId}, retry #${retryCount}`);
            }
            // Use Promise microtask for retry — same reason as destroy():
            // globalThis.setTimeout depends on Dart TimerService which may
            // be unavailable during context disposal.
            Promise.resolve().then(performUpdate);
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
        destroyingPages.add(pageId);
        let retryCount = 0;
        const maxRetries = 100; // Prevent infinite loop

        const finalize = () => {
          // 销毁容器内部状态（事件回调/onVisible 等），切断闭包持引。
          containers[pageId]?.dispose();
          delete roots[pageId];
          delete containers[pageId];
          renderedPages.delete(pageId);
          destroyingPages.delete(pageId);
        };

        const performDestroy = () => {
          try {
            reconciler.updateContainer(null, root, null, null);
            perfLog(`[Renderer] destroy() succeeded for pageId=${pageId}, retries=${retryCount}`);
            finalize();
          } catch (e: unknown) {
            const msg = (e as Error).message || String(e);
            if (isRenderInProgressError(msg) && retryCount < maxRetries) {
              retryCount++;
              if (retryCount <= 3 || retryCount % 10 === 0) {
                console.warn(`[Renderer] Retrying destroy for pageId=${pageId}, retry #${retryCount}`);
              }
              // Use Promise microtask for retry instead of globalThis.setTimeout,
              // which depends on Dart-side TimerService and may be unavailable
              // during context disposal, breaking the retry chain and leaving
              // React component tree unmounted — causing useEffect cleanup
              // (e.g. clearInterval) to never execute.
              Promise.resolve().then(performDestroy);
            } else {
              if (retryCount >= maxRetries) {
                console.error(`[Renderer] Max retries exceeded for destroying page ${pageId}`);
              }
              console.error(`[Renderer] Error destroying page ${pageId}:`, e);
              ErrorHandler.notify(e, 'render', { pageId });
              // Even on fatal error, still try to unmount the component tree
              // so that useEffect cleanup (clearInterval etc.) can execute.
              try {
                console.warn(`[Renderer] Best-effort unmount for pageId=${pageId} after fatal error`);
                reconciler.updateContainer(null, root, null, null);
                // eslint-disable-next-line @typescript-eslint/no-unused-vars
              } catch (_e) {
                // Best effort — if this also fails, nothing more we can do
                console.error(`[Renderer] Best-effort unmount also failed for pageId=${pageId}`);
              }
              finalize();
            }
          }
        };
        performDestroy();
        // 同时清理该页面所有列表项的 sub-root
        listItemManager.disposePageItems(pageId);
      } else {
        // Even if no root, check if we have a temporary container to cleanup
        if (containers[pageId]) {
          console.warn(`[Renderer] destroy() pageId=${pageId} has no root but has orphaned container, cleaning up.`);
          containers[pageId]?.dispose();
          delete containers[pageId];
          renderedPages.delete(pageId);
        } else {
          console.warn(`[Renderer] destroy() pageId=${pageId} has no root and no container, nothing to destroy.`);
        }
      }
    },

    dispatchEvent,
    getItemDSL(pageId: number, refId: string, index: number) {
      const container = containers[pageId];
      if (!container) return null;

      // 查找 itemBuilder
      const node = container.getNodeByRefId(refId);
      if (!node) return null;

      const itemBuilder = (node.props as Record<string, unknown>)?.itemBuilder;
      if (typeof itemBuilder !== 'function') return null;

      // 检查是否为有状态列表（走 reconciler sub-root）
      const stateful = (node.props as Record<string, unknown>)?.stateful === true;

      if (stateful) {
        // 通过 ListItemManager 渲染，使列表项拥有完整 React 生命周期
        return listItemManager.getItemDSL(
          pageId,
          refId,
          index,
          itemBuilder as (index: number) => React.ReactNode,
          container,
        );
      } else {
        // 无状态模式：直接通过 elementToDsl 渲染，无生命周期。
        // 走 elementToDslForItem 以便按 (pageId,refId,index) 回收合成回调，避免泄漏。
        try {
          const element = (itemBuilder as (index: number) => React.ReactNode)(index);
          return container.elementToDslForItem(`${pageId}:${refId}:${index}`, element);
        } catch (e) {
          console.error(`[Renderer] Error in stateless getItemDSL for refId ${refId} at index ${index}:`, e);
          return null;
        }
      }
    },
    disposeItem(pageId: number, refId: string, index: number) {
      listItemManager.disposeItem(pageId, refId, index);
      // 同时回收无状态列表项注册的合成回调，防止 eventCallbacks 泄漏
      containers[pageId]?.clearItemSyntheticCallbacks(`${pageId}:${refId}:${index}`);
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
