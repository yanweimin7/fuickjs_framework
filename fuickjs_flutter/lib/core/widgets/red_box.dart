import 'dart:async';

import 'package:flutter/material.dart';

import '../service/js_error_bus.dart';

/// 开发阶段红屏错误提示，类似 React Native 的 Red Box。
///
/// 监听 [JsErrorBus]，收到未捕获 JS 异常时全屏红屏显示错误信息和堆栈。
/// 仅在 debug 模式下由 [FuickAppView] 挂载。
class RedBoxOverlay extends StatefulWidget {
  final Widget child;

  const RedBoxOverlay({super.key, required this.child});

  @override
  State<RedBoxOverlay> createState() => _RedBoxOverlayState();
}

class _RedBoxOverlayState extends State<RedBoxOverlay> {
  JsErrorInfo? _error;
  StreamSubscription<JsErrorInfo>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = JsErrorBus.instance.stream.listen((error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _dismiss() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_error != null)
          Positioned.fill(
            child: Material(
              color: const Color(0xCCFF0000),
              child: _RedBoxContent(
                error: _error!,
                onDismiss: _dismiss,
              ),
            ),
          ),
      ],
    );
  }
}

class _RedBoxContent extends StatelessWidget {
  final JsErrorInfo error;
  final VoidCallback onDismiss;

  const _RedBoxContent({required this.error, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '[${error.source}] ${error.message}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
            if (error.stack != null && error.stack!.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    error.stack!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            if (error.detail != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Detail: ${error.detail}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
