import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../entities/package.dart';
import '../repositories/package_repository.dart';
import '../../util/logger.dart';

class DownloadService {
  final PackageRepository _repository;
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, double> _progress = {};
  bool Function(Package package)? _isInternalChecker;

  DownloadService(this._repository, {Dio? dio}) : _dio = dio ?? Dio();

  void setInternalChecker(bool Function(Package package) checker) {
    _isInternalChecker = checker;
  }

  Future<Package?> preparePackage(Package package) async {
    final isInternal = _isInternalChecker?.call(package) ?? false;
    final zipFile = await _getZipFile(package, isInternal);
    if (zipFile == null) return null;
    return await _verifyAndExtract(zipFile, package);
  }

  Future<File?> _getZipFile(Package package, bool isInternal) async {
    if (isInternal) {
      return await _extractInternalToZip(package);
    } else {
      return await _downloadRemoteZip(package);
    }
  }

  Future<File?> _extractInternalToZip(Package package) async {
    try {
      final downloadDir = _repository.getDownloadDir();
      final zipFileName = '${package.name}-${package.versionShasumName}.zip';
      final zipFilePath = path.join(downloadDir, zipFileName);
      final zipFile = File(zipFilePath);

      if (await zipFile.exists()) {
        return zipFile;
      }

      if (!(await zipFile.parent.exists())) {
        await zipFile.parent.create(recursive: true);
      }

      final zipAssetPath = 'assets/h5/${package.name}.zip';
      final bytes = await rootBundle.load(zipAssetPath);
      final data = bytes.buffer.asUint8List();

      await zipFile.writeAsBytes(data);
      logger(() => 'Internal package saved: ${package.name}');
      return zipFile;
    } catch (e) {
      logger(() => 'Failed to extract internal ${package.name}: $e');
      return null;
    }
  }

  Future<File?> _downloadRemoteZip(Package package) async {
    if (package.url == null || package.url!.isEmpty) {
      return null;
    }

    final downloadDir = _repository.getDownloadDir();
    final zipFileName = '${package.name}-${package.versionShasumName}.zip';
    final zipFilePath = path.join(downloadDir, zipFileName);

    final zipFile = File(zipFilePath);
    if (await zipFile.exists()) {
      return zipFile;
    }

    if (!(await zipFile.parent.exists())) {
      await zipFile.parent.create(recursive: true);
    }

    final cancelToken = CancelToken();
    _cancelTokens[package.url!] = cancelToken;

    try {
      logger(() => 'Downloading ${package.url}');

      await _dio.download(
        package.url!,
        zipFilePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          _progress[package.url!] = total > 0 ? received / total : 0;
        },
      );

      logger(() => 'Download completed: ${package.url}');
      return zipFile;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        logger(() => 'Download cancelled: ${package.url}');
      } else {
        logger(() => 'Download failed: ${package.url}, ${e.message}');
      }
      return null;
    } finally {
      _cancelTokens.remove(package.url!);
      _progress.remove(package.url!);
    }
  }

  Future<Package?> _verifyAndExtract(File zipFile, Package package) async {
    final flagFile = File(_repository.getPackageFlagFile(package));
    if (await flagFile.exists()) {
      logger(() => 'Package already extracted: ${package.name}');
      return package;
    }

    try {
      final fileMd5 = await _getFileMd5(zipFile);
      if (fileMd5 != package.shasum) {
        logger(() => 'MD5 mismatch for ${package.name}: expected ${package.shasum}, got $fileMd5');
        await zipFile.delete();
        return null;
      }

      final pkgDir = _repository.getPackageDir(package);
      final dir = Directory(pkgDir);

      if (!(await dir.exists())) {
        await dir.create(recursive: true);
      }

      logger(() => 'Unzipping to $pkgDir');
      await _unzip(zipFile, pkgDir);

      await flagFile.create();
      logger(() => 'Package ready: ${package.name}');
      return package;
    } catch (e) {
      logger(() => 'Failed to unzip ${package.name}: $e');
      return null;
    }
  }

  Future<void> _unzip(File zipFile, String outputPath) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    if (archive.files.isEmpty) return;

    final firstFile = archive.files.first;
    int separateIndex = firstFile.name.indexOf('/');
    if (separateIndex < 0) separateIndex = firstFile.name.length - 1;

    final rootDir = firstFile.name.substring(0, separateIndex);

    for (final file in archive.files.skip(1)) {
      final fileName = file.name.substring(rootDir.length + 1);
      final filePath = path.join(outputPath, path.normalize(fileName));

      if (!path.isWithin(outputPath, filePath)) continue;

      if (!file.isFile && !file.isSymbolicLink) {
        await Directory(filePath).parent.create(recursive: true);
        continue;
      }

      final outputFile = File(filePath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(file.content as List<int>);
      file.clear();
    }
  }

  Future<String> _getFileMd5(File file) async {
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  void cancel(String url) {
    _cancelTokens[url]?.cancel('User cancelled');
  }

  double getProgress(String url) => _progress[url] ?? 0;

  bool isDownloading(String url) => _cancelTokens.containsKey(url);
}
