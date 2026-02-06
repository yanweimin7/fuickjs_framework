import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface SliverAppBarProps extends WidgetProps {
  title?: ReactNode;
  leading?: ReactNode;
  actions?: ReactNode[];
  expandedHeight?: number;
  pinned?: boolean;
  floating?: boolean;
  snap?: boolean;
  backgroundColor?: string;
  elevation?: number;
  toolbarHeight?: number;
  bottom?: ReactNode;
}

export class SliverAppBar extends BaseWidget<SliverAppBarProps> {
  render(): ReactNode {
    const { children, title, leading, actions, bottom, ...rest } = this.props;
    return React.createElement(
      'SliverAppBar',
      {
        ...rest,
        isBoundary: true,
        title: title,
        leading: leading,
        actions: actions,
        bottom: bottom,
      },
      children,
    );
  }
}

export default SliverAppBar;
