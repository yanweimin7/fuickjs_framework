import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AnimatedRotationProps extends BaseProps {
  turns: number;
  duration: number; // in milliseconds
  curve?: string;
}

export class AnimatedRotation extends React.Component<AnimatedRotationProps> {
  render(): ReactNode {
    return React.createElement('AnimatedRotation', { ...this.props });
  }
}

export default AnimatedRotation;
