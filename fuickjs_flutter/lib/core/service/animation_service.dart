import '../logger.dart';
import '../utils/extensions.dart';
import '../widgets/fuick_animation.dart';
import '../widgets/widget_utils.dart';
import 'base_fuick_service.dart';

/// 程序化动画控制服务（对应 JS 侧 AnimationService）。
///
/// 命令按 `pageId:animId` 定位注册表条目并广播（同一 animId 可被多个 Widget 引用）：
/// - start    : 播放（loop 走 repeat；可覆盖 duration/curve/loop/reverse）
/// - stop     : 停止并保留当前值
/// - reverse  : 反向播放到 from
/// - reset    : 重置回 from（跳帧）
/// - setValue : 直接设置当前值（跳帧，按 spec 映射）
/// - setTo    : 动画过渡到指定值
///
/// 值 ↔ 控制器进度映射基于 DSL 引用里的初始 spec（from/to），
/// 命令中的 from/to 覆盖只用于计算映射目标，不改变绑定语义。
class AnimationService extends BaseFuickService {
  @override
  String get name => 'Animation';

  AnimationService() {
    registerAsyncMethod('start', (args) async {
      final m = _args(args);
      final entries = _entriesOf(m);
      if (entries == null) return false;
      final spec = _spec(m);
      for (final entry in entries) {
        if (spec != null) {
          entry.spec = entry.spec.copyWith(
            duration: spec.duration,
            curve: spec.curve,
            loop: spec.loop,
            reverse: spec.reverse,
          );
          if (spec.duration != null) {
            entry.controller.duration = spec.duration;
          }
        }
        final current = entry.spec;
        if (current.loop) {
          entry.controller.repeat(reverse: current.reverse);
        } else {
          entry.controller.forward(from: 0);
        }
      }
      return true;
    });

    registerAsyncMethod('stop', (args) async {
      final entries = _entriesOf(_args(args));
      if (entries == null) return false;
      for (final entry in entries) {
        entry.controller.stop();
      }
      return true;
    });

    registerAsyncMethod('reverse', (args) async {
      final entries = _entriesOf(_args(args));
      if (entries == null) return false;
      for (final entry in entries) {
        if (entry.controller.isAnimating) {
          entry.controller.reverse();
        } else {
          entry.controller.animateBack(0);
        }
      }
      return true;
    });

    registerAsyncMethod('reset', (args) async {
      final entries = _entriesOf(_args(args));
      if (entries == null) return false;
      for (final entry in entries) {
        entry.controller.value = 0;
      }
      return true;
    });

    registerAsyncMethod('setValue', (args) async {
      final m = _args(args);
      final entries = _entriesOf(m);
      if (entries == null) return false;
      final value = asDoubleOrNull(m['value']) ?? 0;
      for (final entry in entries) {
        entry.controller.value = entry.spec.progressFor(value);
      }
      return true;
    });

    registerAsyncMethod('setTo', (args) async {
      final m = _args(args);
      final entries = _entriesOf(m);
      if (entries == null) return false;
      final value = asDoubleOrNull(m['value']) ?? 0;
      final duration = Duration(
        milliseconds: (asIntOrNull(m['duration']) ?? 300).clamp(0, 3600000),
      );
      for (final entry in entries) {
        final curveName = m['curve'] as String?;
        await entry.controller.animateTo(
          entry.spec.progressFor(value),
          duration: duration,
          curve: curveName != null ? WidgetUtils.curve(curveName) : entry.spec.curve,
        );
      }
      return true;
    });
  }

  Map<String, dynamic> _args(dynamic args) {
    if (args is Map) return Map<String, dynamic>.from(args);
    if (args is List && args.isNotEmpty && args.first is Map) {
      return Map<String, dynamic>.from(args.first as Map);
    }
    return const {};
  }

  List<FuickAnimationEntry>? _entriesOf(Map<String, dynamic> m) {
    final pageId = asIntOrNull(m['pageId']);
    final animId = m['animId']?.toString();
    if (pageId == null || animId == null) return null;
    final key = FuickAnimationRegistry.keyOf(pageId, animId);
    final list = controller?.animationRegistry.entries(key);
    if (list == null || list.isEmpty) {
      logger.w('[Animation] no entry for $key (命令先于 DSL 渲染? 请确认 animId)');
    }
    return list;
  }

  /// 解析命令里可选的 spec 覆盖（duration/curve/loop/reverse）。
  AnimationSpec? _spec(Map<String, dynamic> m) {
    final raw = m['spec'];
    if (raw is! Map || raw.isEmpty) return null;
    final hasPlaybackFields = raw.containsKey('duration') ||
        raw.containsKey('curve') ||
        raw.containsKey('loop') ||
        raw.containsKey('reverse');
    if (!hasPlaybackFields) return null;
    return AnimationSpec(
      duration: asIntOrNull(raw['duration']) != null
          ? Duration(
              milliseconds:
                  (asIntOrNull(raw['duration']) ?? 300).clamp(0, 3600000),
            )
          : const Duration(milliseconds: 300),
      curve: WidgetUtils.curve(raw['curve'] as String?),
      loop: raw['loop'] == true,
      reverse: raw['reverse'] == true,
    );
  }
}
