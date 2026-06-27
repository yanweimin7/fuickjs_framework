import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface RelativeRect {
  left?: number;
  top?: number;
  right?: number;
  bottom?: number;
}

export interface PositionedTransitionProps extends BaseProps {
  /**
   * 终态 rect（相对父 Stack 边界的偏移），与 Flutter RelativeRect.fromLTRB 语义一致。
   * 缺省视为 0。
   */
  end?: RelativeRect;
  /**
   * 起始 rect。仅在 `duration` > 0 时生效；缺省时与 `end` 相同（无动画起点）。
   */
  begin?: RelativeRect;
  /**
   * 动画时长（毫秒）。未传或 ≤0 时走静态终态常显 `end` 位置。
   */
  duration?: number;
  /**
   * 缓动曲线名称，见 WidgetUtils.parseCurve。
   */
  curve?: string;
}

/**
 * PositionedTransition：
 *
 * - 未传 `duration`：常显 `end` 位置（静态终态，向后兼容）。
 * - 传 `duration`：通过 `TweenAnimationBuilder` 在 `begin` 与 `end` 之间插值，
 *   实现 RelativeRect 平滑过渡。
 */
export class PositionedTransition extends React.Component<PositionedTransitionProps> {
  render(): ReactNode {
    return React.createElement('PositionedTransition', { ...this.props });
  }
}

export default PositionedTransition;
