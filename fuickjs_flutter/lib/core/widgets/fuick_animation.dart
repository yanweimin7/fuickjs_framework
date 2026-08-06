import 'package:flutter/material.dart';

import '../container/fuick_app_controller.dart';
import '../container/fuick_page_view.dart';
import '../utils/extensions.dart';
import 'widget_utils.dart';

/// DSL 动画引用识别：`{ "@anim": id, "spec": {...}, "prop"?: "scale" }`
class FuickAnim {
  const FuickAnim._();

  static bool isRef(dynamic value) => value is Map && value['@anim'] is String;

  static String idOf(Map ref) => ref['@anim'].toString();

  static AnimationSpec specOf(Map ref) {
    final raw = ref['spec'];
    return AnimationSpec.fromMap(raw is Map ? raw : const {});
  }

  /// 变换动画的轴向（仅 Transform 使用）
  static String? propOf(Map ref) {
    final p = ref['prop'];
    return p is String ? p : null;
  }

  /// 将 builder 包裹为动画驱动 Widget；非动画引用时返回 null。
  static Widget? wrapIfRef(
    BuildContext context,
    dynamic ref, {
    required Widget Function(BuildContext, Animation<double>) builder,
  }) {
    if (!isRef(ref)) return null;
    final spec = specOf(ref);
    return FuickAnimated(
      animId: idOf(ref),
      spec: spec,
      builder: builder,
    );
  }
}

/// 动画规格（对应 JS 侧 useAnimation 的 spec 字段）。
class AnimationSpec {
  final double from;
  final double to;
  final Duration duration;
  final Curve curve;
  final bool loop;
  final bool reverse;
  final bool autoStart;

  const AnimationSpec({
    this.from = 0,
    this.to = 1,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.loop = false,
    this.reverse = false,
    this.autoStart = false,
  });

  factory AnimationSpec.fromMap(dynamic map) {
    if (map is! Map) return const AnimationSpec();
    return AnimationSpec(
      from: asDoubleOrNull(map['from']) ?? 0,
      to: asDoubleOrNull(map['to']) ?? 1,
      duration: Duration(
        milliseconds: (asIntOrNull(map['duration']) ?? 300).clamp(0, 3600000),
      ),
      curve: WidgetUtils.curve(map['curve'] as String?),
      loop: map['loop'] == true,
      reverse: map['reverse'] == true,
      autoStart: map['autoStart'] == true,
    );
  }

  AnimationSpec copyWith({
    double? from,
    double? to,
    Duration? duration,
    Curve? curve,
    bool? loop,
    bool? reverse,
  }) {
    return AnimationSpec(
      from: from ?? this.from,
      to: to ?? this.to,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      loop: loop ?? this.loop,
      reverse: reverse ?? this.reverse,
      autoStart: autoStart,
    );
  }

  /// 控制器进度 t（0..1）→ 实际动画值
  double evaluate(double t) => from + (to - from) * t;

  /// 实际动画值 → 控制器进度 t（0..1），越界钳制
  double progressFor(double value) {
    final span = to - from;
    if (span == 0) return 0;
    return ((value - from) / span).clamp(0.0, 1.0);
  }
}

/// 注册表条目：AnimationController + 当前 spec（命令侧按 spec 做值↔进度映射）。
class FuickAnimationEntry {
  final AnimationController controller;
  AnimationSpec spec;

  FuickAnimationEntry(this.controller, this.spec);
}

/// 页面级动画控制器注册表（挂在 FuickAppController 上）。
///
/// key = `pageId:animId`，同一 animId 可能被多个 Widget 引用，
/// 每个引用各自持有 controller（同 spec 同时播放，视觉一致），
/// 控制命令（start/stop...）广播到该 key 下所有条目。
class FuickAnimationRegistry {
  final Map<String, List<FuickAnimationEntry>> _entries = {};

  static String keyOf(int pageId, String animId) => '$pageId:$animId';

  void register(String key, FuickAnimationEntry entry) {
    _entries.putIfAbsent(key, () => []).add(entry);
  }

  void unregister(String key, FuickAnimationEntry entry) {
    final list = _entries[key];
    if (list == null) return;
    list.remove(entry);
    if (list.isEmpty) _entries.remove(key);
  }

  List<FuickAnimationEntry>? entries(String key) => _entries[key];

  void disposeAll() {
    for (final list in _entries.values) {
      for (final entry in list) {
        if (entry.controller.isAnimating) entry.controller.stop();
        entry.controller.dispose();
      }
    }
    _entries.clear();
  }
}

/// 将 Flutter 动画值绑定到 DSL 属性上的驱动 Widget。
///
/// 创建 AnimationController 并注册到 [FuickAnimationRegistry]，按 spec 播放；
/// 动画完成后通过 'animationComplete' 事件通知 JS 侧 useAnimation。
class FuickAnimated extends StatefulWidget {
  final String animId;
  final AnimationSpec spec;
  final Widget Function(BuildContext, Animation<double>) builder;

  const FuickAnimated({
    super.key,
    required this.animId,
    required this.spec,
    required this.builder,
  });

  @override
  State<FuickAnimated> createState() => _FuickAnimatedState();
}

class _FuickAnimatedState extends State<FuickAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late AnimationSpec _spec;
  late Animation<double> _valueAnimation;
  FuickAnimationRegistry? _registry;
  FuickAnimationEntry? _entry;
  String? _registryKey;

  @override
  void initState() {
    super.initState();
    _spec = widget.spec;
    _controller = AnimationController(
      vsync: this,
      duration: _spec.duration,
    );
    _controller.addStatusListener(_onStatus);
    _valueAnimation = _buildValueAnimation();

    final pageId = FuickPageScope.find(context)?.pageId;
    _registry = FuickAppScope.find(context)?.animationRegistry;
    if (pageId != null) {
      _entry = FuickAnimationEntry(_controller, _spec);
      _registryKey = FuickAnimationRegistry.keyOf(pageId, widget.animId);
      _registry?.register(_registryKey!, _entry!);
    }

    if (_spec.autoStart) {
      _play();
    }
  }

  Animation<double> _buildValueAnimation() {
    return Tween<double>(begin: _spec.from, end: _spec.to)
        .chain(CurveTween(curve: _spec.curve))
        .animate(_controller);
  }

  void _play() {
    if (_spec.loop) {
      _controller.repeat(reverse: _spec.reverse);
    } else {
      _controller.forward(from: 0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_spec.loop) {
      _emitComplete();
    }
  }

  void _emitComplete() {
    final controller = FuickAppScope.find(context);
    if (controller == null) return;
    try {
      controller.jsProxy.ctx.invoke('NativeEvent', 'receive', [
        'animationComplete',
        {'animId': widget.animId},
      ]);
    } catch (e) {
      // ignore
    }
  }

  @override
  void didUpdateWidget(FuickAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spec.duration != oldWidget.spec.duration) {
      _controller.duration = widget.spec.duration;
    }
    if (widget.spec.from != oldWidget.spec.from ||
        widget.spec.to != oldWidget.spec.to ||
        widget.spec.curve != oldWidget.spec.curve) {
      _spec = widget.spec;
      _valueAnimation = _buildValueAnimation();
      _entry?.spec = _spec;
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    if (_registryKey != null) {
      _registry?.unregister(_registryKey!, _entry!);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _valueAnimation,
      builder: (context, _) => widget.builder(context, _valueAnimation),
    );
  }
}
