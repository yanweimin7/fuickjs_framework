import '../../util/logger.dart';
import '../entities/package.dart';
import '../repositories/package_repository.dart';
import '../value_objects/package_registry.dart';

/// 包状态机服务：管理 active / staged / history。
class PackageService {
  final PackageRepository _repository;
  final int _retainVersions;

  PackageService(
    this._repository, {
    int retainVersions = 3,
  }) : _retainVersions = retainVersions;

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

    final loaded = await _repository.loadRegistry();
    // 校验 active/staged/history 文件是否完整，丢弃缺失项。
    final active = await _filterValid(loaded.active);
    final staged = await _filterValid(loaded.staged);
    final history = await _filterValid(loaded.history);
    _registry = loaded.copyWith(active: active, staged: staged, history: history);

    final changed = active.length != loaded.active.length ||
        staged.length != loaded.staged.length ||
        history.length != loaded.history.length;
    if (changed) await _persist();

    logger(() =>
        'Registry: active=${active.map((e) => e.versionShasumName)}, staged=${staged.map((e) => e.versionShasumName)}');
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

    var staged = List<Package>.from(_registry.staged);
    for (final pkg in readyPackages) {
      final old = staged.where((p) => p.name == pkg.name).firstOrNull;
      if (old != null && !old.isSameVersion(pkg)) {
        await _repository.deletePackage(old); // 从未 active → 直接删
      }
      staged.removeWhere((p) => p.name == pkg.name);
      staged.add(pkg.copyWith(state: PackageState.staged));
    }
    _registry = _registry.copyWith(staged: staged);
    await _persist();
    for (final p in readyPackages) {
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

    // history 中的同版本记录提升为 staged 后会冗余，先移除（in-memory，由后续 applyReady 落盘）。
    final history = List<Package>.from(_registry.history)
      ..removeWhere((p) => p.name == remote.name && p.isSameVersion(remote));
    if (history.length != _registry.history.length) {
      _registry = _registry.copyWith(history: history);
    }

    final merged = hit.copyWith(
      url: remote.url ?? hit.url,
      minAppVersion: remote.minAppVersion ?? hit.minAppVersion,
      mustBeUpdated: remote.mustBeUpdated,
      timestamp: remote.timestamp ?? hit.timestamp,
      state: PackageState.staged,
    );
    logger(() => 'Reuse local (skip download): ${merged.versionShasumName}');
    return merged;
  }

  /// 远程已移除的包：删 active/staged 文件并移出 registry。
  Future<void> deactivatePackages(List<Package> packages) async {
    if (packages.isEmpty) return;
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
        .where((p) => !(p.name == name &&
            toRemove.any((r) => r.isSameVersion(p))))
        .toList();
  }

  Future<List<Package>> _filterValid(List<Package> packages) async {
    final result = <Package>[];
    for (final pkg in packages) {
      if (await _repository.validatePackage(pkg)) {
        result.add(pkg);
      } else {
        logger(() => 'Dropping invalid package: ${pkg.versionShasumName}');
      }
    }
    return result;
  }

  Future<void> _persist() async {
    await _repository.saveRegistry(_registry);
  }
}
