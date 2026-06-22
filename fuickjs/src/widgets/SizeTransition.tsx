import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface SizeTransitionProps extends BaseProps {
  /**
   * 动画/数值 0.0~1.0；解析端用 AlwaysStoppedAnimation 包装为静态值。
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
}

export class SizeTransition extends React.Component<SizeTransitionProps> {
  render(): ReactNode {
    return React.createElement('SizeTransition', { ...this.props });
  }
}

export default SizeTransition;
