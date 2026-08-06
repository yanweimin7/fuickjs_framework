import React, { ReactNode } from 'react';
import { BaseProps } from './types';
import type { AnimationRef } from '../hooks/useAnimation';

export interface OpacityProps extends BaseProps {
  /** 透明度 0~1；也支持动画引用：`<Opacity opacity={anim.value} />` */
  opacity: number | AnimationRef;
}

export class Opacity extends React.Component<OpacityProps> {
  render(): ReactNode {
    return React.createElement('Opacity', { ...this.props, isBoundary: false });
  }
}

export default Opacity;
