import 'dart:async';
import 'dart:isolate';

import 'bundle_verifier.dart';

/// 验签请求（主 isolate → 子 isolate）。
class _VerifyRequest {
  final int id;
  final String dir;
  _VerifyRequest(this.id, this.dir);
}

/// 验签响应（子 isolate → 主 isolate）。
class _VerifyResponse {
  final int id;
  final bool ok;
  final String? reason;
  _VerifyResponse(this.id, this.ok, this.reason);
  VerifyResult toResult() => ok
      ? VerifyResult.success(null) // manifest 不跨 isolate 传递（用不到）
      : VerifyResult.failure(reason); // reason 类型为 String?,可接收 null
}

/// Dispose 哨兵消息。
class _DisposeMessage {}

/// 初始化消息。
class _InitMessage {
  final Map<String, String> publicKeysB64;
  final SendPort handshakeReply;
  final SendPort responseReply;
  _InitMessage(this.publicKeysB64, this.handshakeReply, this.responseReply);
}

/// 后台 isolate 化验签服务。
///
/// 为什么需要 isolate：单 bundle 验签 ~100-300ms（manifest 读 + Ed25519 + 逐文件
/// SHA-256）。N 个 bundle 在主 isolate 跑会阻塞 UI 线程。挪到独立 isolate 后，
/// 主 isolate 可以并行做其他启动工作（引擎 init / UI 渲染 / 远端同步等）。
///
/// 安全语义：调用方 `await verify()` 必须先完成才加载 JS，**不会**在验签
/// 期间允许 bundle 代码执行 —— 这与"加载后异步检测"不同（后者有 race condition）。
class BundleVerifyIsolate {
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<VerifyResult>> _pending = {};
  SendPort? _commands;
  int _nextId = 0;
  bool _disposed = false;

  BundleVerifyIsolate._();

  /// 启动子 isolate 并完成握手。
  static Future<BundleVerifyIsolate> create(
      Map<String, String> publicKeysB64) async {
    final isolate = BundleVerifyIsolate._();
    await isolate._spawn(publicKeysB64);
    return isolate;
  }

  Future<void> _spawn(Map<String, String> publicKeysB64) async {
    _responses.listen((msg) {
      if (_disposed) return; // dispose 之后到达的响应直接丢弃
      if (msg is _VerifyResponse) {
        final c = _pending.remove(msg.id);
        if (c != null && !c.isCompleted) c.complete(msg.toResult());
      }
    });

    final handshake = ReceivePort();
    final ready = Completer<SendPort>();
    handshake.listen((msg) {
      if (msg is SendPort && !ready.isCompleted) ready.complete(msg);
    });

    await Isolate.spawn(
      _isolateMain,
      _InitMessage(publicKeysB64, handshake.sendPort, _responses.sendPort),
    );

    _commands = await ready.future;
    handshake.close();
  }

  /// 提交一个验签请求，返回 Future。
  /// Future 在子 isolate 完成 verifyDir 后 resolve。
  Future<VerifyResult> verify(String dir) {
    if (_disposed) {
      return Future.value(VerifyResult.failure('verify isolate disposed'));
    }
    final cmds = _commands;
    if (cmds == null) {
      return Future.value(VerifyResult.failure('verify isolate not started'));
    }
    final id = _nextId++;
    final c = Completer<VerifyResult>();
    _pending[id] = c;
    cmds.send(_VerifyRequest(id, dir));
    return c.future;
  }

  /// 释放 isolate。已 pending 的 Future 会被 reject。
  ///
  /// 实现注意：dispose 体内对 _pending 的 reject 用 microtask 延迟一拍执行，
  /// 避免与 response handler 同步竞争（response handler 也可能正要把
  /// Completer 标为完成；二者同时操作同一 Completer 会触发 "Bad state"）。
  /// 后果：dispose 立即返回，pending 的 reject 在下一拍执行。调用方的
  /// `await fut` 仍能正常看到 reject。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final cmds = _commands;
    if (cmds != null) cmds.send(_DisposeMessage());
    final pending = _pending.values.toList();
    _pending.clear();
    // 关闭响应端口：未来到达的 response 会被 _disposed 守卫丢掉。
    _responses.close();
    // microtask 中 reject —— 任何"已被 response 完成"的 Completer 都会
    // 被 isCompleted 守卫跳过，completeError 不再抛。
    scheduleMicrotask(() {
      for (final c in pending) {
        if (c.isCompleted) continue;
        c.completeError(StateError('verify isolate disposed'));
      }
    });
  }
}

void _isolateMain(_InitMessage init) async {
  // 1. 在子 isolate 内构造 verifier（不跨 isolate 传递 verifier 实例）。
  final verifier = BundleVerifier(publicKeysB64: init.publicKeysB64);

  // 2. 打开命令端口并回送 SendPort 完成握手。
  final commands = ReceivePort();
  init.handshakeReply.send(commands.sendPort);

  // 3. 4-way concurrent worker pool。worker 之间通过 idle completers + queue
  //    公平分摊请求。
  const concurrency = 4;
  final idle = <Completer<_VerifyRequest>>[];
  final queue = <_VerifyRequest>[];

  Future<void> worker() async {
    while (true) {
      final _VerifyRequest req;
      if (queue.isNotEmpty) {
        req = queue.removeAt(0);
      } else {
        final c = Completer<_VerifyRequest>();
        idle.add(c);
        req = await c.future;
      }
      final v = await verifier.verifyDir(req.dir);
      init.responseReply.send(_VerifyResponse(req.id, v.ok, v.reason));
    }
  }

  for (var i = 0; i < concurrency; i++) {
    // 每个 worker 一个未捕获的 Future 异常防护：出错就退出 isolate。
    // 调用方会因 Completer 永不完成而 hang —— 这种情况下主 isolate 应该能
    // 通过 dispose() / 新建 isolate 恢复。
    worker().catchError((_) {
      Isolate.exit();
    });
  }

  // 4. 命令分发。
  commands.listen((msg) {
    if (msg is _DisposeMessage) {
      commands.close();
      Isolate.exit();
    } else if (msg is _VerifyRequest) {
      if (idle.isNotEmpty) {
        idle.removeAt(0).complete(msg);
      } else {
        queue.add(msg);
      }
    }
  });
}
