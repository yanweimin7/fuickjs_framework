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
    const evt = eventObj as { pageId: number; nodeId?: number; id?: number; eventKey: string };
    const pageId = evt?.pageId;
    const nodeId: number = Number(evt?.nodeId || evt?.id);
    const eventKey = evt?.eventKey;

    const container = containers[pageId];
    if (container) {
      const fn = container.getCallback(nodeId, eventKey);
      if (typeof fn === 'function') {
        fn(payload);
      } else {
        console.warn(`[Renderer] Callback not found for nodeId=${nodeId}, eventKey=${eventKey}`);
      }
    } else {
      console.warn(`[Renderer] Container not found for pageId=${pageId}`);
    }
  } catch (e) {
    console.error(`[Renderer] Error in dispatchEvent:`, e);
    ErrorHandler.notify(e, 'event', { eventObj, payload });
  }
}

export function createRenderer(): Renderer {
  const reconciler = ReactReconciler(createHostConfig());
  const handleRecoverableError = (error: unknown, errorInfo: unknown) => {
    ErrorHandler.notify(error, 'render', errorInfo);
  };

  function ensureRoot(pageId: number) {
    if (roots[pageId]) return roots[pageId];
    const container = new PageContainer(pageId);
    // container.setIncrementalMode(false);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const root = (reconciler as any).createContainer(container, 1, null, false, null, '', handleRecoverableError, null);
    containers[pageId] = container;
    roots[pageId] = root;
    return root;
  }

  return {
    update(element: React.ReactNode, pageId: number) {
      const root = ensureRoot(pageId);

      const performUpdate = () => {
        try {
          reconciler.updateContainer(element, root, null, () => {
            // Success
          });
        } catch (e: unknown) {
          const msg = (e as Error).message || String(e);
          if (msg.includes('327') || msg.includes('working')) {
            globalThis.setTimeout(performUpdate, 16);
          } else {
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
        const performDestroy = () => {
          try {
            reconciler.updateContainer(null, root, null, () => {
              console.log(`[Renderer] Page ${pageId} unmounted successfully`);
            });
            delete roots[pageId];
            delete containers[pageId];
          } catch (e: unknown) {
            const msg = (e as Error).message || String(e);
            if (msg.includes('327') || msg.includes('working')) {
              globalThis.setTimeout(performDestroy, 16);
            } else {
              console.error(`[Renderer] Error destroying page ${pageId}:`, e);
              ErrorHandler.notify(e, 'render', { pageId });
              delete roots[pageId];
              delete containers[pageId];
            }
          }
        };
        performDestroy();
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
