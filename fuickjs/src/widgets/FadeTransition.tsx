import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface FadeTransitionProps extends BaseProps {
  /**
   * 0.0 ~ 1.0 之间的小数；解析端用 AlwaysStoppedAnimation 包装为静态值。
   */
  opacity: number;
}

export class FadeTransition extends React.Component<FadeTransitionProps> {
  render(): ReactNode {
    return React.createElement('FadeTransition', { ...this.props });
  }
}

export default FadeTransition;
