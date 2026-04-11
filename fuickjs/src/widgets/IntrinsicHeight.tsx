import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export type IntrinsicHeightProps = WidgetProps;

export class IntrinsicHeight extends React.Component<IntrinsicHeightProps> {
  render(): ReactNode {
    return React.createElement('IntrinsicHeight', { ...this.props });
  }
}

export default IntrinsicHeight;
