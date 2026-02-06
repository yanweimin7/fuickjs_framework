import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface IntrinsicWidthProps extends WidgetProps {
  stepWidth?: number;
  stepHeight?: number;
}

export class IntrinsicWidth extends React.Component<IntrinsicWidthProps> {
  render(): ReactNode {
    return React.createElement('IntrinsicWidth', { ...this.props });
  }
}

export default IntrinsicWidth;
