import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface PointerEvent {
  position: { dx: number; dy: number };
  localPosition: { dx: number; dy: number };
  pressure: number;
  delta: { dx: number; dy: number };
}

export interface PointerListenerProps extends WidgetProps {
  onPointerDown?: (event: PointerEvent) => void;
  onPointerMove?: (event: PointerEvent) => void;
  onPointerUp?: (event: PointerEvent) => void;
  onPointerCancel?: (event: PointerEvent) => void;
  behavior?: 'deferToChild' | 'opaque' | 'translucent';
}

export class PointerListener extends React.Component<PointerListenerProps> {
  render(): ReactNode {
    return React.createElement('PointerListener', { ...this.props, isBoundary: false });
  }
}

export default PointerListener;
