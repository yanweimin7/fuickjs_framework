import React, { ReactNode } from 'react';
import { WidgetProps, BoxDecoration, BoxConstraints } from './types';
import type { AnimationRef } from '../hooks/useAnimation';

export interface ContainerProps extends WidgetProps {
  /** 也支持动画引用：`<Container width={anim.value} />` */
  width?: number | AnimationRef;
  /** 也支持动画引用：`<Container height={anim.value} />` */
  height?: number | AnimationRef;
  constraints?: BoxConstraints;
  color?: string;
  alignment?: 'center' | 'topLeft' | 'topRight' | 'bottomLeft' | 'bottomRight';
  decoration?: BoxDecoration;
  borderRadius?:
    | number
    | {
        topLeft?: number;
        topRight?: number;
        bottomLeft?: number;
        bottomRight?: number;
      };
  border?: {
    color?: string;
    width?: number;
  };
}

export class Container extends React.Component<ContainerProps> {
  render(): ReactNode {
    return React.createElement('Container', { ...this.props });
  }
}

export default Container;
