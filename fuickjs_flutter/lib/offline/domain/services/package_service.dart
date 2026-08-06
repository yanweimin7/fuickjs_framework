import 'dart:async';

import 'package:synchronized/synchronized.dart';

import '../../util/logger.dart';
import '../entities/package.dart';
import '../repositories/package_repository.dart';
import '../services/bundle_verify_isolate.dart';
import '../value_objects/package_registry.dart';

/// 包状态机服务：管理 active / staged / history。
class PackageService {
  final PackageRepository _repository;
  final int _retainVersions;
  final BundleVerifyIsolate? _verifyIsolate;

  /// 后台验签 Future（fire-and-forget）。测试可 await 它等待验证完成。
  /// 生产代码通常忽略。
  Future<void>? _bgVerifyFuture;

  /// _registry 修改互斥锁。
  ///
  /// 为什么要锁：_runBackgroundVerify 在开始时快照 _registry，在结束时
  /// 用 `_registry = snapshot.copyWith(...)` 写回。如果不锁，期间发生的
  /// applyReady / promoteStaged / verifyOnOpen 都会被快照覆盖。
  /// 读操作（getter）不参与，因为 Dart 单线程下读到的要么是旧要么是新的，
  /// 不会读到中间态。
  ///
  /// 用 synchronized 库的 Lock 替代手写链式 Completer：避免 finally 漏写
  /// 导致整条锁链死锁、支持超时、语义更清晰。
  final Lock _registryLock = Lock();

  PackageService(
    this._repository, {
    int retainVersions = 3,
    BundleVerifyIsolate? verifyIsolate,
  })  : _retainVersions = retainVersions,
        _verifyIsolate = verifyIsolate;

  /// 暴露给测试 await 后台验签完成。生产环境无需关心。
  Future<void>? get backgroundVerifyDone => _bgVerifyFuture;

  /// 在锁内执行 action,确保所有 _registry 修改 + 持久化串行化。
  /// 任何已修改 _registry 的方法都应通过此 helper 包装。
  Future<T> _withRegistryLock<T>(Future<T> Function() action) =>
      _registryLock.synchronized(action);

  PackageRegistry _registry = const PackageRegistry();
  List<Package> _remotePackages = [];
  List<Package> _internalPackages = [];
  bool _initialized = false;

  PackageRegistry get registry => _registry;
  List<Package> get activePackages => List.from(_registry.active);
  List<Package> get stagedPackages => List.from(_registry.staged);
  List<Package> get remotePackages => List.from(_remotePackages);
  List<Package> get internalPackages => List.from(_internalPackages);

  bool isInternal(Package package) =>
      _internalPackages.any((p) => p.isSameVersion(package));

  Package? getActivePackage(String name) => _registry.activeOf(name);
  Package? getStagedPackage(String name) => _registry.stagedOf(name);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 锁内做初始 registry 加载 + flag-level 过滤 + 持久化。
    // 防止与并发请求（如 Offline.refresh）的 _registry 修改产生竞态。
    await _withRegistryLock(() async {
      final loaded = await _repository.loadRegistry();

      // P0-3 第一道：flag-level 校验，过滤缺失文件的包（轻量，毫秒级）。
      final active = await _filterValid(loaded.active);
      final staged = await _filterValid(loaded.staged);
      final history = await _filterValid(loaded.history);

      // 先以校验后的状态快速进入 init 完成态 —— 调用方能立即开始工作。
      _registry =
          loaded.copyWith(active: active, staged: staged, history: history);
      final initialChanged = active.length != loaded.active.length ||
          staged.length != loaded.staged.length ||
          history.length != loaded.history.length;
      if (initialChanged) await _persist();

      logger(() =>
          'Registry: active=${active.map((e) => e.versionShasumName)}, staged=${staged.map((e) => e.versionShasumName)}');
    });

