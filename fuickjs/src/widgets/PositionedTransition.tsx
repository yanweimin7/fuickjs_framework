import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface PositionedTransitionProps extends BaseProps {
  /**
   * 终态 rect（相对父 Stack 边界的偏移），与 Flutter RelativeRect.fromLTRB 语义一致。
   * 缺省视为 0。begin 在解析端默认为 RelativeRect.zero。
   */
  end?: {
    left?: number;
    top?: number;
    right?: number;
    bottom?: number;
  };
}

/**
 * 静态终态版的 PositionedTransition：常显 end 位置。
 * 如需真正的过渡动画，请在外层用 TweenAnimationBuilder / AnimatedBuilder 包裹。
 */
export class PositionedTransition extends React.Component<PositionedTransitionProps> {
  render(): ReactNode {
    return React.createElement('PositionedTransition', { ...this.props });
  }
}

export default PositionedTransition;
