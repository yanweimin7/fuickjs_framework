import React from 'react';
import { PageContainer } from './PageContainer';
import { ItemContainer } from './ItemContainer';
import { createHostConfig } from './hostConfig';
import { ErrorHandler } from './ErrorHandler';
import { logDebug } from '../utils/log';

interface ItemEntry {
  container: ItemContainer;
  root: unknown; // reconciler sub-root
}

/**
 * ListItemManager 管理列表项的 reconciler sub-root，使通过 getItemDSL 渲染的
 * 列表项拥有完整的 React 生命周期（useState, useEffect 等）。
 *
 * 核心设计：
 * - 每个 (pageId, refId, index) 对应一个 sub-root，保持组件实例持久化
 * - getItemDSL 时通过 flushSync 同步渲染，渲染后从 Node 树提取 DSL 返回
 * - disposeItem 时 updateContainer(null, subRoot) 触发 useEffect cleanup
 * - 页面 destroy 时批量清理所有 sub-root
 */
export class ListItemManager {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private reconciler: any;
  private handleRecoverableError: (error: unknown, errorInfo: unknown) => void;
  private items: Map<string, ItemEntry> = new Map();

  constructor(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    reconciler: any,
    handleRecoverableError: (error: unknown, errorInfo: unknown) => void,
  ) {
    this.reconciler = reconciler;
    this.handleRecoverableError = handleRecoverableError;
  }

  private itemKey(pageId: number, refId: string, index: number): string {
    return `${pageId}:${refId}:${index}`;
  }

  /**
   * 同步 flush 卸载 sub-root。ConcurrentRoot 下裸 updateContainer(null) 只是
   * 调度卸载（异步 commit），items.delete 后可能永远没人触发 useEffect cleanup；
   * 与 getItemDSL 的渲染路径一样用 flushSync 保证返回即已 unmount。
   */
  private flushSyncUnmount(root: unknown): void {
    if (this.reconciler.flushSyncFromReconciler) {
      this.reconciler.flushSyncFromReconciler(() => {
        this.reconciler.updateContainer(null, root, null, null);
      });
    } else if (this.reconciler.flushSync) {
      this.reconciler.flushSync(() => {
        this.reconciler.updateContainer(null, root, null, null);
      });
    } else {
      this.reconciler.updateContainer(null, root, null, null);
    }
  }

  /**
   * 渲染列表项并通过 reconciler sub-root，返回 DSL。
   * 如果 sub-root 不存在则创建，存在则更新。
   */
  getItemDSL(
    pageId: number,
    refId: string,
    index: number,
    itemBuilder: (index: number) => React.ReactNode,
    mainContainer: PageContainer,
  ): unknown {
    const key = this.itemKey(pageId, refId, index);
    let entry = this.items.get(key);

    const element = itemBuilder(index);

    if (!entry) {
      // 创建新的 sub-root
      const container = new ItemContainer(pageId, mainContainer);

      // React 19: createContainer 新增 onUncaughtError/onCaughtError/onDefaultTransitionIndicator，
      // onRecoverableError 从第 7 位移至第 9 位。
      const root = (this.reconciler as any).createContainer(
        container,
        1, // tag: ConcurrentRoot
        null,
        false,
        null,
        '',
        null, // onUncaughtError
        null, // onCaughtError
        this.handleRecoverableError, // onRecoverableError
        () => {}, // onDefaultTransitionIndicator
      );
      entry = { container, root };
      this.items.set(key, entry);
      logDebug(`[ListItemManager] Created sub-root for key=${key}`);
    }

    try {
      // flushSync 保证同步渲染，渲染完成后 Node 树已提交
      // React 19 compatible: try flushSyncFromReconciler, fallback to flushSync
      if (this.reconciler.flushSyncFromReconciler) {
        this.reconciler.flushSyncFromReconciler(() => {
          this.reconciler.updateContainer(element, entry!.root, null, null);
        });
      } else if (this.reconciler.flushSync) {
        this.reconciler.flushSync(() => {
          this.reconciler.updateContainer(element, entry!.root, null, null);
        });
      } else {
        // Fallback: direct call without flushSync
        this.reconciler.updateContainer(element, entry!.root, null, null);
      }

      // 标记初始渲染完成，后续状态变更将发送增量补丁
      entry.container.markInitialRenderDone();

      // 从已提交的 Node 树提取 DSL
      const dsl = entry.container.toDsl();
      return dsl;
    } catch (e) {
      console.error(`[ListItemManager] Error rendering item key=${key}:`, e);
      ErrorHandler.notify(e, 'render', { pageId, refId, index });

      // 回退到无生命周期的 elementToDsl 方式。
      // 走 elementToDslForItem 以便按 itemKey 回收合成回调（与无状态路径一致），
      // 避免回退渲染注册的合成 eventCallbacks 无人清理。
      console.warn(`[ListItemManager] Falling back to elementToDsl for key=${key}`);
      return mainContainer.elementToDslForItem(key, element);
    }
  }

  /**
   * 销毁指定列表项的 sub-root，触发 useEffect cleanup。
   * 应在 Flutter 侧列表项 widget 被回收时调用。
   */
  disposeItem(pageId: number, refId: string, index: number): void {
    const key = this.itemKey(pageId, refId, index);
    const entry = this.items.get(key);
    if (!entry) {
      return;
    }

    logDebug(`[ListItemManager] Disposing item key=${key}`);
    try {
      // 同步 unmount → useEffect cleanup 在返回前执行
      this.flushSyncUnmount(entry.root);
    } catch (e) {
      console.error(`[ListItemManager] Error disposing item key=${key}:`, e);
    }

    this.items.delete(key);
  }

  /**
   * 销毁指定页面所有列表项的 sub-root。
   * 在页面 destroy 时调用。
   */
  disposePageItems(pageId: number): void {
    const prefix = `${pageId}:`;
    const keysToDispose: string[] = [];

    for (const key of this.items.keys()) {
      if (key.startsWith(prefix)) {
        keysToDispose.push(key);
      }
    }

    if (keysToDispose.length > 0) {
      logDebug(`[ListItemManager] Disposing ${keysToDispose.length} items for pageId=${pageId}`);
      for (const key of keysToDispose) {
        const entry = this.items.get(key);
        if (entry) {
          try {
            this.flushSyncUnmount(entry.root);
          } catch (e) {
            console.error(`[ListItemManager] Error disposing item key=${key}:`, e);
          }
        }
        this.items.delete(key);
      }
    }
  }

  /**
   * 获取当前活跃的 sub-root 数量（调试用）。
   */
  get size(): number {
    return this.items.size;
  }
}
