import React, { ReactNode } from 'react';
import { BaseProps, Offset } from './types';
import type { AnimationTransformRef } from '../hooks/useAnimation';

export type TransformAlignment =
  | 'topLeft'
  | 'topCenter'
  | 'topRight'
  | 'centerLeft'
  | 'center'
  | 'centerRight'
  | 'bottomLeft'
  | 'bottomCenter'
  | 'bottomRight';

export interface TransformProps extends BaseProps {
  /**
   * 旋转弧度。等价于 `Transform.rotate(angle)`。
   * 支持动画引用：`<Transform rotate={anim.transform.rotate()} />`。
   */
  rotate?: number | AnimationTransformRef;
  /**
   * 缩放。传 number = x/y 等比；传 `{ x, y }` = 独立缩放。
   * 支持动画引用：`<Transform scale={anim.transform.scale()} />`（prop 决定轴）。
   */
  scale?: number | { x?: number; y?: number } | AnimationTransformRef;
  /**
   * 平移。`{ x, y }` 偏移量。
   * 支持动画引用：`<Transform translate={anim.transform.translateX()} />`。
   */
  translate?: { x: number; y: number } | AnimationTransformRef;
  /**
   * 4×4 矩阵（16 个 number 的一维数组）。与 rotate/scale/translate 互斥。
   */
  transform?: number[];
  /**
   * 对齐锚点（围绕哪个点旋转/缩放）。默认 `center`。
   */
  alignment?: TransformAlignment;
  /**
   * 显式原点偏移。`{ dx, dy }`，与 `alignment` 配合使用。
   */
  origin?: Offset;
}

export class Transform extends React.Component<TransformProps> {
  render(): ReactNode {
    return React.createElement('Transform', { ...this.props });
  }
}

export default Transform;
