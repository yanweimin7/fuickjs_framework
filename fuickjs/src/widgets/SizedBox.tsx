import React, { ReactNode } from 'react';
import { WidgetProps } from './types';
import type { AnimationRef } from '../hooks/useAnimation';

export interface SizedBoxProps extends WidgetProps {
  /** 也支持动画引用：`<SizedBox width={anim.value} />` */
  width?: number | AnimationRef;
  /** 也支持动画引用：`<SizedBox height={anim.value} />` */
  height?: number | AnimationRef;
}

export class SizedBox extends React.Component<SizedBoxProps> {
  render(): ReactNode {
    return React.createElement('SizedBox', { ...this.props });
  }
}

export default SizedBox;
