import React from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';
import { elementToDsl, getContainer } from '../core/page_render';

export abstract class ScrollableBaseWidget<
  P extends WidgetProps = WidgetProps,
  S = Record<string, unknown>,
> extends BaseWidget<P, S> {
  // 每条 item 的合成回调 key,与 ListItemManager.itemKey 保持一致,
  // 便于 elementToDslForItem 在重渲染前按 (pageId, refId, index) 回收旧回调。
  private itemCallbackKey(index: number): string {
    return `${this.pageId}:${this.scopedRefId}:${index}`;
  }

  public updateItem(index: number, dsl: unknown) {
    let finalDsl = dsl;
    if (React.isValidElement(dsl)) {
      // 走 elementToDslForItem,避免 raw elementToDsl 每次都分配新合成 nodeId
      // 并把旧 callback 留在 eventCallbacks 里造成无界泄漏。
      const container = getContainer(this.pageId);
      finalDsl = container
        ? container.elementToDslForItem(this.itemCallbackKey(index), dsl)
        : elementToDsl(this.pageId, dsl);
    }

    this.callNativeCommand('updateItem', { index, dsl: finalDsl });
  }

  public updateItems(items: { index: number; dsl: unknown }[]) {
    const container = getContainer(this.pageId);
    const finalItems = items.map((item) => {
      let finalDsl = item.dsl;
      if (React.isValidElement(item.dsl)) {
        // 同样按 itemKey 回收,否则 100 个 item × 每次 tick = 旧 callback 永远不被释放。
        finalDsl = container
          ? container.elementToDslForItem(this.itemCallbackKey(item.index), item.dsl)
          : elementToDsl(this.pageId, item.dsl);
      }
      return { index: item.index, dsl: finalDsl };
    });

    this.callNativeCommand('updateItems', { items: finalItems });
  }

  public refresh() {
    this.callNativeCommand('refresh');
  }
}
