import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { ScrollableBaseWidget } from './ScrollableBaseWidget';

export interface SliverListProps extends WidgetProps {
  itemCount?: number;
  itemBuilder?: (index: number) => ReactNode;
  cacheKey?: unknown;
}

export class SliverList extends ScrollableBaseWidget<SliverListProps> {
  render(): ReactNode {
    const { children, ...rest } = this.props;
    return React.createElement(
      'SliverList',
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

export default SliverList;