    // P0-3 第二道：内容级验签（Ed25519 + SHA-256）。
    // 改成 fire-and-forget 后台跑：init 不再阻塞，验签在 isolate 里并行进行。
    //
    // 安全保证不变：即使后台验签还在跑，on-open 验签（verifyOnOpen）也会在
    // 用户真正打开 bundle 时做最终闸。两条路径的"删除"是幂等的，可重复触发。
    _startBackgroundVerify();
  }

  /// 启动后台验签任务（fire-and-forget）。
  void _startBackgroundVerify() {
    final isolate = _verifyIsolate;
    if (isolate == null) return;

    // 锁内跑：确保后台验签的 snapshot 写回不会覆盖期间发生的 sync/promote 修改。
    // catchError 兜底：fire-and-forget Future 若抛异常会变成 unhandled async
    // error，这里记日志吃掉，避免污染 zone 错误处理。锁本身在 finally 中释放，
    // 不会因为异常而卡死后续 _withRegistryLock 调用。
    _bgVerifyFuture = _withRegistryLock(() => _doBackgroundVerify(isolate))
        .catchError((Object e, StackTrace st) {
      logger(() => '[P0-3] background verify crashed: $e');
    });
  }

  Future<void> _doBackgroundVerify(BundleVerifyIsolate isolate) async {
    // 锁内：_registry 不会被并发修改。
    final initial = _registry;
    final reActive = await _reverifyOrDrop(initial.active.toList(), isolate);
    final reStaged = await _reverifyOrDrop(initial.staged.toList(), isolate);

    _registry = _registry.copyWith(active: reActive, staged: reStaged);

    if (reActive.length != initial.active.length ||
        reStaged.length != initial.staged.length) {
      logger(() =>
          '[P0-3 bg] Registry cleaned: active ${initial.active.length} → ${reActive.length}, '
          'staged ${initial.staged.length} → ${reStaged.length}');
      await _persist();
    }
  }

  /// P0-3：对 [pkgs] 中的每个包做 Ed25519 + SHA-256 重新验签。
  /// 验签失败 → 删包 + 移出结果列表。
  /// 验签成功 → 保留。
  ///
  /// 隔离：验签请求通过 [isolate] 提交到子 isolate 的 4-way worker pool。
  /// 主 isolate 不阻塞，可以并行做其他启动工作（远端同步、UI 渲染、引擎 init）。
  Future<List<Package>> _reverifyOrDrop(
    List<Package> pkgs,
    BundleVerifyIsolate isolate,
  ) async {
    if (pkgs.isEmpty) return const [];

    // 关键：把 isolate 的 verify 结果**作为 Future 的返回值**带回主 isolate，
    // 而不是直接共享 `kept`/`failures` 列表。
    //
    // 之前的实现（pkgs.map + Future.wait + 直接 add 到共享 list）在 isolate
    // 响应极快的场景下会触发 Dart 的 "Concurrent modification during iteration"：
    // Future.wait 等待期间，async 协程的 continuation 仍在向同一个 list 写入，
    // 而 for-in 迭代器的 ListIterator 检测到 modCount 变化就抛错。
    //
    // 正确做法：每个 worker 返回自己的结果；await Future.wait 收齐后才合并
    // 到 kept/failures。合并完成后才进入 for-loop 删包，此时 list 不再被
    // 任何并发路径修改。
    final results = await Future.wait(
      pkgs.map((pkg) async {
        // 单包容错：getPackageDir 可能因 pkg 缺 sha256 抛 StateError，
        // isolate.verify 也可能因 isolate 死掉抛 StateError。
        // 不能让单个包的异常拖垮整轮 bg verify —— 失败视为 ok:false 走删包路径。
        try {
          final v = await isolate.verify(_repository.getPackageDir(pkg));
          return _VerifyOutcome(pkg: pkg, ok: v.ok);
        } catch (e) {
          // 注意：日志不能用 versionShasumName,因为 pkg 可能正是因为缺 sha256
          // 才在 getPackageDir 内抛 StateError,这里再访问会二次抛。
          logger(
              () => '[P0-3] verify error for ${pkg.name}@${pkg.version}: $e');
          return _VerifyOutcome(pkg: pkg, ok: false);
        }
      }),
    );

    final kept = <Package>[];
    final failures = <Package>[];
    for (final r in results) {
      if (r.ok) {
        kept.add(r.pkg);
      } else {
        failures.add(r.pkg);
      }
    }

    // 失败的统一删 + log。迭代 failures 时不会有其他路径再写它。
    // 单包删失败不能影响其他包的处理 —— 比如 pkg 缺 sha256 时
    // versionShasumName/deletePackage 都会抛,必须 try/catch 隔离。
    for (final pkg in failures) {
      try {
        logger(() =>
            '[P0-3] Drop tampered active/staged package: ${pkg.versionShasumName} '
            '(${'verify failed'})');
        await _repository.deletePackage(pkg);
      } catch (e) {
        logger(() =>
            '[P0-3] deletePackage error for ${pkg.name}@${pkg.version}: $e');
      }
    }
    return kept;
  }

  /// P0-3 on-open 验签：打开 bundle 前最后一道闸。
  /// 验签通过 → 返回 [Package]（调用方继续加载 JS）。
  /// 验签失败 → 返回 null（调用方应退出 bundle / 回退）。
  ///
  /// 隔离：验签在子 isolate 跑，但调用方必须 await。
  /// 关键：JS 在 await 返回前**不会**开始执行（避免 race condition）。
  /// isolate 的"异步"只意味着主 isolate 的事件循环不被验签 I/O 阻塞。
  ///
  /// 走 registry 锁：失败时调 deletePackage，且为了在锁内把"刚验签失败的包"
  /// 也从 in-memory 列表里清掉，避免下一次 getActive 仍返回已删的包。
  Future<Package?> verifyOnOpen(Package pkg, String dir) async {
    return _withRegistryLock(() => _doVerifyOnOpen(pkg, dir));
  }

  Future<Package?> _doVerifyOnOpen(Package pkg, String dir) async {
    final isolate = _verifyIsolate;
    if (isolate == null) return pkg; // 未配置验签 → 信任上层
    final v = await isolate.verify(dir);
    if (v.ok) return pkg;
    logger(() =>
        '[P0-3 on-open] Reject tampered package: ${pkg.versionShasumName} '
        '(${v.reason})');
    await _repository.deletePackage(pkg);
    // 同步清掉 in-memory 引用,否则下一次 getActive 仍会返回已删的包。
    // history 同 version+sha256 引用也一并清:目录已删,留着是脏数据。
    final active = List<Package>.from(_registry.active)
      ..removeWhere((p) => p.isSameVersion(pkg));
    final staged = List<Package>.from(_registry.staged)
      ..removeWhere((p) => p.isSameVersion(pkg));
    final history = List<Package>.from(_registry.history)
      ..removeWhere((p) => p.isSameVersion(pkg));
    if (active.length != _registry.active.length ||
        staged.length != _registry.staged.length ||
        history.length != _registry.history.length) {
      _registry = _registry.copyWith(
        active: active,
        staged: staged,
        history: history,
      );
      await _persist();
    }
    return null;
  }

  void setRemotePackages(List<Package> packages) {
    _remotePackages = List.from(packages);
  }

  void setInternalPackages(List<Package> packages) {
    _internalPackages = List.from(packages);
  }

  /// 将就绪（已下载校验）的包置入 staged 单槽位（替换语义）。
  /// 旧 staged 若从未 active 过，删其文件。
  Future<void> applyReady(List<Package> readyPackages) async {
    if (readyPackages.isEmpty) return;
    await _withRegistryLock(() => _doApplyReady(readyPackages));
  }

  Future<void> _doApplyReady(List<Package> readyPackages) async {
    var staged = List<Package>.from(_registry.staged);
    var history = List<Package>.from(_registry.history);
    var historyChanged = false;
    final promoted = <Package>[];
    for (final pkg in readyPackages) {
      // 提升到 packages 目录（rename staging→packages + flag）。
      // 必须在 registry 锁内：与下面的 registry 写入原子化，消除"已落地未入册"
      // 窗口——否则 cleanUnreferenced 会扫到 packages/ 下不在 registry.retained
      // 的新目录并误删（见 docs/bundle-delivery.md 竞态1）。
      //
      // 仅当包尚未提升（flag 不存在）时才 promote：
      // - preparePackage 返回的包：staging 就绪、packages/ 无 flag → promote
      // - reuseLocalAsStaged 复用的包：已在 packages/ 有 flag → 跳过
      if (!await _repository.validatePackage(pkg)) {
        try {
          await _repository.promoteStaging(pkg);
        } catch (e) {
          logger(
              () => 'promoteStaging failed for ${pkg.versionShasumName}: $e');
          continue; // 提升失败 → 不入 registry，下次 preparePackage 重试
        }
      }
      final old = staged.where((p) => p.name == pkg.name).firstOrNull;
      if (old != null && !old.isSameVersion(pkg)) {
        await _repository.deletePackage(old); // 从未 active → 直接删
        // old 目录被删,若 history 中存在同 version+sha256 引用(理论上不应该,
        // 但 registry 损坏时可能出现;正常流程 reuseLocalAsStaged 已先移除),
        // 一并清掉避免脏数据。
        final before = history.length;
        history.removeWhere((p) => p.isSameVersion(old));
        if (history.length != before) historyChanged = true;
      }
      staged.removeWhere((p) => p.name == pkg.name);
      staged.add(pkg.copyWith(state: PackageState.staged));
      promoted.add(pkg);
    }
    _registry = _registry.copyWith(
      staged: staged,
      history: historyChanged ? history : _registry.history,
    );
    await _persist();
    for (final p in promoted) {
      logger(() => 'Staged: ${p.versionShasumName}');
    }
  }

  /// 下次打开提升：staged → active，旧 active → history，裁剪 history。
  /// 返回提升后的 active（无 staged 时返回当前 active）。
  ///
  /// 安全校验：远程 staged 必须等于当前已知线上最新版本，否则丢弃——
  /// 防止误发包被撤回后仍残留生效。内置包恒豁免；远程列表未就绪
  /// （离线/首启未同步）时不阻断，保持可用。
  Future<Package?> promoteStaged(String name) async {
    return _withRegistryLock(() => _doPromoteStaged(name));
  }

  Future<Package?> _doPromoteStaged(String name) async {
    var staged = _registry.stagedOf(name);
    if (staged != null && !_isStagedPromotable(staged)) {
      await _discardStaged(staged);
      staged = null;
    }
    if (staged == null) return _registry.activeOf(name);

    final oldActive = _registry.activeOf(name);
    final newActive = staged.copyWith(state: PackageState.active);

    var history = List<Package>.from(_registry.history);
    if (oldActive != null && !oldActive.isSameVersion(newActive)) {
      history.insert(0, oldActive.copyWith(state: PackageState.history));
    }
    history = await _trimHistory(name, history);

    final active = List<Package>.from(_registry.active)
      ..removeWhere((p) => p.name == name)
      ..add(newActive);
    final stagedList = List<Package>.from(_registry.staged)
      ..removeWhere((p) => p.name == name);

    _registry = _registry.copyWith(
      active: active,
      staged: stagedList,
      history: history,
    );
    await _persist();
    logger(() => 'Promoted active: ${newActive.versionShasumName}');
    return newActive;
  }

  /// staged 是否允许生效：内置包恒允许；远程包需等于当前已知线上最新版本。
  /// 远程列表未就绪（_remotePackages 为空 / 不含该 name）时不阻断，保持可用。
  bool _isStagedPromotable(Package staged) {
    if (isInternal(staged)) return true;
    final remote =
        _remotePackages.where((p) => p.name == staged.name).firstOrNull;
    if (remote == null) return true;
    return staged.isSameVersion(remote);
  }

  /// 丢弃过时/误发的 staged：删文件 + 移出 registry。
  Future<void> _discardStaged(Package staged) async {
    await _repository.deletePackage(staged);
    _registry = _registry.copyWith(
      staged: _registry.staged.where((p) => p.name != staged.name).toList(),
    );
    await _persist();
    logger(() =>
        'Discard stale staged (mismatch remote latest): ${staged.versionShasumName}');
  }

  /// 远程目标版本已在本地 retained（history/staged/active）且文件完整 →
  /// 返回可直接 staged 的候选包（由调用方统一 [applyReady] 落盘），跳过下载。
  Future<Package?> reuseLocalAsStaged(Package remote) async {
    return _withRegistryLock(() => _doReuseLocalAsStaged(remote));
  }

  Future<Package?> _doReuseLocalAsStaged(Package remote) async {
    Package? hit;
    for (final pkg in _registry.retained) {
      if (pkg.name == remote.name && pkg.isSameVersion(remote)) {
        if (await _repository.validatePackage(pkg)) {
          hit = pkg;
          break;
        }
      }
    }
    if (hit == null) return null;

    // history 中的同版本记录提升为 staged 后会冗余，先移除（in-memory,由后续 applyReady 落盘）。
    final history = List<Package>.from(_registry.history)
      ..removeWhere((p) => p.name == remote.name && p.isSameVersion(remote));
    if (history.length != _registry.history.length) {
      _registry = _registry.copyWith(history: history);
    }

    final merged = hit.copyWith(
      url: remote.url ?? hit.url,
      minAppVersion: remote.minAppVersion ?? hit.minAppVersion,
      // mustBeUpdated 是"曾标记过强制就保留强制"的语义：
      // history 中的包可能原本是紧急更新（hit.mustBeUpdated=true），
      // 若 remote 的 latest.json 没显式带这个字段（默认 false），不能把它覆盖掉。
      mustBeUpdated: remote.mustBeUpdated || hit.mustBeUpdated,
      timestamp: remote.timestamp ?? hit.timestamp,
      state: PackageState.staged,
    );
    logger(() => 'Reuse local (skip download): ${merged.versionShasumName}');
    return merged;
  }

  /// 远程已移除的包：删 active/staged 文件并移出 registry。
  Future<void> deactivatePackages(List<Package> packages) async {
    if (packages.isEmpty) return;
    await _withRegistryLock(() => _doDeactivatePackages(packages));
  }

  Future<void> _doDeactivatePackages(List<Package> packages) async {
    for (final pkg in packages) {
      final a = _registry.activeOf(pkg.name);
      final s = _registry.stagedOf(pkg.name);
      if (a != null) await _repository.deletePackage(a);
      if (s != null) await _repository.deletePackage(s);
    }
    final names = packages.map((e) => e.name).toSet();
    _registry = _registry.copyWith(
      active: _registry.active.where((p) => !names.contains(p.name)).toList(),
      staged: _registry.staged.where((p) => !names.contains(p.name)).toList(),
    );
    await _persist();
  }

  Future<List<Package>> _trimHistory(String name, List<Package> history) async {
    final ofName = history.where((p) => p.name == name).toList();
    if (ofName.length <= _retainVersions) return history;
    final toRemove = ofName.sublist(_retainVersions);
    for (final p in toRemove) {
      await _repository.deletePackage(p);
    }
    return history
        .where(
            (p) => !(p.name == name && toRemove.any((r) => r.isSameVersion(p))))
        .toList();
  }

  Future<List<Package>> _filterValid(List<Package> packages) async {
    final result = <Package>[];
    for (final pkg in packages) {
      // 单包容错:pkg 可能缺 sha256(reigstry 被篡改),validatePackage 内部
      // 调 versionShasumName → integrity 会抛 StateError。不能让一个坏包
      // 拖垮整个 init 的 registry 加载 —— 失败视为无效,直接 drop。
      try {
        if (await _repository.validatePackage(pkg)) {
          result.add(pkg);
        } else {
          logger(() => 'Dropping invalid package: ${pkg.versionShasumName}');
        }
      } catch (e) {
        logger(
            () => 'Dropping invalid package: ${pkg.name}@${pkg.version}: $e');
      }
    }
    return result;
  }

  Future<void> _persist() async {
    await _repository.saveRegistry(_registry);
  }
}

/// 单包验签结果（worker 在 isolate 中跑完后作为 Future 返回值带回主 isolate）。
/// 避免在 await Future.wait 期间对共享 list 进行并发写入。
class _VerifyOutcome {
  final Package pkg;
  final bool ok;
  const _VerifyOutcome({required this.pkg, required this.ok});
}
