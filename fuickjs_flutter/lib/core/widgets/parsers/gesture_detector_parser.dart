import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class GestureDetectorParser extends WidgetParser {
  @override
  String get type => 'GestureDetector';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final dynamic onTapProp = props['onTap'];
    final dynamic onTapDownProp = props['onTapDown'];
    final dynamic onTapCancelProp = props['onTapCancel'];
    final dynamic onDoubleTapProp = props['onDoubleTap'];
    final dynamic onLongPressProp = props['onLongPress'];
    final dynamic onLongPressStartProp = props['onLongPressStart'];
    final dynamic onLongPressMoveUpdateProp = props['onLongPressMoveUpdate'];
    final dynamic onLongPressEndProp = props['onLongPressEnd'];
    final dynamic onPanStartProp = props['onPanStart'];
    final dynamic onPanUpdateProp = props['onPanUpdate'];
    final dynamic onPanEndProp = props['onPanEnd'];
    final dynamic onScaleStartProp = props['onScaleStart'];
    final dynamic onScaleUpdateProp = props['onScaleUpdate'];
    final dynamic onScaleEndProp = props['onScaleEnd'];
    final dynamic onHorizontalDragStartProp = props['onHorizontalDragStart'];
    final dynamic onHorizontalDragUpdateProp = props['onHorizontalDragUpdate'];
    final dynamic onHorizontalDragEndProp = props['onHorizontalDragEnd'];
    final dynamic onVerticalDragStartProp = props['onVerticalDragStart'];
    final dynamic onVerticalDragUpdateProp = props['onVerticalDragUpdate'];
    final dynamic onVerticalDragEndProp = props['onVerticalDragEnd'];

    final bool hasScale = onScaleStartProp != null ||
        onScaleUpdateProp != null ||
        onScaleEndProp != null;
    final bool hasHoriDrag = onHorizontalDragStartProp != null ||
        onHorizontalDragUpdateProp != null ||
        onHorizontalDragEndProp != null;
    final bool hasVertDrag = onVerticalDragStartProp != null ||
        onVerticalDragUpdateProp != null ||
        onVerticalDragEndProp != null;
    final bool hasLongPressMove = onLongPressStartProp != null ||
        onLongPressMoveUpdateProp != null ||
        onLongPressEndProp != null;

    return WidgetUtils.wrapPadding(
      props,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        // ---- 基础手势 ----
        onTapDown: onTapDownProp != null
            ? (details) => FuickAction.event(context, onTapDownProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy,
                  'globalX': details.globalPosition.dx,
                  'globalY': details.globalPosition.dy,
                })
            : null,
        onTapCancel: onTapCancelProp != null
            ? () => FuickAction.event(context, onTapCancelProp)
            : null,
        onTap: onTapProp != null
            ? () {
                FuickAction.event(context, onTapProp);
              }
            : null,
        onDoubleTap: onDoubleTapProp != null
            ? () => FuickAction.event(context, onDoubleTapProp)
            : null,
        onLongPress: onLongPressProp != null
            ? () => FuickAction.event(context, onLongPressProp)
            : null,

        // ---- 长按拖拽 ----
        onLongPressStart: onLongPressStartProp != null
            ? (details) => FuickAction.event(context, onLongPressStartProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy,
                  'globalX': details.globalPosition.dx,
                  'globalY': details.globalPosition.dy,
                })
            : null,
        onLongPressMoveUpdate: onLongPressMoveUpdateProp != null
            ? (details) => FuickAction.event(context, onLongPressMoveUpdateProp, value: {
                  'dx': details.offsetFromOrigin.dx,
                  'dy': details.offsetFromOrigin.dy,
                })
            : null,
        onLongPressEnd: onLongPressEndProp != null
            ? (details) => FuickAction.event(context, onLongPressEndProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy,
                  'globalX': details.globalPosition.dx,
                  'globalY': details.globalPosition.dy,
                })
            : null,

        // ---- 自由拖动（Pan）----
        onPanStart: onPanStartProp != null
            ? (details) => FuickAction.event(context, onPanStartProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy,
                  'globalX': details.globalPosition.dx,
                  'globalY': details.globalPosition.dy,
                })
            : null,
        onPanUpdate: onPanUpdateProp != null
            ? (details) => FuickAction.event(context, onPanUpdateProp, value: {
                  'dx': details.delta.dx,
                  'dy': details.delta.dy,
                  'globalX': details.globalPosition.dx,
                  'globalY': details.globalPosition.dy,
                })
            : null,
        onPanEnd: onPanEndProp != null
            ? (details) => FuickAction.event(context, onPanEndProp, value: {
                  'dx': details.velocity.pixelsPerSecond.dx,
                  'dy': details.velocity.pixelsPerSecond.dy,
                })
            : null,

        // ---- 双指缩放 ----
        onScaleStart: onScaleStartProp != null
            ? (details) => FuickAction.event(context, onScaleStartProp, value: {
                  'scale': 1.0,
                  'horizontalScale': 1.0,
                  'verticalScale': 1.0,
                  'focalX': details.localFocalPoint.dx,
                  'focalY': details.localFocalPoint.dy,
                  'pointerCount': details.pointerCount,
                })
            : null,
        onScaleUpdate: onScaleUpdateProp != null
            ? (details) => FuickAction.event(context, onScaleUpdateProp, value: {
                  'scale': details.scale,
                  'horizontalScale': details.horizontalScale,
                  'verticalScale': details.verticalScale,
                  'focalX': details.localFocalPoint.dx,
                  'focalY': details.localFocalPoint.dy,
                  'pointerCount': details.pointerCount,
                })
            : null,
        onScaleEnd: onScaleEndProp != null
            ? (details) => FuickAction.event(context, onScaleEndProp, value: {
                  'scale': 1.0,
                  'horizontalScale': 1.0,
                  'verticalScale': 1.0,
                  'velocityX': details.velocity.pixelsPerSecond.dx,
                  'velocityY': details.velocity.pixelsPerSecond.dy,
                  'pointerCount': details.pointerCount,
                })
            : null,

        // ---- 水平拖动 ----
        onHorizontalDragStart: onHorizontalDragStartProp != null
            ? (details) => FuickAction.event(context, onHorizontalDragStartProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy,
                  'velocityX': 0,
                  'velocityY': 0,
                })
            : null,
        onHorizontalDragUpdate: onHorizontalDragUpdateProp != null
            ? (details) => FuickAction.event(context, onHorizontalDragUpdateProp, value: {
                  'dx': details.delta.dx,
                  'dy': details.delta.dy,
                  'velocityX': 0,
                  'velocityY': 0,
                })
            : null,
        onHorizontalDragEnd: onHorizontalDragEndProp != null
            ? (details) => FuickAction.event(context, onHorizontalDragEndProp, value: {
                  'dx': details.primaryVelocity ?? 0,
                  'dy': 0,
                  'velocityX': details.primaryVelocity ?? 0,
                  'velocityY': 0,
                })
            : null,

        // ---- 垂直拖动 ----
        onVerticalDragStart: onVerticalDragStartProp != null
            ? (details) => FuickAction.event(context, onVerticalDragStartProp, value: {
                  'dx': details.localPosition.dx,
                  'dy': details.localPosition.dy,
                  'velocityX': 0,
                  'velocityY': 0,
                })
            : null,
        onVerticalDragUpdate: onVerticalDragUpdateProp != null
            ? (details) => FuickAction.event(context, onVerticalDragUpdateProp, value: {
                  'dx': details.delta.dx,
                  'dy': details.delta.dy,
                  'velocityX': 0,
                  'velocityY': 0,
                })
            : null,
        onVerticalDragEnd: onVerticalDragEndProp != null
            ? (details) => FuickAction.event(context, onVerticalDragEndProp, value: {
                  'dx': 0,
                  'dy': details.primaryVelocity ?? 0,
                  'velocityX': 0,
                  'velocityY': details.primaryVelocity ?? 0,
                })
            : null,

        child: factory.buildFirstChild(context, children, type),
      ),
    );
  }
}
