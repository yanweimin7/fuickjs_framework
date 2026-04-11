import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface ImageProps extends WidgetProps {
  /**
   * 图片来源，支持以下格式：
   * - 网络图片:  `https://example.com/img.png`
   * - Asset 图片: `assets/images/logo.png`
   * - 本地文件:  `/data/user/.../img.png` 或 `file:///data/user/.../img.png`
   * - base64:   `data:image/png;base64,...`
   * - SVG:      以上所有格式均支持 .svg 后缀
   *
   * 也可以用 `url` 属性（向后兼容），`src` 优先级更高。
   */
  src?: string;
  /** @deprecated 请使用 `src`，`url` 保持向后兼容 */
  url?: string;

  width?: number;
  height?: number;

  /**
   * 图片缩放模式（对应 Flutter BoxFit）
   * - `cover`     等比缩放并裁剪，填满容器
   * - `contain`   等比缩放，完整显示，不裁剪
   * - `fill`      拉伸填满，不保持比例
   * - `fitWidth`  宽度适配
   * - `fitHeight` 高度适配
   * - `none`      不缩放
   * - `scaleDown` 只缩小不放大
   */
  fit?: 'cover' | 'contain' | 'fill' | 'fitWidth' | 'fitHeight' | 'none' | 'scaleDown';

  /**
   * 图片颜色叠加（tint），以 BlendMode.srcIn 混合
   * 也可以用 `color`（向后兼容），`tintColor` 优先级更高
   */
  tintColor?: string;
  /** @deprecated 请使用 `tintColor` */
  color?: string;

  /**
   * 加载中占位背景色，默认 #f5f5f5
   * 仅对网络图片生效
   */
  placeholderColor?: string;

  /**
   * 加载失败时的备用图地址，支持与 src 相同的格式
   */
  errorSrc?: string;

  /**
   * 跨 URL 切换时是否保持旧图（避免闪白）
   * 仅对网络图片生效，默认 false
   */
  gaplessPlayback?: boolean;

  /** 图片加载完成回调 */
  onLoad?: () => void;
  /** 图片加载失败回调 */
  onError?: () => void;
}

export class Image extends React.Component<ImageProps> {
  render(): ReactNode {
    return React.createElement('Image', { ...this.props, isBoundary: false });
  }
}

export default Image;
