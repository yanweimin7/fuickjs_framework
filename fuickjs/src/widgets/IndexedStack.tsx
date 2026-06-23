import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export type IndexedStackAlignment =
  | 'topLeft'
  | 'topCenter'
  | 'topRight'
  | 'centerLeft'
  | 'center'
  | 'centerRight'
  | 'bottomLeft'
  | 'bottomCenter'
  | 'bottomRight';

export type IndexedStackSizing = 'stack' | 'loose';

export interface IndexedStackProps extends BaseProps {
  /**
   * 当前显示的子节点下标。
   */
  index: number;
  /**
   * 子节点对齐方式，默认 `topLeft`（与 Stack 一致）。
   */
  alignment?: IndexedStackAlignment;
  /**
   * 子节点布局行为：
   *   - `stack` (默认)：扩展到 IndexedStack 自身大小
   *   - `loose`：按子节点自身尺寸
   */
  sizing?: IndexedStackSizing;
}

/**
 * IndexedStack：所有子节点都会被构建（state 保留），但仅显示 `index` 指定的子节点。
 *
 * 适合做"切换不重建"的 Tab 内容区，与 PageView 配合可保留每个 Tab 的滚动位置/状态。
 */
export class IndexedStack extends React.Component<IndexedStackProps> {
  render(): ReactNode {
    return React.createElement('IndexedStack', { ...this.props });
  }
}

export default IndexedStack;
