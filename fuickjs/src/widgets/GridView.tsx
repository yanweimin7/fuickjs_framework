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
  /** 滚动位置变化回调（高频，每次滚动像素变化都触发） */
  onScroll?: (e: { pixels: number; axis: 'vertical' | 'horizontal'; maxScrollExtent: number }) => void;
  /** 滚动到顶部阈值内触发 */
  onScrollStartReached?: () => void;
  /** 滚动到底部阈值内触发 */
  onScrollEndReached?: () => void;
  /** 顶部阈值，默认 50 */
  startThreshold?: number;
  /** 底部阈值，默认 50 */
  endThreshold?: number;
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
