import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { ScrollableBaseWidget } from './ScrollableBaseWidget';

export interface SliverGridProps extends WidgetProps {
  gridDelegate: {
    type?: 'fixedCrossAxisCount' | 'maxCrossAxisExtent';
    crossAxisCount?: number;
    maxCrossAxisExtent?: number;
    mainAxisSpacing?: number;
    crossAxisSpacing?: number;
    childAspectRatio?: number;
  };
  itemCount?: number;
  itemBuilder?: (index: number) => ReactNode;
  cacheKey?: unknown;
}

export class SliverGrid extends ScrollableBaseWidget<SliverGridProps> {
  render(): ReactNode {
    const { children, ...rest } = this.props;
    return React.createElement(
      'SliverGrid',
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

export default SliverGrid;
