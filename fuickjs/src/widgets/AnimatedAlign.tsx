import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface AnimatedAlignProps extends BaseProps {
  alignment:
    | 'topLeft'
    | 'topCenter'
    | 'topRight'
    | 'centerLeft'
    | 'center'
    | 'centerRight'
    | 'bottomLeft'
    | 'bottomCenter'
    | 'bottomRight';
  duration: number; // in milliseconds
  curve?: string;
}

export class AnimatedAlign extends React.Component<AnimatedAlignProps> {
  render(): ReactNode {
    return React.createElement('AnimatedAlign', { ...this.props });
  }
}

export default AnimatedAlign;
