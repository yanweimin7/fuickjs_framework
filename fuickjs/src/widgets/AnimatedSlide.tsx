import React, { ReactNode } from 'react';
import { BaseProps, Offset } from './types';

export interface AnimatedSlideProps extends BaseProps {
  offset: Offset;
  duration: number; // in milliseconds
  curve?: string;
}

export class AnimatedSlide extends React.Component<AnimatedSlideProps> {
  render(): ReactNode {
    return React.createElement('AnimatedSlide', { ...this.props });
  }
}

export default AnimatedSlide;
