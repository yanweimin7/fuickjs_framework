import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { ScrollableBaseWidget } from './ScrollableBaseWidget';

export interface GridViewProps extends WidgetProps {
  crossAxisCount: number;
  mainAxisSpacing?: number;
  crossAxisSpacing?: number;
  childAspectRatio?: number;
  itemCount?: number;
  itemBuilder?: (index: number) => ReactNode;
  shrinkWrap?: boolean;
  physics?: 'never' | 'bouncing' | 'clamping' | 'always';
  cacheKey?: unknown;
}

export class GridView extends ScrollableBaseWidget<GridViewProps> {
  public animateTo(offset: number, duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('animateTo', { offset, duration, curve });
  }

  render(): ReactNode {
    const { children, ...rest } = this.props;

    return React.createElement(
      'GridView',
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

export default GridView;
