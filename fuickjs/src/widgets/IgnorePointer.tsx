import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface IgnorePointerProps extends BaseProps {
  /**
   * 是否忽略命中测试。true = 子树不接收事件，false = 正常接收。
   * 默认 true。
   */
  ignoring?: boolean;
}

export class IgnorePointer extends React.Component<IgnorePointerProps> {
  render(): ReactNode {
    return React.createElement('IgnorePointer', { ...this.props });
  }
}

export default IgnorePointer;
