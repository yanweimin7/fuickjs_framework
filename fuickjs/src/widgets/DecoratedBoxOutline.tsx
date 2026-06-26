import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface DecoratedBoxOutlineProps extends BaseProps {
  /**
   * 描边宽度，默认 1。
   */
  width?: number;
  /**
   * 描边颜色（HEX 字符串，如 `#000000`），默认黑色。
   */
  color?: string;
  /**
   * 描边与子元素之间的间距。默认 0（紧贴子元素）。
   */
  offset?: number;
}

/**
 * 在子节点外侧绘制一圈边框，对应 CSS `outline` 语义。
 *
 * 用 `DecoratedBox(position: foreground)` + 可选 `Padding` 实现。
 * 当前仅支持 `solid` 样式（Flutter 限制）。
 */
export class DecoratedBoxOutline extends React.Component<DecoratedBoxOutlineProps> {
  render(): ReactNode {
    return React.createElement('DecoratedBoxOutline', { ...this.props });
  }
}

export default DecoratedBoxOutline;
