import React, { ReactNode } from 'react';
import { WidgetProps, BoxDecoration } from './types';

export interface AnimatedContainerProps extends WidgetProps {
  width?: number;
  height?: number;
  color?: string;
  alignment?:
    | 'center'
    | 'topLeft'
    | 'topRight'
    | 'bottomLeft'
    | 'bottomRight'
    | 'centerLeft'
    | 'centerRight'
    | 'topCenter'
    | 'bottomCenter';
  decoration?: BoxDecoration;
  duration: number; // in milliseconds
  curve?: string; // 'linear', 'easeIn', 'easeOut', 'easeInOut', etc.
}

export class AnimatedContainer extends React.Component<AnimatedContainerProps> {
  render(): ReactNode {
    return React.createElement('AnimatedContainer', { ...this.props });
  }
}

export default AnimatedContainer;
