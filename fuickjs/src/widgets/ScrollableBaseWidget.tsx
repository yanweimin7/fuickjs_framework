import React from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';
import { elementToDsl } from '../page_render';

export abstract class ScrollableBaseWidget<
  P extends WidgetProps = WidgetProps,
  S = Record<string, unknown>,
> extends BaseWidget<P, S> {
  public updateItem(index: number, dsl: unknown) {
    let finalDsl = dsl;
    if (React.isValidElement(dsl)) {
      finalDsl = elementToDsl(this.pageId, dsl);
    }

    this.callNativeCommand('updateItem', { index, dsl: finalDsl });
  }

  public updateItems(items: { index: number; dsl: unknown }[]) {
    const finalItems = items.map((item) => {
      let finalDsl = item.dsl;
      if (React.isValidElement(item.dsl)) {
        finalDsl = elementToDsl(this.pageId, item.dsl);
      }
      return { index: item.index, dsl: finalDsl };
    });

    this.callNativeCommand('updateItems', { items: finalItems });
  }

  public refresh() {
    this.callNativeCommand('refresh');
  }
}
