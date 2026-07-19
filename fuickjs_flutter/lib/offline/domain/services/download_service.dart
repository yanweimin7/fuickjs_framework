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
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, double> _progress = {};
  bool Function(Package package)? _isInternalChecker;

  DownloadService(
    this._repository, {
    required OfflineConfig config,
    required BundleVerifier verifier,
    Dio? dio,
  })  : _config = config,
        _verifier = verifier,
        _dio = dio ?? Dio();

  void setInternalChecker(bool Function(Package package) checker) {
    _isInternalChecker = checker;
  }

  /// 下载/取出 → 整包 SHA-256 → 解压 staging → 验签 → minAppVersion → 原子提升。
  /// 成功返回处于 staged 状态的 Package；失败返回 null。
  Future<Package?> preparePackage(Package package) async {
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
    final expected = package.integrity;
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

    // 代码层验签。
    final verify = await _verifier.verifyDir(stagingDir);
    if (!verify.ok) {
      logger(() => 'verify failed $id: ${verify.reason}');
      await _safeDeleteDir(stagingDir);
      return null;
    }
    logger(() => 'verify ok: $id');

    // minAppVersion 兼容性（manifest 优先，回退 package）。
    final minAppVersion =
        verify.manifest?.minAppVersion ?? package.minAppVersion;
    if (!VersionUtils.isAppVersionSatisfied(_config.appVersion, minAppVersion)) {
      logger(() =>
          'minAppVersion not satisfied $id: need $minAppVersion, app ${_config.appVersion}');
      await _safeDeleteDir(stagingDir);
      return null;
    }

    // 原子提升 staging → packages。
    final pkgDir = _repository.getPackageDir(package);
    try {
      await _repository.promoteStaging(package);
      logger(() => 'Promoted staging → packages: $id → $pkgDir');
    } catch (e) {
      logger(() => 'promote failed $id: $e');
      await _safeDeleteDir(stagingDir);
      return null;
    }

    // 提升成功后立即删 zip 缓存（无论内置/远程）。
    // 下次需要时由 preparePackage 入口的 validatePackage 命中复用 staging；
    // 若 staging 缺失（registry 清空/包被回收）则重新从 assets 提取或从网络下载。
    await _safeDelete(File(_zipPath(package)));

    logger(() => 'Package ready (staged): $id');
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
    try {
      logger(() => 'Downloading ${package.url}');
      await _dio.download(
        package.url!,
        tmpPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          _progress[package.url!] = total > 0 ? received / total : 0;
        },
      );
      // 下载完成才 rename 到最终路径，避免半包被当成完整包。
      await File(tmpPath).rename(zipFile.path);
      logger(() => 'Download completed: ${package.url}');
      return zipFile;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        logger(() => 'Download cancelled: ${package.url}');
      } else {
        logger(() => 'Download failed: ${package.url}, ${e.message}');
      }
      await _safeDelete(File(tmpPath));
      return null;
    } catch (e) {
      logger(() => 'Download error: ${package.url}, $e');
      await _safeDelete(File(tmpPath));
      return null;
    } finally {
      _cancelTokens.remove(package.url!);
      _progress.remove(package.url!);
    }
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

  bool isDownloading(String url) => _cancelTokens.containsKey(url);
}
