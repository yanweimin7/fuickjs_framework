import 'dart:async';

import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:flutter/material.dart';

import '../engine/fuick_app_context_manager.dart';

/// QuickJS 引擎内存监控浮层。
///
/// 定时通过 [FuickAppContextManager] 拿到对应 appName 的 [IQuickJsContext],
/// 调用 [IQuickJsContext.computeMemoryUsage] 拉取 runtime 内存快照,
/// 在右上角半透明面板里展示。底层走 native 的 `JS_ComputeMemoryUsage`,
/// C 层零分配,仅经一次跨 isolate IPC,适合高频轮询。
///
/// 通过 [FuickAppView.showMemoryMonitor] 启用,或直接嵌入到任意页面。
class MemoryMonitorOverlay extends StatefulWidget {
  /// 监控的 bundle appName,需与 FuickAppView.appName 一致。
  final String appName;

  /// 刷新间隔。默认 500ms,平衡实时性与 IPC 开销。
  final Duration refreshInterval;

  /// 浮层距父容器顶部的偏移。
  final double top;

  /// 浮层距父容器右侧的偏移。
  final double right;

  const MemoryMonitorOverlay({
    super.key,
    required this.appName,
    this.refreshInterval = const Duration(milliseconds: 500),
    this.top = 8,
    this.right = 8,
  });

  @override
  State<MemoryMonitorOverlay> createState() => _MemoryMonitorOverlayState();
}

class _MemoryMonitorOverlayState extends State<MemoryMonitorOverlay> {
  final ValueNotifier<JSMemoryUsage?> _notifier =
      ValueNotifier<JSMemoryUsage?>(null);
  Timer? _timer;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final ctx = FuickAppContextManager().getContext(widget.appName)?.ctx;
      // Web 端 ctx 是 HostJsContext（非引擎上下文），无 runGC/computeMemoryUsage；
      // 本浮层是 QuickJS 内存监控，Web 上直接跳过。
      if (ctx is! IQuickJsContext) return;
      // 采样前先 GC,确保测到的是真实可达对象而非待回收垃圾。
      await ctx.runGC();
      final usage = await ctx.computeMemoryUsage();
      if (mounted) _notifier.value = usage;
    } catch (_) {
      // context 还没 ready 或已 dispose,下次 tick 重试。
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      right: widget.right,
      child: IgnorePointer(
        child: Material(
          color: const Color.fromRGBO(0, 0, 0, 0.72),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ValueListenableBuilder<JSMemoryUsage?>(
              valueListenable: _notifier,
              builder: (_, usage, __) {
                if (usage == null) {
                  return const Text(
                    'measuring...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'JS Engine Memory',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MemoryRow('malloc', usage.mallocSize),
                    _MemoryRow('used', usage.memoryUsedSize),
                    const _Divider(),
                    _MemoryRow('jsFuncCode', usage.jsFuncCodeSize),
                    _MemoryRow('atom', usage.atomSize, count: usage.atomCount),
                    _MemoryRow('obj', usage.objSize, count: usage.objCount),
                    _MemoryRow('str', usage.strSize, count: usage.strCount),
                    _MemoryRow('prop', usage.propSize),
                    _MemoryRow('shape', usage.shapeSize),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  final String label;
  final int bytes;
  final int? count;

  const _MemoryRow(this.label, this.bytes, {this.count});

  @override
  Widget build(BuildContext context) {
    final countSuffix = count == null ? '' : '  ($count)';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            '${_fmtBytes(bytes)}$countSuffix',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: 140,
        child: Divider(
          height: 1,
          color: Colors.white24,
        ),
      ),
    );
  }
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}
