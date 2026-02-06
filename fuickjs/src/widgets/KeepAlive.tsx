import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface KeepAliveProps extends WidgetProps {
  children?: ReactNode;
}

/**
 * KeepAlive component wraps its child to maintain its state in lists or tab views.
 */
export class KeepAlive extends React.Component<KeepAliveProps> {
  render(): ReactNode {
    return React.createElement('KeepAlive', { ...this.props, isBoundary: true });
  }
}

export default KeepAlive;
