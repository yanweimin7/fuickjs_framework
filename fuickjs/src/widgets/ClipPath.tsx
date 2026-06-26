import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface ClipPathProps extends BaseProps {
  /**
   * CSS `clip-path` 值字符串，目前支持：
   *   - `circle(50%)`
   *   - `ellipse(50% 40%)`
   *   - `inset(10px)` / `inset(10px 20px round 8px)`
   *   - `polygon(50% 0%, 100% 100%, 0% 100%)`
   *
   * 不支持 `url()` / `path()`。
   */
  path: string;
}

/**
 * 自定义路径裁剪子节点。
 *
 * 内部根据 `path` 字符串自动选用 `ClipOval` / `ClipRRect` / `ClipPath`。
 */
export class ClipPath extends React.Component<ClipPathProps> {
  render(): ReactNode {
    return React.createElement('ClipPath', { ...this.props });
  }
}

export default ClipPath;
