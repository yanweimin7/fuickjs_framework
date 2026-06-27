import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface FadeTransitionProps extends BaseProps {
  /**
   * 0.0 ~ 1.0 之间的小数。
   *
   * - 未传 `duration`：以 `AlwaysStoppedAnimation` 包装为静态终态值（向后兼容）。
   * - 传 `duration`：通过 `TweenAnimationBuilder` 在前一次值与本值之间插值，
   *   实现淡入淡出动画。
   */
  opacity: number;
  /**
   * 动画时长（毫秒）。未传或 ≤0 时走静态终态。
   */
  duration?: number;
  /**
   * 缓动曲线名称，见 WidgetUtils.parseCurve：
   * `ease` / `easeIn` / `easeOut` / `easeInOut` / `linear` / `decelerate`
   * `fastOutSlowIn` / `bounceIn` / `bounceOut` / `bounceInOut`
   * `elasticIn` / `elasticOut` / `elasticInOut`。
   */
  curve?: string;
}

export class FadeTransition extends React.Component<FadeTransitionProps> {
  render(): ReactNode {
    return React.createElement('FadeTransition', { ...this.props });
  }
}

export default FadeTransition;
