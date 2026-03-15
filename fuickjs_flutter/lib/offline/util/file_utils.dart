import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

import 'logger.dart';

extension FileEx on File {
  Future<void> writeToFileGuard(String str) async {
    try {
      final parentDir = parent;
      if (!(await parentDir.exists())) {
        await parentDir.create(recursive: true);
      }

      final tempFile = File(path.join(parentDir.path, '.${path.basename(this.path)}.tmp'));
      await tempFile.writeAsString(str, flush: true);
      await tempFile.rename(absolute.path);
    } catch (e) {
      logger(() => 'failed to writeToFileGuard ${absolute.path}, $e');
    }
  }
}

class FileUtils {
  static Future<String> readFile(String filePath,
      {String defaultValue = ''}) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file.readAsString();
    }
    return defaultValue;
  }

  static Future<void> unzip(File zipFile, String outputPath) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    if (archive.files.isEmpty) return;

    final dirFile = archive.files.first;
    int seperateIndex = dirFile.name.indexOf('/');
    if (seperateIndex < 0) seperateIndex = dirFile.name.length - 1;

    String rootDir = dirFile.name.substring(0, seperateIndex);

    for (final file in archive.files.sublist(1)) {
      final fileName = file.name.substring(rootDir.length + 1);
      final filePath = path.join(outputPath, path.normalize(fileName));

      if (!path.isWithin(outputPath, filePath)) {
        continue;
      }

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
}
