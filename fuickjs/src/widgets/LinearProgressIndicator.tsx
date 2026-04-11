import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface LinearProgressIndicatorProps extends WidgetProps {
  value?: number;
  color?: string;
  backgroundColor?: string;
  strokeWidth?: number;
  borderRadius?: number;
}

export class LinearProgressIndicator extends React.Component<LinearProgressIndicatorProps> {
  render(): ReactNode {
    return React.createElement('LinearProgressIndicator', { ...this.props, isBoundary: false });
  }
}

export default LinearProgressIndicator;
