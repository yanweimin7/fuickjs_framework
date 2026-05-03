import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../logger.dart';
import '../utils/extensions.dart';
import 'base_fuick_service.dart';

class WebSocketService extends BaseFuickService {
  @override
  String get name => 'WebSocket';

  bool _isDisposed = false;

  // ── Client mode state ─────────────────────────────────────────────────────
  final Map<String, WebSocketChannel> _sockets = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // ── Server mode state ─────────────────────────────────────────────────────
  int _clientCounter = 0;
  final Map<String, HttpServer> _servers = {};
  // serverId -> { clientId -> WebSocket }
  final Map<String, Map<String, WebSocket>> _serverClients = {};

  WebSocketService() {
    // Client mode
    registerAsyncMethod('connect', _handleConnect);
    registerMethod('send', _handleSend);
    registerMethod('close', _handleClose);
    // Server mode
    registerAsyncMethod('listen', _handleListen);
    registerMethod('sendToClient', _handleSendToClient);
    registerMethod('stopListen', _handleStopListen);
  }

  // ── Client mode ───────────────────────────────────────────────────────────

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
      final encodedData = jsonEncode(data);
      final jsCode = isBinary
          ? '''(function() { var socket = globalThis["$jsHandler"]; if (socket && socket._handleMessage) { socket._handleMessage(base64ToArrayBuffer($encodedData)); } })();'''
          : '''(function() { var socket = globalThis["$jsHandler"]; if (socket && socket._handleMessage) { socket._handleMessage($encodedData); } })();''';
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
      final encodedReason = jsonEncode(closeReason);
      final jsCode = '''(function() { var socket = globalThis["$jsHandler"]; if (socket && socket._handleClose) { socket._handleClose($closeCode, $encodedReason, $wasClean); } delete globalThis["$jsHandler"]; })();''';
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
      final int? code = asIntOrNull(options['code']);
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

  // ── Server mode ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _handleListen(dynamic args) async {
    try {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? serverId = options['serverId']?.toString();
      final int port = asInt(options['port'] ?? 0);

      if (serverId == null || serverId.isEmpty) {
        return {'success': false, 'error': 'serverId is required'};
      }

      // Stop any existing server with the same id
      await _stopServer(serverId);

      final httpServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _servers[serverId] = httpServer;
      _serverClients[serverId] = {};

      final actualPort = httpServer.port;
      final ip = await _findLocalIp();

      logger.i('[WebSocketService] Server $serverId listening on $ip:$actualPort');

      // Accept WebSocket upgrades
      httpServer.transform(WebSocketTransformer()).listen(
        (WebSocket ws) {
          final clientId = (++_clientCounter).toString();
          _serverClients[serverId]![clientId] = ws;

          logger.i('[WebSocketService] Server $serverId: client $clientId connected');
          _fireServerEvent(serverId, '_handleClientConnected', clientId, null);

          ws.listen(
            (message) {
              _handleServerClientMessage(serverId, clientId, message);
            },
            onDone: () {
              logger.i('[WebSocketService] Server $serverId: client $clientId disconnected');
              _serverClients[serverId]?.remove(clientId);
              _fireServerEvent(serverId, '_handleClientDisconnected', clientId, null);
            },
            onError: (e) {
              logger.e('[WebSocketService] Server $serverId client $clientId error: $e');
              _serverClients[serverId]?.remove(clientId);
              _fireServerEvent(serverId, '_handleClientDisconnected', clientId, null);
            },
          );
        },
        onError: (e) {
          logger.e('[WebSocketService] Server $serverId accept error: $e');
        },
      );

      return {'success': true, 'ip': ip, 'port': actualPort};
    } catch (e, s) {
      logger.e('[WebSocketService] listen error: $e\n$s');
      return {'success': false, 'error': e.toString()};
    }
  }

  void _handleServerClientMessage(String serverId, String clientId, dynamic message) {
    if (_isDisposed) return;
    try {
      String data;
      if (message is String) {
        data = message;
      } else if (message is List<int>) {
        data = base64Encode(message);
      } else if (message is Uint8List) {
        data = base64Encode(message);
      } else {
        data = message.toString();
      }
      _fireServerEvent(serverId, '_handleClientMessage', clientId, data);
    } catch (e, s) {
      logger.e('[WebSocketService] _handleServerClientMessage error: $e\n$s');
    }
  }

  void _fireServerEvent(String serverId, String method, String clientId, String? data) {
    if (_isDisposed) return;
    try {
      final jsGlobal = '_ws_server_$serverId';
      final encodedClientId = jsonEncode(clientId);
      String jsCode;
      if (data != null) {
        final encodedData = jsonEncode(data);
        jsCode = '(function(){ var s=globalThis["$jsGlobal"]; if(s&&s.$method) s.$method($encodedClientId,$encodedData); })();';
      } else {
        jsCode = '(function(){ var s=globalThis["$jsGlobal"]; if(s&&s.$method) s.$method($encodedClientId); })();';
      }
      ctx.eval(jsCode);
    } catch (e, s) {
      logger.e('[WebSocketService] _fireServerEvent error: $e\n$s');
    }
  }

  dynamic _handleSendToClient(dynamic args) {
    try {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? serverId = options['serverId']?.toString();
      final String? clientId = options['clientId']?.toString();
      final String? data = options['data']?.toString();

      if (serverId == null || clientId == null || data == null) {
        logger.w('[WebSocketService] sendToClient: missing serverId/clientId/data');
        return false;
      }

      final ws = _serverClients[serverId]?[clientId];
      if (ws == null) {
        logger.w('[WebSocketService] sendToClient: client not found $serverId/$clientId');
        return false;
      }

      ws.add(data);
      return true;
    } catch (e, s) {
      logger.e('[WebSocketService] sendToClient error: $e\n$s');
      return false;
    }
  }

  dynamic _handleStopListen(dynamic args) {
    try {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? serverId = options['serverId']?.toString();
      if (serverId == null || serverId.isEmpty) return false;
      _stopServer(serverId);
      return true;
    } catch (e, s) {
      logger.e('[WebSocketService] stopListen error: $e\n$s');
      return false;
    }
  }

  Future<void> _stopServer(String serverId) async {
    final clients = _serverClients.remove(serverId) ?? {};
    for (final ws in clients.values) {
      try {
        await ws.close();
      } catch (_) {}
    }
    try {
      await _servers[serverId]?.close(force: true);
    } catch (_) {}
    _servers.remove(serverId);
  }

  Future<String> _findLocalIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback && addr.address.startsWith('192.')) {
          return addr.address;
        }
      }
    }
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return '127.0.0.1';
  }

  // ── dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _isDisposed = true;
    // Client mode cleanup
    for (final socketId in _sockets.keys.toList()) {
      _subscriptions[socketId]?.cancel();
      try {
        _sockets[socketId]?.sink.close(1000, '');
      } catch (_) {}
    }
    _subscriptions.clear();
    _sockets.clear();

    // Server mode cleanup
    for (final serverId in _servers.keys.toList()) {
      final clients = _serverClients.remove(serverId) ?? {};
      for (final ws in clients.values) {
        try {
          ws.close();
        } catch (_) {}
      }
      try {
        _servers[serverId]?.close(force: true);
      } catch (_) {}
    }
    _servers.clear();
    _serverClients.clear();

    super.dispose();
  }
}
