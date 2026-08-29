import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../config/offline_config.dart';
import '../../util/logger.dart';
import '../../util/version_utils.dart';
import '../entities/package.dart';
import '../repositories/package_repository.dart';
import 'bundle_verifier.dart';

class DownloadService {
  final PackageRepository _repository;
  final OfflineConfig _config;
  final BundleVerifier _verifier;
  final bool _enableSignatureVerify;
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, double> _progress = {};
  // 进度节流：按 name 记录上一次回调的进度，增量 <1% 不回调，避免高频打 UI。
  final Map<String, double> _lastEmittedProgress = {};
  // 按 name 记录最近一次进度（含终态 1.0 / -1.0），供 pull 查询。
  final Map<String, double> _progressByName = {};
  bool Function(Package package)? _isInternalChecker;

  DownloadService(
    this._repository, {
    required OfflineConfig config,
    required BundleVerifier verifier,
    bool? enableSignatureVerify,
    Dio? dio,
  })  : _config = config,
        _verifier = verifier,
        _enableSignatureVerify = enableSignatureVerify ?? config.enableSignatureVerify,
        _dio = dio ?? Dio() {
    // enableSignatureVerify=true 却未配置公钥是配置错误：验签必因无 key 匹配
    // 而失败，并把正常包误判为"被篡改"删除。这里 fail-fast 早抛，避免静默损坏。
    if (_enableSignatureVerify && config.signaturePublicKeysB64.isEmpty) {
      throw ArgumentError(
        'enableSignatureVerify=true requires signaturePublicKeysB64 to be '
        'non-empty. Configure signaturePublicKeysB64, or set '
        'enableSignatureVerify=false.',
      );
    }
  }

  void setInternalChecker(bool Function(Package package) checker) {
    _isInternalChecker = checker;
  }

  /// 同包 in-flight 去重。key: versionShasumName。
  final Map<String, Future<Package?>> _prepareInflight = {};

  /// 下载/取出 → 整包 SHA-256 → 解压 staging → 验签 → minAppVersion → 原子提升。
  /// 成功返回处于 staged 状态的 Package；失败返回 null。
  ///
  /// 并发安全：首启时页面加载（_ensureBuiltinActive）与后台 sync（_syncAndClean）
  /// 会对同一内置包并发调用本方法。若不合并，两条流程会在同一 staging 目录上
  /// 交错 _resetDir/_unzip/promoteStaging，导致提升后的包目录仍是半写状态，
  /// 引擎 fopen 会读到截断的 bundle.js（SyntaxError，第二次加载才正常）。
  /// 同包并发调用共享同一个 in-flight Future，第二个调用直接 join 其结果。
  Future<Package?> preparePackage(Package package) {
    final id = package.versionShasumName;
    final existing = _prepareInflight[id];
    if (existing != null) {
      logger(() => 'preparePackage in-flight, joining: $id');
      return existing;
    }
    final future = _doPreparePackage(package);
    _prepareInflight[id] = future;
    future.then((_) {}, onError: (_) {}).whenComplete(() {
      _prepareInflight.remove(id);
    });
    return future;
  }

  Future<Package?> _doPreparePackage(Package package) async {
    final id = package.versionShasumName;
    // 已提升过（flag 存在）→ 直接复用。
    if (await _repository.validatePackage(package)) {
      logger(() => 'Package already prepared: $id');
      return package.copyWith(state: PackageState.staged);
    }

    final isInternal = _isInternalChecker?.call(package) ?? false;
    if (isInternal) {
      logger(() => 'Prepare internal package: $id');
    }
    final zipFile = await _getZipFile(package, isInternal);
    if (zipFile == null) return null;

    // 整包 SHA-256 校验（图片也被覆盖）。
    final expected = package.sha256;
    if (expected.isNotEmpty) {
      final actual = await _sha256OfFile(zipFile);
      if (actual.toLowerCase() != expected.toLowerCase()) {
        logger(() => 'zip sha256 mismatch $id: expected $expected got $actual');
        await _safeDelete(zipFile);
        return null;
      }
      logger(() => 'zip sha256 ok: $id');
    }

    // 解压到 staging。
    final stagingDir = _repository.getStagingDir(package);
    logger(() => 'Unzip to staging: $id → $stagingDir');
    await _resetDir(stagingDir);
    try {
      await _unzip(zipFile, stagingDir);
    } catch (e) {
      logger(() => 'unzip failed $id: $e');
      await _safeDeleteDir(stagingDir);
      return null;
    }

    // 代码层验签（Ed25519 + 逐代码文件 SHA-256）。
    // enableSignatureVerify=false 时跳过，仅保留整包 zip SHA-256（传输完整性）。
    final VerifyResult verify;
    if (_enableSignatureVerify) {
      verify = await _verifier.verifyDir(stagingDir);
      if (!verify.ok) {
        logger(() => 'verify failed $id: ${verify.reason}');
        await _safeDeleteDir(stagingDir);
        return null;
      }
      logger(() => 'verify ok: $id');
    } else {
      logger(() => 'signature verify disabled, skip code-layer verify: $id');
      verify = const VerifyResult.success(null);
    }

    // minAppVersion 兼容性（manifest 优先，回退 package）。
    final minAppVersion =
        verify.manifest?.minAppVersion ?? package.minAppVersion;
    if (!VersionUtils.isAppVersionSatisfied(
        _config.appVersion, minAppVersion)) {
      logger(() =>
          'minAppVersion not satisfied $id: need $minAppVersion, app ${_config.appVersion}');
      await _safeDeleteDir(stagingDir);
      return null;
    }

    // staging 就绪。提升（rename staging→packages + flag）由 PackageService.applyReady
    // 在 registry 锁内完成，确保"落地"与"入册"原子化——否则 promoteStaging 与
    // applyReady 之间存在"已落地未入册"窗口，cleanUnreferenced 会误删刚 promote 的目录。
    //
    // 验签通过后立即删 zip 缓存（staging 已是最终内容）。
    // 下次需要时由 preparePackage 入口的 validatePackage 命中复用（flag 存在）；
    // 若 flag 缺失（registry 清空/包被回收）则重新从 assets 提取或从网络下载。
    await _safeDelete(File(_zipPath(package)));

    logger(() => 'Package ready (staging): $id');
    return package.copyWith(
      state: PackageState.staged,
      minAppVersion: minAppVersion,
    );
  }

