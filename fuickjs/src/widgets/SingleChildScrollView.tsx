import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface SingleChildScrollViewProps extends WidgetProps {
  scrollDirection?: 'horizontal' | 'vertical';
  onScroll?: (e: { pixels: number; axis: 'vertical' | 'horizontal'; maxScrollExtent: number }) => void;
  onScrollStartReached?: () => void;
  onScrollEndReached?: () => void;
  startThreshold?: number;
  endThreshold?: number;
}

export class SingleChildScrollView extends BaseWidget<SingleChildScrollViewProps> {
  public animateTo(offset: number, duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('animateTo', { offset, duration, curve });
  }

  public scrollToTop(duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('scrollToTop', { duration, curve });
  }

  public scrollToBottom(duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('scrollToBottom', { duration, curve });
  }

  render(): ReactNode {
    return React.createElement('SingleChildScrollView', {
      ...this.props,
      refId: this.scopedRefId,
      isBoundary: true,
    });
  }
}

export default SingleChildScrollView;
