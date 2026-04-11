import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { ScrollableBaseWidget } from './ScrollableBaseWidget';

export interface ListViewProps extends WidgetProps {
  scrollDirection?: 'horizontal' | 'vertical';
  orientation?: 'horizontal' | 'vertical';
  shrinkWrap?: boolean;
  itemCount?: number;
  itemBuilder?: (index: number) => ReactNode;
  cacheKey?: unknown;
}

export class ListView extends ScrollableBaseWidget<ListViewProps> {
  public animateTo(offset: number, duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('animateTo', { offset, duration, curve });
  }

  public jumpTo(offset: number) {
    this.callNativeCommand('jumpTo', { offset });
  }

  render(): ReactNode {
    const { children, ...rest } = this.props;

    return React.createElement(
      'ListView',
      {
        ...rest,
        hasBuilder: !!this.props.itemBuilder,
        refId: this.scopedRefId,
        isBoundary: true,
      },
      children,
    );
  }
}

export default ListView;
