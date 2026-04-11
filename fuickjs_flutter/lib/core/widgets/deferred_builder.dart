import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 分帧构建组件
/// 
/// 将构建任务延迟到下一帧执行，避免阻塞当前帧
/// 适用于非首屏关键内容的延迟加载
class DeferredBuilder extends StatefulWidget {
  final WidgetBuilder builder;
  final Widget? placeholder;

  const DeferredBuilder({
    super.key,
    required this.builder,
    this.placeholder,
  });

  @override
  State<DeferredBuilder> createState() => _DeferredBuilderState();
}

class _DeferredBuilderState extends State<DeferredBuilder> {
  Widget? _child;

  @override
  void initState() {
    super.initState();
    // 延迟到下一帧构建
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (mounted) {
        setState(() {
          _child = widget.builder(context);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _child ?? widget.placeholder ?? const SizedBox.shrink();
  }
}

/// 分帧构建列表项
/// 
/// 对于 ListView/GridView 中的项目，可以延迟构建非可见项
class DeferredListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final int deferredAfter;

  const DeferredListItem({
    super.key,
    required this.index,
    required this.child,
    this.deferredAfter = 10,
  });

  @override
  Widget build(BuildContext context) {
    // 前 deferredAfter 项直接构建，后面的延迟构建
    if (index < deferredAfter) {
      return child;
    }
    return DeferredBuilder(
      placeholder: Container(
        height: 50,
        color: Colors.transparent,
      ),
      builder: (_) => child,
    );
  }
}
