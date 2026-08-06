import React, { ReactNode } from 'react';
import { WidgetProps } from './types';

export interface PointArgs {
  /** 本地坐标（相对手势组件） */
  dx: number;
  dy: number;
  /** 全局坐标 */
  globalX: number;
  globalY: number;
}

export interface ScaleArgs {
  /** 缩放比例（初始为 1） */
  scale: number;
  /** 水平缩放比例 */
  horizontalScale: number;
  /** 垂直缩放比例 */
  verticalScale: number;
  /** 焦点坐标（相对组件） */
  focalX: number;
  focalY: number;
  /** 触点数量 */
  pointerCount: number;
}

export interface DragArgs {
  /** 相对手势起点累计位移（Update）；Start 为 0 */
  dx: number;
  dy: number;
  /** 滑动速度（End 时有效，像素/秒） */
  velocityX: number;
  velocityY: number;
}

export interface GestureDetectorProps extends WidgetProps {
  onTapDown?: (args: PointArgs) => void;
  onTapCancel?: () => void;
  onTap?: () => void;
  onDoubleTap?: () => void;
  onLongPress?: () => void;
  /** 长按后开始拖动 */
  onLongPressStart?: (args: PointArgs) => void;
  /** 长按拖动中（高频） */
  onLongPressMoveUpdate?: (args: DragArgs) => void;
  /** 长按拖动结束 */
  onLongPressEnd?: (args: PointArgs) => void;
  onPanStart?: (args: PointArgs) => void;
  onPanUpdate?: (args: DragArgs) => void;
  onPanEnd?: (args: PointArgs) => void;
  /** 双指缩放开始 */
  onScaleStart?: (args: ScaleArgs) => void;
  /** 双指缩放中（高频） */
  onScaleUpdate?: (args: ScaleArgs) => void;
  /** 双指缩放结束 */
  onScaleEnd?: (args: ScaleArgs) => void;
  /** 水平拖动开始 */
  onHorizontalDragStart?: (args: DragArgs) => void;
  /** 水平拖动中（高频） */
  onHorizontalDragUpdate?: (args: DragArgs) => void;
  /** 水平拖动结束 */
  onHorizontalDragEnd?: (args: DragArgs) => void;
  /** 垂直拖动开始 */
  onVerticalDragStart?: (args: DragArgs) => void;
  /** 垂直拖动中（高频） */
  onVerticalDragUpdate?: (args: DragArgs) => void;
  /** 垂直拖动结束 */
  onVerticalDragEnd?: (args: DragArgs) => void;
}

export class GestureDetector extends React.Component<GestureDetectorProps> {
  render(): ReactNode {
    return React.createElement('GestureDetector', { ...this.props });
  }
}

export default GestureDetector;
