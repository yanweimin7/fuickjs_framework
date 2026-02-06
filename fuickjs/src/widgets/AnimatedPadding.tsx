import React, { ReactNode } from 'react';
import { BaseProps, EdgeInsets } from './types';

export interface AnimatedPaddingProps extends BaseProps {
  padding: number | EdgeInsets;
  duration: number; // in milliseconds
  curve?: string;
}

export class AnimatedPadding extends React.Component<AnimatedPaddingProps> {
  render(): ReactNode {
    return React.createElement('AnimatedPadding', { ...this.props });
  }
}

export default AnimatedPadding;
