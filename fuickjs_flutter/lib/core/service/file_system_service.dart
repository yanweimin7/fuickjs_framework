import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'base_fuick_service.dart';

class FileSystemService extends BaseFuickService {
  @override
  String get name => 'FileSystem';

  FileSystemService() {
    registerAsyncMethod('getDirectories', (args) async {
      final dirs = <String, String>{};
      try {
        final temp = await getTemporaryDirectory();
        dirs['temporary'] = temp.path;

        final appDoc = await getApplicationDocumentsDirectory();
        dirs['documents'] = appDoc.path;

        final appSupport = await getApplicationSupportDirectory();
        dirs['support'] = appSupport.path;

        final libDir = await getLibraryDirectory();
        dirs['library'] = libDir.path;
      } catch (e) {
        logger.e('Error getting directories: $e');
      }
      return dirs;
    });

    registerAsyncMethod('readFile', (args) async {
      final path = _getPath(args);
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File not found: $path');
      }

      final encoding = args is Map ? args['encoding'] : null;
      if (encoding == 'base64') {
        final bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }

      return await file.readAsString();
    });

    registerAsyncMethod('writeFile', (args) async {
      final path = _getPath(args);
      if (path == null) return false;

      final content = args is Map ? args['data'] : null;
      if (content == null) return false;

      final file = File(path);
      final encoding = args is Map ? args['encoding'] : null;

      if (encoding == 'base64') {
        await file.writeAsBytes(base64Decode(content));
      } else {
        await file.writeAsString(content.toString());
      }
      return true;
    });

    registerAsyncMethod('exists', (args) async {
      final path = _getPath(args);
      if (path == null) return false;
      return await File(path).exists() || await Directory(path).exists();
    });

    registerAsyncMethod('unlink', (args) async {
      final path = _getPath(args);
      if (path == null) return false;

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    });

    registerAsyncMethod('mkdir', (args) async {
      final path = _getPath(args);
      if (path == null) return false;

      final recursive = args is Map && args['recursive'] == true;
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: recursive);
        return true;
      }
      return false;
    });

    registerAsyncMethod('rmdir', (args) async {
      final path = _getPath(args);
      if (path == null) return false;

      final recursive = args is Map && args['recursive'] == true;
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: recursive);
        return true;
      }
      return false;
    });

    registerAsyncMethod('readdir', (args) async {
      final path = _getPath(args);
      if (path == null) return [];

      final dir = Directory(path);
      if (!await dir.exists()) {
        throw Exception('Directory not found: $path');
      }

      final List<String> entries = [];
      await for (final entity
          in dir.list(recursive: false, followLinks: false)) {
        entries.add(entity.path.split(Platform.pathSeparator).last);
      }
      return entries;
    });

    registerAsyncMethod('stat', (args) async {
      final path = _getPath(args);
      if (path == null) return null;

      final stat = await FileStat.stat(path);
      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }

      return {
        'type': stat.type.toString(), // file, directory, link, notFound
        'size': stat.size,
        'mode': stat.mode,
        'changed': stat.changed.millisecondsSinceEpoch,
        'modified': stat.modified.millisecondsSinceEpoch,
        'accessed': stat.accessed.millisecondsSinceEpoch,
        'isFile': stat.type == FileSystemEntityType.file,
        'isDirectory': stat.type == FileSystemEntityType.directory,
      };
    });

    registerAsyncMethod('rename', (args) async {
      final oldPath = _getPath(args, key: 'oldPath');
      final newPath = _getPath(args, key: 'newPath');
      if (oldPath == null || newPath == null) return false;

      final file = File(oldPath);
      if (await file.exists()) {
        await file.rename(newPath);
        return true;
      }
      final dir = Directory(oldPath);
      if (await dir.exists()) {
        await dir.rename(newPath);
        return true;
      }
      return false;
    });

    registerAsyncMethod('copyFile', (args) async {
      final src = _getPath(args, key: 'src');
      final dest = _getPath(args, key: 'dest');
      if (src == null || dest == null) return false;

      final file = File(src);
      if (await file.exists()) {
        await file.copy(dest);
        return true;
      }
      return false;
    });
  }

  String? _getPath(dynamic args, {String key = 'path'}) {
    if (args is String && key == 'path') return args;
    if (args is Map) {
      return args[key]?.toString();
    }
    return null;
  }
}
