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

/// 单次 verify 的待完成项：包装 Completer + 超时 Timer，
/// 保证响应/超时只触发一次、且超时能取消 Timer 避免泄漏。
class _Pending {
  final Completer<VerifyResult> completer = Completer<VerifyResult>();
  Timer? timer;

  void complete(VerifyResult r) {
    timer?.cancel();
    timer = null;
    if (!completer.isCompleted) completer.complete(r);
  }

  void failWithError(Object e) {
    timer?.cancel();
    timer = null;
    if (!completer.isCompleted) completer.completeError(e);
  }
}

/// 后台 isolate 化验签服务。
///
/// 为什么需要 isolate：单 bundle 验签 ~100-300ms（manifest 读 + Ed25519 + 逐文件
/// SHA-256）。N 个 bundle 在主 isolate 跑会阻塞 UI 线程。挪到独立 isolate 后，
/// 主 isolate 可以并行做其他启动工作（引擎 init / UI 渲染 / 远端同步等）。
///
/// 安全语义：调用方 `await verify()` 必须先完成才加载 JS，**不会**在验签
/// 期间允许 bundle 代码执行 —— 这与"加载后异步检测"不同（后者有 race condition）。
///
/// 健壮性（修复点）：原先 worker 一旦抛未捕获异常就 `Isolate.exit()` 杀掉整个
/// isolate，导致所有 in-flight `verify()` 的 Completer 永不完成、调用方永久 hang
/// （软 brick），且无任何超时。现改为纵深防御：
///  1) worker 自愈：单包验签异常只判该包失败，不杀 isolate；
///  2) 每条请求自带超时，无响应即以 failure 完成；
///  3) 主侧监听 isolate 退出（崩溃/OOM），崩溃时把所有 pending 以 failure 完成。
class BundleVerifyIsolate {
  static const Duration _defaultTimeout = Duration(seconds: 15);

  final ReceivePort _responses = ReceivePort();
  final Map<int, _Pending> _pending = {};
  SendPort? _commands;
  Isolate? _isolate;
  ReceivePort? _exitPort;
  int _nextId = 0;
  bool _disposed = false;
  bool _crashed = false;

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
        _pending.remove(msg.id)?.complete(msg.toResult());
      }
    });

    final handshake = ReceivePort();
    final ready = Completer<SendPort>();
    handshake.listen((msg) {
      if (msg is SendPort && !ready.isCompleted) ready.complete(msg);
    });

    _isolate = await Isolate.spawn(
      _isolateMain,
      _InitMessage(publicKeysB64, handshake.sendPort, _responses.sendPort),
    );

    // 崩溃看门狗：isolate 意外退出（OOM / 不可捕获崩溃）时，
    // 把仍 pending 的 verify 以 failure 完成，避免调用方永久 hang。
    _exitPort = ReceivePort();
    _isolate!.addOnExitListener(_exitPort!.sendPort);
    _exitPort!.listen((_) => _onIsolateExited());

    _commands = await ready.future;
    handshake.close();
  }

  /// isolate 退出回调：仅处理"非 dispose 触发的意外退出"。
  /// dispose 已同步置 `_disposed=true` 并在 microtask 中处理 pending，故直接忽略。
  void _onIsolateExited() {
    if (_disposed || _crashed) return;
    _crashed = true;
    _commands = null;
    _responses.close();
    _exitPort?.close();
    final entries = _pending.values.toList();
    _pending.clear();
    for (final p in entries) {
      p.complete(VerifyResult.failure('verify isolate crashed unexpectedly'));
    }
  }

  /// 提交一个验签请求，返回 Future。
  /// Future 在子 isolate 完成 verifyDir 后 resolve；超时或 isolate 崩溃时以
  /// [VerifyResult.failure] 完成（调用方据此拒绝该 bundle 并回退内置，不 hang）。
  Future<VerifyResult> verify(String dir, {Duration? timeout}) {
    if (_disposed) {
      return Future.value(VerifyResult.failure('verify isolate disposed'));
    }
    if (_crashed) {
      // 崩溃后不再发往死 isolate，立即以 failure 完成（回退内置）。
      return Future.value(VerifyResult.failure('verify isolate crashed'));
    }
    final cmds = _commands;
    if (cmds == null) {
      return Future.value(VerifyResult.failure('verify isolate not started'));
    }
    final id = _nextId++;
    final p = _Pending();
    _pending[id] = p;
    cmds.send(_VerifyRequest(id, dir));
    final effective = timeout ?? _defaultTimeout;
    p.timer = Timer(effective, () {
      _pending.remove(id)?.complete(
        VerifyResult.failure(
          'verify timeout after ${effective.inMilliseconds}ms ($dir)',
        ),
      );
    });
    return p.completer.future;
  }

  /// 释放 isolate。
  ///
  /// 注意：dispose 走**抛错**语义（`completeError(StateError)`），而非 failure ——
  /// 调用方把 dispose 期间的中断视为"验签设施不可用、跳过"，不应误判为"包被篡改"
  /// 而删除一个本就正常的包（见 _doVerifyOnOpen 的删除逻辑）。
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
    _exitPort?.close();
    // microtask 中 reject —— 任何"已被 response 完成"的 Completer 都会
    // 被 isCompleted 守卫跳过，completeError 不再抛。
    scheduleMicrotask(() {
      for (final p in pending) {
        if (p.completer.isCompleted) continue;
        p.failWithError(StateError('verify isolate disposed'));
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
      try {
        final _VerifyRequest req;
        if (queue.isNotEmpty) {
          req = queue.removeAt(0);
        } else {
          final c = Completer<_VerifyRequest>();
          idle.add(c);
          req = await c.future;
        }
        VerifyResult v;
        try {
          // 单包验签异常（坏包 / 缺文件 / 格式错误）只判该包失败，
          // 绝不抛出杀死整个 isolate —— 其他请求继续正常验签。
          v = await verifier.verifyDir(req.dir);
        } catch (e) {
          v = VerifyResult.failure('verifyDir threw: $e');
        }
        init.responseReply.send(_VerifyResponse(req.id, v.ok, v.reason));
      } catch (e) {
        // 任何意外错误（如 send 失败）兜底：打印并继续循环，
        // 不杀 isolate。该 req 已丢失，主 isolate 侧有超时兜底。
        // ignore: avoid_print
        print('[BundleVerifyIsolate] worker unexpected error (continuing): $e');
      }
    }
  }

  for (var i = 0; i < concurrency; i++) {
    // 不再使用 `catchError((_) => Isolate.exit())`：旧逻辑任一 worker 抛异常
    // 就杀掉整个 isolate，导致所有 in-flight verify 永久 hang（软 brick）。
    // worker 内部已自愈，这里仅 fire-and-forget 启动即可。
    worker();
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
