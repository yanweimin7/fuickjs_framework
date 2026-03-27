import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../logger.dart';
import '../utils/extensions.dart';
import 'base_fuick_service.dart';

class WebSocketService extends BaseFuickService {
  @override
  String get name => 'WebSocket';

  bool _isDisposed = false;
  final Map<String, WebSocketChannel> _sockets = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  WebSocketService() {
    registerAsyncMethod('connect', _handleConnect);
    registerMethod('send', _handleSend);
    registerMethod('close', _handleClose);
  }

  Future<Map<String, dynamic>> _handleConnect(dynamic args) async {
    try {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? socketId = options['socketId']?.toString();
      final String? url = options['url']?.toString();
      final List<dynamic> protocols = (options['protocols'] as List<dynamic>?) ?? [];

      if (socketId == null || socketId.isEmpty) {
        return {'success': false, 'error': 'Socket ID is required'};
      }

      if (url == null || url.isEmpty) {
        return {'success': false, 'error': 'URL is required'};
      }

      // Close existing socket with same ID if any
      await _closeSocket(socketId);

      logger.i('[WebSocketService] Connecting to $url with socketId: $socketId');

      final wsUrl = Uri.parse(url);
      final socket = WebSocketChannel.connect(
        wsUrl,
        protocols: protocols.isNotEmpty ? protocols.cast<String>() : null,
      );

      _sockets[socketId] = socket;

      // Wait for connection to be established
      await socket.ready;

      logger.i('[WebSocketService] Connected to $url');

      // Listen for messages
      _subscriptions[socketId] = socket.stream.listen(
        (message) {
          _handleMessage(socketId, message);
        },
        onError: (error) {
          logger.e('[WebSocketService] Error on socket $socketId: $error');
          _handleError(socketId, error.toString());
        },
        onDone: () {
          logger.i('[WebSocketService] Socket $socketId closed');
          _handleCloseEvent(socketId);
        },
      );

      return {
        'success': true,
        'protocol': socket.protocol ?? '',
        'extensions': '',
      };
    } catch (e, s) {
      logger.e('[WebSocketService] Error connecting: $e\n$s');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  void _handleMessage(String socketId, dynamic message) {
    if (_isDisposed) return;
    try {
      String data;
      bool isBinary = false;

      if (message is String) {
        data = message;
      } else if (message is List<int>) {
        // Binary data - encode as base64
        data = base64Encode(message);
        isBinary = true;
      } else if (message is Uint8List) {
        data = base64Encode(message);
        isBinary = true;
      } else {
        data = message.toString();
      }

      // Call JS handler
      final jsHandler = '_ws_$socketId';
      final escapedData = data.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '\\r');
      final jsCode = isBinary
          ? '''(function() { var socket = globalThis["$jsHandler"]; if (socket && socket._handleMessage) { socket._handleMessage(base64ToArrayBuffer("$escapedData")); } })();'''
          : '''(function() { var socket = globalThis["$jsHandler"]; if (socket && socket._handleMessage) { socket._handleMessage("$escapedData"); } })();''';
      ctx.eval(jsCode);
    } catch (e, s) {
      logger.e('[WebSocketService] Error handling message: $e\n$s');
    }
  }

  void _handleCloseEvent(String socketId) {
    if (_isDisposed) return;
    try {
      final socket = _sockets[socketId];
      if (socket == null) return;

      final closeCode = socket.closeCode ?? 1006;
      final closeReason = socket.closeReason ?? '';
      final wasClean = closeCode == 1000;

      // Call JS handler
      final jsHandler = '_ws_$socketId';
      final escapedReason = closeReason.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '\\r');
      final jsCode = '''(function() { var socket = globalThis["$jsHandler"]; if (socket && socket._handleClose) { socket._handleClose($closeCode, "$escapedReason", $wasClean); } delete globalThis["$jsHandler"]; })();''';
      ctx.eval(jsCode);

      // Clean up
      _cleanupSocket(socketId);
    } catch (e, s) {
      logger.e('[WebSocketService] Error handling close: $e\n$s');
    }
  }

  void _handleError(String socketId, String error) {
    if (_isDisposed) return;
    try {
      // Call JS handler
      final jsHandler = '_ws_$socketId';
      final jsCode = '''(function() { var socket = globalThis["$jsHandler"]; if (socket && socket._handleError) { socket._handleError(); } })();''';
      ctx.eval(jsCode);
    } catch (e, s) {
      logger.e('[WebSocketService] Error handling error event: $e\n$s');
    }
  }

  dynamic _handleSend(dynamic args) {
    try {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? socketId = options['socketId']?.toString();
      final String? data = options['data']?.toString();
      final bool isBinary = options['isBinary'] == true;

      if (socketId == null || socketId.isEmpty) {
        logger.w('[WebSocketService] Send failed: socketId is required');
        return false;
      }

      final socket = _sockets[socketId];
      if (socket == null) {
        logger.w('[WebSocketService] Send failed: socket not found: $socketId');
        return false;
      }

      if (data == null) {
        logger.w('[WebSocketService] Send failed: data is null');
        return false;
      }

      if (isBinary) {
        // Decode base64 to binary
        final bytes = base64Decode(data);
        socket.sink.add(bytes);
      } else {
        socket.sink.add(data);
      }

      return true;
    } catch (e, s) {
      logger.e('[WebSocketService] Error sending: $e\n$s');
      return false;
    }
  }

  dynamic _handleClose(dynamic args) {
    try {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? socketId = options['socketId']?.toString();
      final int? code =  asIntOrNull(options['code']);
      final String? reason = options['reason']?.toString();

      if (socketId == null || socketId.isEmpty) {
        return false;
      }

      return _closeSocket(socketId, code: code, reason: reason);
    } catch (e, s) {
      logger.e('[WebSocketService] Error closing: $e\n$s');
      return false;
    }
  }

  Future<bool> _closeSocket(String socketId, {int? code, String? reason}) async {
    final socket = _sockets[socketId];
    if (socket == null) {
      return false;
    }

    try {
      await socket.sink.close(code ?? 1000, reason ?? '');
    } catch (e) {
      logger.w('[WebSocketService] Error closing socket: $e');
    }

    _cleanupSocket(socketId);
    return true;
  }

  void _cleanupSocket(String socketId) {
    _subscriptions[socketId]?.cancel();
    _subscriptions.remove(socketId);
    _sockets.remove(socketId);
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 同步取消所有 stream 订阅，避免 dispose 后仍收到消息回调
    // sink.close() 是异步的，无法在 dispose 中 await，让底层自行关闭
    for (final socketId in _sockets.keys.toList()) {
      _subscriptions[socketId]?.cancel();
      try {
        _sockets[socketId]?.sink.close(1000, '');
      } catch (_) {}
    }
    _subscriptions.clear();
    _sockets.clear();
    super.dispose();
  }
}
