import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export type BlendMode =
  | 'srcOver'
  | 'multiply'
  | 'screen'
  | 'overlay'
  | 'darken'
  | 'lighten'
  | 'colorDodge'
  | 'colorBurn'
  | 'hardLight'
  | 'softLight'
  | 'difference'
  | 'exclusion'
  | 'hue'
  | 'saturation'
  | 'color'
  | 'luminosity';

export interface ColorFilteredProps extends BaseProps {
  /**
   * 混合模式。对应 CSS `mix-blend-mode`。
   * 设为 `srcOver`（默认）时不会包任何 wrapper，等同直接渲染子节点。
   */
  blendMode: BlendMode;
}

/**
 * 对子节点应用颜色混合模式。
 *
 * 注意：Flutter 用 `ShaderMask` + 纯白渐变来近似 CSS `mix-blend-mode`，
 * 视觉效果与 Web 端不完全一致，但覆盖了最常见的 multiply/screen/overlay 等模式。
 */
export class ColorFiltered extends React.Component<ColorFilteredProps> {
  render(): ReactNode {
    return React.createElement('ColorFiltered', { ...this.props });
  }
}

export default ColorFiltered;
