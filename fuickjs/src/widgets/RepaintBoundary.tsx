import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export class RepaintBoundary extends React.Component<WidgetProps> {
  render(): ReactNode {
    return React.createElement('RepaintBoundary', { ...this.props, isBoundary: true });
  }
}

export default RepaintBoundary;
