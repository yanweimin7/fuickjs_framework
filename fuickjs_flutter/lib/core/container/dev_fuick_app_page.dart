import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../logger.dart';
import 'fuick_app_view.dart';

const debugRouteName = '/dev';

/// 调试专用的 FuickApp 页面
/// 负责处理 WebSocket 连接、接收重载信号并管理 [FuickAppView] 的生命周期
class DevFuickAppPage extends StatefulWidget {
  final bool useIsolate;
  final bool useAotCode;
  final String debugServerUrl;

  const DevFuickAppPage({
    super.key,
    this.useIsolate = true,
    this.useAotCode = true,
    this.debugServerUrl = 'ws://127.0.0.1:8080',
  });

  @override
  State<DevFuickAppPage> createState() => _DevFuickAppPageState();
}

class _DevFuickAppPageState extends State<DevFuickAppPage> {
  WebSocketChannel? _wsChannel;
  bool _disposed = false;
  String? _lastDebugCode;
  Map<String, dynamic>? _lastSourceMap;
  String _lastAppName = 'bundle';
  String? _cachedBundleRoot;
  String? _assetsHash;

  String _makeAppName(String base) => '_dev_$base';

  @override
  void initState() {
    super.initState();
    _connectDebugServer();
  }

  void _connectDebugServer() {
    if (_disposed) return;
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(widget.debugServerUrl));
      _wsChannel?.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'reload') {
            logger.i('[Dev] Received reload signal and business payload');
            final payload = data['payload'];
            _handleReload(
              businessCode: payload?['business'],
              appName: payload?['appName'] as String? ?? 'bundle',
              sourceMap: payload?['sourceMap'] as Map<String, dynamic>?,
              assets: payload?['assets'] as Map<String, dynamic>?,
            );
          }
        },
        onError: (error) {
          logger.e('[Dev] WebSocket error: $error');
        },
        onDone: () {
          logger.w('[Dev] WebSocket closed, retrying in 3s...');
          Future.delayed(const Duration(seconds: 3), _connectDebugServer);
        },
      );
    } catch (e) {
      logger.e('[Dev] Failed to connect to debug server: $e');
    }
  }

  Future<void> _handleReload({
    String? businessCode,
    String appName = 'bundle',
    Map<String, dynamic>? sourceMap,
    Map<String, dynamic>? assets,
  }) async {
    if (businessCode == null || businessCode.isEmpty) {
      logger.w('[Dev] No business code received, skip reload');
      return;
    }

    try {
      _lastDebugCode = businessCode;
      _lastSourceMap = sourceMap;
      _lastAppName = appName;
      final debugAppName = _makeAppName(appName);

      if (assets != null) {
        _cachedBundleRoot = await _saveAssets(assets, appName);
      }

      if (!mounted) return;

      // pop 所有预览页（_dev_preview），不会误伤 /dev
      Navigator.of(context).popUntil(
        (route) => route.settings.name != '_dev_preview',
      );
      // CupertinoPageRoute pop 动画 400ms + dispose 数帧，
      // 等 1s 确保旧 FuickAppView.dispose() → releaseContext() 完成后再 push。
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      Navigator.of(context).push(
        CupertinoPageRoute(
          settings: const RouteSettings(name: '_dev_preview'),
          builder: (context) => FuickAppView(
            appName: debugAppName,
            debugBusinessCode: _lastDebugCode,
            sourceMap: _lastSourceMap,
            cachedBundleRoot: _cachedBundleRoot,
          ),
        ),
      );
      logger.d('[Dev] Opened new debug preview');
    } catch (e) {
      logger.e('[Dev] Failed to handle reload: $e');
    }
  }

  /// 将 assets base64 文件写入临时缓存目录，内容不变时跳过。
  Future<String?> _saveAssets(Map<String, dynamic> assets, String appName) async {
    final files = assets['files'] as Map<String, dynamic>?;
    final hash = assets['hash'] as String?;
    if (files == null || hash == null) return _cachedBundleRoot;
    if (hash == _assetsHash && _cachedBundleRoot != null) {
      return _cachedBundleRoot; // 没变化，复用
    }

    final dir = Directory(p.join(
      Directory.systemTemp.path,
      'fuick_debug_${appName}_$hash',
    ));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      for (final entry in files.entries) {
        // 与 zip 包结构对齐：<root>/assets/<rel>
        final file = File(p.join(dir.path, 'assets', entry.key));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(base64Decode(entry.value as String));
      }
    }
    _assetsHash = hash;
    logger.d('[Dev] Assets cached to ${dir.path} (${files.length} files)');
    return dir.path;
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
              Text('Bundle: $_lastAppName'
                  '${_lastSourceMap != null ? " (with sourcemap)" : ""}'),
              const SizedBox(height: 4),
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
    _disposed = true;
    _wsChannel?.sink.close();
    super.dispose();
  }
}
