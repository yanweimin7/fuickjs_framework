import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface SizeTransitionProps extends BaseProps {
  /**
   * 动画/数值 0.0~1.0。
   *
   * - 未传 `duration`：以 `AlwaysStoppedAnimation` 包装为静态终态值（向后兼容）。
   * - 传 `duration`：通过 `TweenAnimationBuilder` 在前一次值与本值之间插值。
   */
  sizeFactor: number;
  /**
   * 'horizontal' | 'vertical'；默认 'vertical'。
   */
  axis?: 'horizontal' | 'vertical';
  /**
   * 当 axis 给定时，沿该轴的 alignment（解析为 Alignment）。
   */
  axisAlignment?: string;
  /**
   * 动画时长（毫秒）。未传或 ≤0 时走静态终态。
   */
  duration?: number;
  /**
   * 缓动曲线名称，见 WidgetUtils.parseCurve。
   */
  curve?: string;
}

export class SizeTransition extends React.Component<SizeTransitionProps> {
  render(): ReactNode {
    return React.createElement('SizeTransition', { ...this.props });
  }
}

export default SizeTransition;
