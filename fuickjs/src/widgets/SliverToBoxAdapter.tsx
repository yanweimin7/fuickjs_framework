import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export type SliverToBoxAdapterProps = WidgetProps;

export class SliverToBoxAdapter extends BaseWidget<SliverToBoxAdapterProps> {
  render(): ReactNode {
    const { children, ...rest } = this.props;
    return React.createElement(
      'SliverToBoxAdapter',
      {
        ...rest,
        isBoundary: true,
      },
      children,
    );
  }
}

export default SliverToBoxAdapter;
