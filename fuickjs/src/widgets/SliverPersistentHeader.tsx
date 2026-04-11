import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface SliverPersistentHeaderProps extends WidgetProps {
  pinned?: boolean;
  floating?: boolean;
  minExtent?: number;
  maxExtent?: number;
}

export class SliverPersistentHeader extends BaseWidget<SliverPersistentHeaderProps> {
  render(): ReactNode {
    const { children, ...rest } = this.props;
    return React.createElement(
      'SliverPersistentHeader',
      {
        ...rest,
      },
      children,
    );
  }
}

export default SliverPersistentHeader;