  Future<File?> _getZipFile(Package package, bool isInternal) async {
    return isInternal
        ? _extractInternalToZip(package)
        : _downloadRemoteZip(package);
  }

  Future<File?> _extractInternalToZip(Package package) async {
    final id = package.versionShasumName;
    try {
      final zipFile = File(_zipPath(package));
      if (await zipFile.exists()) {
        final size = await zipFile.length();
        logger(() => 'Internal zip cache hit: $id (${zipFile.path}, ${size}B)');
        return zipFile;
      }
      if (!await zipFile.parent.exists()) {
        await zipFile.parent.create(recursive: true);
      }

      final assetPath = _repository.builtinBundleZipAsset(package.name);
      logger(() => 'Extract builtin zip: $id from asset $assetPath');
      final bytes = await rootBundle.load(assetPath);
      final data = bytes.buffer.asUint8List();

      final tmp = File('${zipFile.path}.tmp');
      await tmp.writeAsBytes(data, flush: true);
      await tmp.rename(zipFile.path);
      logger(() =>
          'Builtin zip extracted: $id → ${zipFile.path} (${data.length}B)');
      return zipFile;
    } catch (e) {
      logger(() => 'Failed to extract builtin $id: $e');
      return null;
    }
  }

  Future<File?> _downloadRemoteZip(Package package) async {
    if (package.url == null || package.url!.isEmpty) return null;

    final zipFile = File(_zipPath(package));
    if (await zipFile.exists()) return zipFile;
    if (!await zipFile.parent.exists()) {
      await zipFile.parent.create(recursive: true);
    }

    final tmpPath = '${zipFile.path}.tmp';
    final cancelToken = CancelToken();
    _cancelTokens[package.url!] = cancelToken;
    _lastEmittedProgress.remove(package.name);
    try {
      logger(() => 'Downloading ${package.url}');
      await _dio.download(
        package.url!,
        tmpPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? received / total : 0.0;
          _progress[package.url!] = progress;
          _emitProgress(package.name, progress);
        },
      );
      // 下载完成才 rename 到最终路径，避免半包被当成完整包。
      await File(tmpPath).rename(zipFile.path);
      logger(() => 'Download completed: ${package.url}');
      _emitProgress(package.name, 1.0);
      return zipFile;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        logger(() => 'Download cancelled: ${package.url}');
      } else {
        logger(() => 'Download failed: ${package.url}, ${e.message}');
      }
      _emitProgress(package.name, -1.0);
      await _safeDelete(File(tmpPath));
      return null;
    } catch (e) {
      logger(() => 'Download error: ${package.url}, $e');
      _emitProgress(package.name, -1.0);
      await _safeDelete(File(tmpPath));
      return null;
    } finally {
      _cancelTokens.remove(package.url!);
      _progress.remove(package.url!);
      _lastEmittedProgress.remove(package.name);
    }
  }

  /// 进度透出（节流）：进度增量 <1% 时跳过；终止态（1.0 / -1.0）恒透出。
  void _emitProgress(String name, double progress) {
    _progressByName[name] = progress;
    final cb = _config.onDownloadProgress;
    if (cb == null) return;
    final last = _lastEmittedProgress[name];
    final isTerminal = progress >= 1.0 || progress < 0;
    if (!isTerminal &&
        last != null &&
        (progress - last).abs() < 0.01) {
      return;
    }
    _lastEmittedProgress[name] = progress;
    cb(name, progress);
  }

  String _zipPath(Package package) => p.join(
        _repository.getDownloadDir(),
        '${package.versionShasumName}.zip',
      );

  Future<void> _unzip(File zipFile, String outputPath) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.isEmpty) return;

    for (final file in archive.files) {
      // 跳过软链，防路径穿越。
      if (file.isSymbolicLink) continue;

      final filePath = p.join(outputPath, p.normalize(file.name));
      if (!p.isWithin(outputPath, filePath) &&
          p.normalize(filePath) != p.normalize(outputPath)) {
        continue;
      }

      if (!file.isFile) {
        await Directory(filePath).create(recursive: true);
        continue;
      }
      final outputFile = File(filePath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(file.content as List<int>);
      file.clear();
    }
  }

  Future<String> _sha256OfFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> _resetDir(String dir) async {
    final d = Directory(dir);
    if (await d.exists()) await d.delete(recursive: true);
    await d.create(recursive: true);
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _safeDeleteDir(String dir) async {
    try {
      final d = Directory(dir);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  void cancel(String url) {
    _cancelTokens[url]?.cancel('User cancelled');
  }

  double getProgress(String url) => _progress[url] ?? 0;

  /// 按 bundle name 查询最近一次下载进度（含终态 1.0 / -1.0）。
  /// 未下载过返回 0。仅供需要 pull 语义的接入方（如进度条首次进入时读取）。
  double getProgressByName(String name) => _progressByName[name] ?? 0;

  bool isDownloading(String url) => _cancelTokens.containsKey(url);
}
