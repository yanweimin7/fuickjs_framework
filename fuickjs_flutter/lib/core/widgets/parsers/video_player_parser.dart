import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../container/fuick_action.dart';
import '../../utils/extensions.dart';
import '../fuick_command_listener_mixin.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class VideoPlayerParser extends WidgetParser {
  @override
  String get type => 'VideoPlayer';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    return FuickVideoPlayer(
      refId: props['refId'],
      url: props['url'],
      asset: props['asset'],
      autoPlay: props['autoPlay'] == true,
      looping: props['looping'] == true,
      showControls: props['showControls'] == true,
      onInitialized: asMapOrNull(props['onInitialized']),
      onVideoEnd: asMapOrNull(props['onVideoEnd']),
      onError: asMapOrNull(props['onError']),
    );
  }
}

class FuickVideoPlayer extends StatefulWidget implements FuickWidget {
  @override
  final String? refId;
  final String? url;
  final String? asset;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final Map<String, dynamic>? onInitialized;
  final Map<String, dynamic>? onVideoEnd;
  final Map<String, dynamic>? onError;

  const FuickVideoPlayer({
    super.key,
    this.refId,
    this.url,
    this.asset,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = false,
    this.onInitialized,
    this.onVideoEnd,
    this.onError,
  });

  @override
  State<FuickVideoPlayer> createState() => FuickVideoPlayerState();
}

class FuickVideoPlayerState extends State<FuickVideoPlayer>
    with FuickCommandListenerMixin<FuickVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  String? get refId => widget.refId;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(FuickVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url || widget.asset != oldWidget.asset) {
      _disposeController();
      _initializeController();
    } else {
      // Update properties that don't require re-initialization
      if (widget.looping != oldWidget.looping) {
        _controller?.setLooping(widget.looping);
      }
    }
  }

  Future<void> _initializeController() async {
    try {
      if (widget.url != null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      } else if (widget.asset != null) {
        _controller = VideoPlayerController.asset(widget.asset!);
      } else {
        return;
      }

      await _controller!.initialize();
      _controller!.addListener(_onControllerUpdate);

      if (widget.looping) {
        await _controller!.setLooping(true);
      }
      if (widget.autoPlay) {
        await _controller!.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.onInitialized != null) {
          FuickAction.event(context, widget.onInitialized, value: {
            'duration': _controller!.value.duration.inMilliseconds,
            'size': {
              'width': _controller!.value.size.width,
              'height': _controller!.value.size.height
            },
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (widget.onError != null && mounted) {
        FuickAction.event(context, widget.onError,
            value: {'error': e.toString()});
      }
    }
  }

  void _onControllerUpdate() {
    if (_controller == null) return;
    final value = _controller!.value;
    if (value.isCompleted && widget.onVideoEnd != null) {
      // Debounce or check if we already fired end event?
      // VideoPlayerController might fire multiple times at end.
      // But for now simple dispatch.
      FuickAction.event(context, widget.onVideoEnd);
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  void onCommand(String method, dynamic args) {
    if (_controller == null || !_isInitialized) return;

    switch (method) {
      case 'play':
        _controller!.play();
        break;
      case 'pause':
        _controller!.pause();
        break;
      case 'stop':
        _controller!.pause();
        _controller!.seekTo(Duration.zero);
        break;
      case 'seekTo':
        final position = asInt(args['position']); // in milliseconds
        _controller!.seekTo(Duration(milliseconds: position));
        break;
      case 'setVolume':
        final volume = asDouble(args['volume']);
        if (volume != 0) {
          _controller!.setVolume(volume);
        }
        break;
      case 'setLooping':
        final looping = args['looping'] == true;
        _controller!.setLooping(looping);
        break;
      case 'setPlaybackSpeed':
        final speed = asDouble(args['speed']);
        if (speed != 0) {
          _controller!.setPlaybackSpeed(speed);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller!),
          // We can add basic controls here if showControls is true
          // But for now, let's keep it clean or minimal.
        ],
      ),
    );
  }
}
