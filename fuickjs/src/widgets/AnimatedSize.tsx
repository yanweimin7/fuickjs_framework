import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export type AnimatedSizeCurve = 'linear' | 'ease' | 'easeIn' | 'easeOut' | 'easeInOut' | 'fastOutSlowIn' | 'decelerate';

export type AnimatedSizeAlignment =
  | 'topLeft'
  | 'topCenter'
  | 'topRight'
  | 'centerLeft'
  | 'center'
  | 'centerRight'
  | 'bottomLeft'
  | 'bottomCenter'
  | 'bottomRight';

export type AnimatedSizeAxis = 'horizontal' | 'vertical';

export interface AnimatedSizeProps extends BaseProps {
  /**
   * 动画时长（毫秒）。默认 300。
   */
  duration?: number;
  /**
   * 反向动画时长（毫秒）。缺省与 `duration` 相同。
   */
  reverseDuration?: number;
  /**
   * 动画曲线。
   */
  curve?: AnimatedSizeCurve;
  /**
   * 子节点对齐锚点（尺寸变化时围绕该点缩放）。默认 `center`。
   */
  alignment?: AnimatedSizeAlignment;
  /**
   * 限制仅在一个方向上做尺寸动画。`horizontal` / `vertical`。
   */
  axis?: AnimatedSizeAxis;
}

/**
 * AnimatedSize：子节点尺寸变化时自动插值过渡。
 *
 * 使用方式：包裹一个会动态改变 size 的子节点（通过 state 控制 width/height），
 * 切换状态时即触发动画。常用于展开/折叠、显示/隐藏容器。
 */
export class AnimatedSize extends React.Component<AnimatedSizeProps> {
  render(): ReactNode {
    return React.createElement('AnimatedSize', { ...this.props });
  }
}

export default AnimatedSize;
