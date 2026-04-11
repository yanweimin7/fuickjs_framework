import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface RefreshIndicatorProps extends WidgetProps {
  onRefresh?: () => void;
  color?: string;
  backgroundColor?: string;
  refId?: string;
}

export class RefreshIndicator extends React.Component<RefreshIndicatorProps> {
  render(): ReactNode {
    return React.createElement('RefreshIndicator', { ...this.props });
  }
}

export default RefreshIndicator;
