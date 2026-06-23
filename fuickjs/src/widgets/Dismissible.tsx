import React, { ReactNode } from 'react';
import { BaseProps } from './types';

export type DismissibleDirection = 'horizontal' | 'vertical' | 'endToStart' | 'startToEnd' | 'up' | 'down' | 'none';

export interface DismissibleProps extends BaseProps {
  /**
   * 唯一 key（同一父级中必须唯一）。缺省使用 UniqueKey()。
   * 业务方建议显式传入，否则多个 Dismissible 同级会冲突。
   */
  key?: string;
  /**
   * 允许的滑动方向。默认 `horizontal`。
   */
  direction?: DismissibleDirection;
  /**
   * 滑动到边界后松手时，是否在背景消失阶段的过渡时长（毫秒）。默认 300。
   */
  resizeDuration?: number;
  /**
   * 跟随手指的拖动时长（毫秒）。默认 200。
   */
  movementDuration?: number;
  /**
   * 滑动到 dismiss 阈值的额外距离（按主轴负方向，0~1）。
   */
  crossAxisEndOffset?: number;
  /**
   * 滑动时显示的背景（左/上方向）。DSL 子树。
   */
  background?: { type: string; props?: Record<string, unknown>; children?: unknown };
  /**
   * 反方向（endToStart / down）显示的背景。
   */
  secondaryBackground?: {
    type: string;
    props?: Record<string, unknown>;
    children?: unknown;
  };
  /**
   * 真正完成 dismiss 时触发，参数为 `DismissDirection` 名称
   *（'horizontal' / 'vertical' / 'endToStart' / 'startToEnd' / 'up' / 'down' / 'none'）。
   * 业务方应在此事件里**同步从列表数据源移除该项**，否则下次重建会闪回。
   */
  onDismissed?: (direction: string) => void;
  /**
   * 松手时触发，参数为 `DismissDirection` 名称。同步 fallback：返回 true 立即 dismiss。
   */
  onConfirmDismiss?: (direction: string) => void;
  /**
   * 拖动时持续触发，参数为 reason 名称（`dismissed` / `swiped` / ...）。
   */
  onUpdate?: (reason: string) => void;
  /**
   * 子节点消失后的 resize 动画结束时触发。
   */
  onResize?: () => void;
}

/**
 * Dismissible：可滑动删除/归档的列表项。
 *
 * 通常搭配 `ListView` 一起使用，监听 `onDismissed` 删除数据源中的对应项。
 */
export class Dismissible extends React.Component<DismissibleProps> {
  render(): ReactNode {
    return React.createElement('Dismissible', { ...this.props });
  }
}

export default Dismissible;
