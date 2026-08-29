import 'package:flutter/material.dart';

import '../../logger.dart';

/// centerSlice runtime safety wrapper.
///
/// Checks if centerSlice borders fit within widget size after image loads.
/// If not, drops centerSlice to prevent paintImage assertion crash.
class SafeCenterSliceImage extends StatefulWidget {
  final ImageProvider imageProvider;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Rect centerSlice;
  final bool gaplessPlayback;
  final ImageErrorWidgetBuilder? errorBuilder;

  const SafeCenterSliceImage({
    super.key,
    required this.imageProvider,
    this.width,
    this.height,
    required this.fit,
    this.color,
    this.colorBlendMode,
    required this.centerSlice,
    this.gaplessPlayback = false,
    this.errorBuilder,
  });

  @override
  State<SafeCenterSliceImage> createState() => _SafeCenterSliceImageState();
}

class _SafeCenterSliceImageState extends State<SafeCenterSliceImage> {
  ImageInfo? _imageInfo;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disposeStream();
    _resolve();
  }

  @override
  void didUpdateWidget(SafeCenterSliceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageProvider != oldWidget.imageProvider) {
      _disposeStream();
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    _stream = stream;
    _listener = ImageStreamListener(_onImage, onError: _onError);
    stream.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool _) {
    _imageInfo?.dispose();
    _imageInfo = info;
    if (mounted) setState(() {});
  }

  void _onError(Object exception, StackTrace? stackTrace) {
    if (mounted) setState(() {});
  }

  void _disposeStream() {
    if (_listener != null && _stream != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
    _imageInfo?.dispose();
    _imageInfo = null;
  }

  @override
  void dispose() {
    _disposeStream();
    super.dispose();
  }

  Rect? _effectiveCenterSlice() {
    if (_imageInfo == null) return widget.centerSlice;
    final imageWidth = _imageInfo!.image.width.toDouble();
    final imageHeight = _imageInfo!.image.height.toDouble();
    final slice = widget.centerSlice;
    final borderW = slice.left + (imageWidth - slice.right);
    final borderH = slice.top + (imageHeight - slice.bottom);
    final widgetW = widget.width;
    final widgetH = widget.height;
    if ((widgetW != null && borderW > widgetW) ||
        (widgetH != null && borderH > widgetH)) {
      logger.w(
        "[SafeCenterSliceImage] centerSlice dropped: borders "
        "(${borderW.toStringAsFixed(0)}x${borderH.toStringAsFixed(0)}) "
        "exceed widget size. Image: ${imageWidth.toStringAsFixed(0)}x"
        "${imageHeight.toStringAsFixed(0)}, slice: $slice",
      );
      return null;
    }
    return widget.centerSlice;
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: widget.imageProvider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      centerSlice: _effectiveCenterSlice(),
      gaplessPlayback: widget.gaplessPlayback,
      errorBuilder: widget.errorBuilder,
    );
  }
}
