import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface ScaleTransitionProps extends BaseProps {
  /**
   * 缩放比例。未传 `duration` 时以 `AlwaysStoppedAnimation` 包装为静态值；
   * 传 `duration` 时通过 `TweenAnimationBuilder` 在前一次值与本值之间插值。
   */
  scale: number;
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

export class ScaleTransition extends React.Component<ScaleTransitionProps> {
  render(): ReactNode {
    return React.createElement('ScaleTransition', { ...this.props });
  }
}

export default ScaleTransition;
