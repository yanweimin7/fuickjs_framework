import React from 'react';
import { PageContainer } from './PageContainer';
import { ItemContainer } from './ItemContainer';
import { createHostConfig } from './hostConfig';
import { ErrorHandler } from './ErrorHandler';

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
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const root = (this.reconciler as any).createContainer(
        container,
        1, // tag: ConcurrentRoot
        null,
        false,
        null,
        '',
        this.handleRecoverableError,
        null,
      );
      entry = { container, root };
      this.items.set(key, entry);
      console.log(`[ListItemManager] Created sub-root for key=${key}`);
    }

    try {
      // flushSync 保证同步渲染，渲染完成后 Node 树已提交
      this.reconciler.flushSync(() => {
        this.reconciler.updateContainer(element, entry!.root, null, null);
      });

      // 标记初始渲染完成，后续状态变更将发送增量补丁
      entry.container.markInitialRenderDone();

      // 从已提交的 Node 树提取 DSL
      const dsl = entry.container.toDsl();
      return dsl;
    } catch (e) {
      console.error(`[ListItemManager] Error rendering item key=${key}:`, e);
      ErrorHandler.notify(e, 'render', { pageId, refId, index });

      // 回退到无生命周期的 elementToDsl 方式
      console.warn(`[ListItemManager] Falling back to elementToDsl for key=${key}`);
      return mainContainer.elementToDsl(element);
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

    console.log(`[ListItemManager] Disposing item key=${key}`);
    try {
      // updateContainer(null, ...) 触发组件 unmount → useEffect cleanup
      this.reconciler.updateContainer(null, entry.root, null, null);
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
      console.log(`[ListItemManager] Disposing ${keysToDispose.length} items for pageId=${pageId}`);
      for (const key of keysToDispose) {
        const entry = this.items.get(key);
        if (entry) {
          try {
            this.reconciler.updateContainer(null, entry.root, null, null);
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
