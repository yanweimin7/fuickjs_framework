import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'base_fuick_service.dart';
import '../logger.dart';

class MediaService extends BaseFuickService {
  @override
  String get name => 'Media';

  final ImagePicker _picker = ImagePicker();

  MediaService() {
    // previewImage: 全屏预览图片
    registerAsyncMethod('previewImage', (args) async {
      try {
        final Map<dynamic, dynamic> options = args is Map ? args : {};
        final List<dynamic> urls =
            options['urls'] is List ? options['urls'] as List : [];
        final int current = (options['current'] as num?)?.toInt() ?? 0;

        if (urls.isEmpty) return {'success': false, 'error': 'urls is empty'};

        // 获取当前页面 context
        final contexts = controller?.navigation.pageContexts ?? [];
        final BuildContext? ctx =
            contexts.isNotEmpty ? contexts.last : null;
        if (ctx == null || !(ctx as Element).mounted) {
          return {'success': false, 'error': 'No valid context'};
        }

        final urlList = urls.map((e) => e.toString()).toList();

        await Navigator.of(ctx).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, anim, secondAnim) {
              return _ImagePreviewPage(urls: urlList, initialIndex: current);
            },
          ),
        );

        return {'success': true};
      } catch (e) {
        logger.e('[MediaService] previewImage error: $e');
        return {'success': false, 'error': e.toString()};
      }
    });

    // chooseImage: 从相册或相机选择图片
    registerAsyncMethod('chooseImage', (args) async {
      try {
        final Map<dynamic, dynamic> options = args is Map ? args : {};
        final int count = (options['count'] as num?)?.toInt() ?? 1;
        final List<dynamic> sourceTypeList = options['sourceType'] is List
            ? options['sourceType'] as List
            : ['album', 'camera'];

        final bool allowCamera = sourceTypeList.contains('camera');
        final bool allowAlbum = sourceTypeList.contains('album');

        List<XFile> files = [];

        if (allowCamera && !allowAlbum) {
          // 只相机
          final image = await _picker.pickImage(source: ImageSource.camera);
          if (image != null) files = [image];
        } else if (count == 1) {
          // 单选相册
          final image = await _picker.pickImage(source: ImageSource.gallery);
          if (image != null) files = [image];
        } else {
          // 多选相册
          files = await _picker.pickMultiImage(limit: count);
        }

        if (files.isEmpty) {
          // 用户取消
          return null;
        }

        final List<Map<String, dynamic>> result = [];
        for (final file in files) {
          final bytes = await file.length();
          result.add({
            'path': file.path,
            'tempFilePath': file.path,
            'size': bytes,
            'type': 'image',
          });
        }

        return {
          'tempFilePaths': result.map((e) => e['path']).toList(),
          'tempFiles': result,
        };
      } catch (e) {
        logger.e('[MediaService] chooseImage error: $e');
        rethrow;
      }
    });

    // chooseVideo: 从相册或相机选择视频
    registerAsyncMethod('chooseVideo', (args) async {
      try {
        final Map<dynamic, dynamic> options = args is Map ? args : {};
        final List<dynamic> sourceTypeList = options['sourceType'] is List
            ? options['sourceType'] as List
            : ['album', 'camera'];
        final bool allowCamera = sourceTypeList.contains('camera');

        final XFile? file = await _picker.pickVideo(
          source: allowCamera && !sourceTypeList.contains('album')
              ? ImageSource.camera
              : ImageSource.gallery,
        );

        if (file == null) return null;

        final bytes = await file.length();
        return {
          'tempFilePath': file.path,
          'size': bytes,
          'type': 'video',
        };
      } catch (e) {
        logger.e('[MediaService] chooseVideo error: $e');
        rethrow;
      }
    });
  }
}

// ── 全屏图片预览页 ────────────────────────────────────────────────────

class _ImagePreviewPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _ImagePreviewPage({required this.urls, required this.initialIndex});

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.urls.length > 1
            ? Text('${_current + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white))
            : null,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, index) {
          final url = widget.urls[index];
          final isLocal = url.startsWith('/') || url.startsWith('file://');
          return InteractiveViewer(
            child: Center(
              child: isLocal
                  ? Image.file(File(url.replaceFirst('file://', '')),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white, size: 64))
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          const CircularProgressIndicator(color: Colors.white),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white, size: 64),
                    ),
            ),
          );
        },
      ),
    );
  }
}
