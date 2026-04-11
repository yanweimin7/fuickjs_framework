import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface PageViewProps extends WidgetProps {
  scrollDirection?: 'horizontal' | 'vertical';
  initialPage?: number;
  onPageChanged?: (index: number) => void;
  physics?: 'never' | 'bouncing' | 'clamping' | 'always';
  autoplay?: boolean;
  autoplayInterval?: number;
  circular?: boolean;
  indicatorDots?: boolean;
  indicatorColor?: string;
  indicatorActiveColor?: string;
}

export class PageView extends BaseWidget<PageViewProps> {
  public animateToPage(page: number, duration: number = 300, curve: string = 'easeInOut') {
    this.callNativeCommand('animateToPage', { page, duration, curve });
  }

  public jumpToPage(page: number) {
    this.callNativeCommand('jumpToPage', { page });
  }

  render(): ReactNode {
    const { children, ...otherProps } = this.props;

    return React.createElement(
      'PageView',
      {
        ...otherProps,
        refId: this.scopedRefId,
        isBoundary: true,
      },
      children,
    );
  }
}

export default PageView;
