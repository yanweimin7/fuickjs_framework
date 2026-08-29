import 'base_fuick_service.dart';

/// Web 端 WebSocket 服务：Phase 1 不实现。
///
/// 客户端模式后续可改用 `package:web` 的 WebSocket；服务端模式
/// （dart:io HttpServer + WebSocketTransformer）在浏览器无对应物，天然不支持。
/// 所有 WebSocket.* 方法不可用。
class WebSocketService extends BaseFuickService {
  @override
  String get name => 'WebSocket';

  WebSocketService();
}
