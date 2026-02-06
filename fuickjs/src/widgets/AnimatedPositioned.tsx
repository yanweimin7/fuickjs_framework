import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AnimatedPositionedProps extends BaseProps {
  left?: number;
  top?: number;
  right?: number;
  bottom?: number;
  width?: number;
  height?: number;
  duration: number; // in milliseconds
  curve?: string;
}

export class AnimatedPositioned extends React.Component<AnimatedPositionedProps> {
  render(): ReactNode {
    return React.createElement('AnimatedPositioned', { ...this.props });
  }
}

export default AnimatedPositioned;
