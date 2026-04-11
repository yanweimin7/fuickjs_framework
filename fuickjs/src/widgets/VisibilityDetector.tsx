import React, { ReactNode } from 'react';
import { BaseWidget } from './BaseWidget';
import { WidgetProps } from './types';

export interface VisibilityInfo {
  visibleFraction: number;
  size: { width: number; height: number };
  visibleBounds: { left: number; top: number; width: number; height: number };
}

export interface VisibilityDetectorProps extends WidgetProps {
  onVisibilityChanged?: (info: VisibilityInfo) => void;
  /**
   * Key is required for VisibilityDetector to identify the widget.
   * If not provided, it will fallback to refId or auto-generated key on native side,
   * but it's recommended to provide a stable key or refId.
   */
}

export class VisibilityDetector extends BaseWidget<VisibilityDetectorProps> {
  protected get widgetType(): string {
    return 'VisibilityDetector';
  }

  render(): ReactNode {
    return React.createElement('VisibilityDetector', {
      ...this.props,
      refId: this.scopedRefId,
    }, this.props.children);
  }
}
