import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export interface HeroProps extends BaseProps {
  /**
   * 唯一标识。源 / 目标页中两个 `Hero` 的 `tag` 相同则会自动联动飞行动画。
   */
  tag: string;
  /**
   * 子节点（必须为单 child）。
   */
}

export class Hero extends React.Component<HeroProps> {
  render(): ReactNode {
    return React.createElement('Hero', { ...this.props });
  }
}

export default Hero;
