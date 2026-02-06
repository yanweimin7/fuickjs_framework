import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AnimatedScaleProps extends BaseProps {
  scale: number;
  duration: number; // in milliseconds
  curve?: string;
}

export class AnimatedScale extends React.Component<AnimatedScaleProps> {
  render(): ReactNode {
    return React.createElement('AnimatedScale', { ...this.props });
  }
}

export default AnimatedScale;
