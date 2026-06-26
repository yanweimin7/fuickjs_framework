import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface RotatedBoxProps extends BaseProps {
  /**
   * 旋转的 1/4 圈数。
   * 1 = 90°，2 = 180°，3 = 270°，负数 = 反向。
   */
  quarterTurns: number;
}

export class RotatedBox extends React.Component<RotatedBoxProps> {
  render(): ReactNode {
    return React.createElement('RotatedBox', { ...this.props });
  }
}

export default RotatedBox;
