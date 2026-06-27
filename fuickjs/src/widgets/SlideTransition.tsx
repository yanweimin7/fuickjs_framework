import React, { ReactNode } from 'react';
import { BaseProps, Offset } from './types';

export interface SlideTransitionProps extends BaseProps {
  /**
   * 平移偏移。未传 `duration` 时以静态终态显示；
   * 传 `duration` 时通过 `TweenAnimationBuilder` 在前一次值与本值之间插值。
   */
  position: Offset;
  transformHitTests?: boolean;
  /**
   * 动画时长（毫秒）。未传或 ≤0 时走静态终态。
   */
  duration?: number;
  /**
   * 缓动曲线名称，见 WidgetUtils.parseCurve。
   */
  curve?: string;
}

export class SlideTransition extends React.Component<SlideTransitionProps> {
  render(): ReactNode {
    return React.createElement('SlideTransition', { ...this.props });
  }
}

export default SlideTransition;
