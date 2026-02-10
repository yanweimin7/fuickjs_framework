import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fuick_app_view.dart';

const debugRouteName = '/dev';

/// 调试专用的 FuickApp 页面
/// 负责处理 WebSocket 连接、接收重载信号并管理 [FuickAppView] 的生命周期
class DevFuickAppPage extends StatefulWidget {
  final bool useIsolate;
  final bool useAotCode;
  final String debugServerUrl;
  final RouteObserver<ModalRoute<void>>? routeObserver;

  const DevFuickAppPage({
    super.key,
    this.useIsolate = true,
    this.useAotCode = true,
    this.debugServerUrl = 'ws://127.0.0.1:8080',
    this.routeObserver,
  });

  @override
  State<DevFuickAppPage> createState() => _DevFuickAppPageState();
}

class _DevFuickAppPageState extends State<DevFuickAppPage> with RouteAware {
  WebSocketChannel? _wsChannel;
  bool _isShowingPreview = false;
  String? _lastDebugCode;

  // 这里需要访问全局的 routeObserver。由于这是一个 package，
  // 我们建议在应用层（main.dart）定义的 observer 通过某种方式传递，
  // 或者在此处定义一个约定好的静态变量。
  // 为了演示，我们假设它存在于 context 链中或者通过某种方式可访问。
  // 实际上，更通用的做法是在 DevFuickAppPage 增加一个 RouteObserver 参数。

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      widget.routeObserver?.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // 当有新页面覆盖当前页面时触发
    _isShowingPreview = true;
    debugPrint('[Dev] RouteAware: didPushNext (preview opened)');
  }

  @override
  void didPopNext() {
    // 当覆盖层页面关闭，回到当前页面时触发
    _isShowingPreview = false;
    debugPrint('[Dev] RouteAware: didPopNext (returned to debug console)');
  }

  @override
  void initState() {
    super.initState();
    _connectDebugServer();
  }

  void _connectDebugServer() {
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(widget.debugServerUrl));
      _wsChannel?.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'reload') {
            debugPrint('[Dev] Received reload signal and business payload');
            final payload = data['payload'];
            _handleReload(businessCode: payload?['business']);
          }
        },
        onError: (error) {
          debugPrint('[Dev] WebSocket error: $error');
        },
        onDone: () {
          debugPrint('[Dev] WebSocket closed, retrying in 3s...');
          Future.delayed(const Duration(seconds: 3), _connectDebugServer);
        },
      );
    } catch (e) {
      debugPrint('[Dev] Failed to connect to debug server: $e');
    }
  }

  Future<void> _handleReload({String? businessCode}) async {
    if (businessCode == null || businessCode.isEmpty) {
      debugPrint('[Dev] No business code received, skip reload');
      return;
    }

    try {
      _lastDebugCode = businessCode;
      debugPrint('[Dev] Received bundle code (length: ${businessCode.length})');

      if (!mounted) return;

      // 1. 如果当前已经打开了预览页面，先将其关闭
      if (_isShowingPreview) {
        Navigator.of(
          context,
        ).popUntil((e) => (e.settings.name) == debugRouteName);
        // 给一点点时间让 pop 动画执行或状态重置
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!mounted) return;

      // 2. 自动打开一个新页面加载 FuickAppView
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => FuickAppView(
            appName: 'dev_bundle',
            debugBusinessCode: _lastDebugCode,
          ),
        ),
      );
      debugPrint('[Dev] Opened new debug page with direct eval');
    } catch (e) {
      debugPrint('[Dev] Failed to handle reload: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuick Debug Console')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terminal, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              '等待调试代码推送...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Server: ${widget.debugServerUrl}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (_lastDebugCode != null) ...[
              const SizedBox(height: 24),
              const Text('状态: 已接收到最新代码'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '点击 PC 端 "r" 键可再次刷新',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    _wsChannel?.sink.close();
    super.dispose();
  }
}
