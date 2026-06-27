import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface RotationTransitionProps extends BaseProps {
  /**
   * 旋转圈数（1.0 = 一圈）。未传 `duration` 时以静态终态显示；
   * 传 `duration` 时通过 `TweenAnimationBuilder` 在前一次值与本值之间插值。
   */
  turns: number;
  alignment?: string;
  /**
   * 动画时长（毫秒）。未传或 ≤0 时走静态终态。
   */
  duration?: number;
  /**
   * 缓动曲线名称，见 WidgetUtils.parseCurve。
   */
  curve?: string;
}

export class RotationTransition extends React.Component<RotationTransitionProps> {
  render(): ReactNode {
    return React.createElement('RotationTransition', { ...this.props });
  }
}

export default RotationTransition;
