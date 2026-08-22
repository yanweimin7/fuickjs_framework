import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import { BaseWidget } from './BaseWidget';

export interface RefreshIndicatorProps extends WidgetProps {
  onRefresh?: () => void;
  color?: string;
  backgroundColor?: string;
  refId?: string;
}

export class RefreshIndicator extends BaseWidget<RefreshIndicatorProps> {
  render(): ReactNode {
    return React.createElement('RefreshIndicator', {
      ...this.props,
      refId: this.scopedRefId,
    });
  }

  complete(): void {
    this.callNativeCommand('complete');
  }

  show(): void {
    this.callNativeCommand('show');
  }
}

export default RefreshIndicator;
