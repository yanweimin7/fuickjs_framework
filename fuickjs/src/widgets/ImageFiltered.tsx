import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface ImageFilteredProps extends BaseProps {
  /**
   * 水平方向高斯模糊 sigma 值。
   */
  sigmaX?: number;
  /**
   * 垂直方向高斯模糊 sigma 值。缺省等于 sigmaX。
   */
  sigmaY?: number;
}

/**
 * 对子节点应用图像后处理（目前仅支持高斯模糊）。
 *
 * 等价于 CSS `filter: blur(Npx)`。
 */
export class ImageFiltered extends React.Component<ImageFilteredProps> {
  render(): ReactNode {
    return React.createElement('ImageFiltered', { ...this.props });
  }
}

export default ImageFiltered;
