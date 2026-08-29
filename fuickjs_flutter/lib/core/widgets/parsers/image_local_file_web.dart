import 'package:flutter/material.dart';

/// Web 端本地文件图片分支：浏览器无 `dart:io File`，`file://`/绝对路径图片不支持。
/// 恒返回 null，让 ImageParser 走 errorSrc / 占位降级。
Widget? buildLocalFileImage({
  required String filePath,
  required double? width,
  required double? height,
  required BoxFit? fit,
  required ColorFilter? colorFilter,
  required bool gaplessPlayback,
  required Color? tintColor,
  required Rect? centerSlice,
  required Widget Function() errorWidget,
  required void Function(BuildContext context, Object error, StackTrace? stackTrace)
      fireError,
}) {
  return null;
}
