import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AnimatedOpacityProps extends BaseProps {
  opacity: number;
  duration: number; // in milliseconds
  curve?: string;
}

export class AnimatedOpacity extends React.Component<AnimatedOpacityProps> {
  render(): ReactNode {
    return React.createElement('AnimatedOpacity', { ...this.props });
  }
}

export default AnimatedOpacity;
