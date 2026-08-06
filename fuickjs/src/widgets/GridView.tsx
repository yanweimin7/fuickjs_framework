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
  /** 固定 item 高度/宽度（滚动方向上的尺寸）。提供后 scrollToIndex 可精确计算偏移 */
  itemExtent?: number;
}

export class GridView extends ScrollableBaseWidget<GridViewProps> {
  public animateTo(offset: number, duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('animateTo', { offset, duration, curve });
  }

  public jumpTo(offset: number) {
    this.callNativeCommand('jumpTo', { offset });
  }

  /**
   * 滚动到指定 index 的 item。
   * 配置了 itemExtent 时精确滚动；否则按列表估算平均尺寸（maxScrollExtent/itemCount）。
   * @param duration 传 > 0 时带动画（毫秒），否则瞬时跳转
   */
  public scrollToIndex(index: number, duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('scrollToIndex', { index, duration, curve });
  }

  /** 滚动到顶部（带动画） */
  public scrollToTop(duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('scrollToTop', { duration, curve });
  }

  /** 滚动到底部（带动画） */
  public scrollToBottom(duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('scrollToBottom', { duration, curve });
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
