import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface GestureDetectorProps extends WidgetProps {
  onTapDown?: () => void;
  onTapCancel?: () => void;
  onTap?: () => void;
  onDoubleTap?: () => void;
  onLongPress?: () => void;
  onPanStart?: (args: Record<string, unknown>) => void;
  onPanUpdate?: (args: Record<string, unknown>) => void;
  onPanEnd?: (args: Record<string, unknown>) => void;
}

export class GestureDetector extends React.Component<GestureDetectorProps> {
  render(): ReactNode {
    return React.createElement('GestureDetector', { ...this.props });
  }
}

export default GestureDetector;
