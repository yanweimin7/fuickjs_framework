import 'package:fjs_engine/core/js_bridge.dart';
import 'package:flutter/material.dart';

import '../container/fuick_app_controller.dart';
import '../logger.dart';
import 'base_fuick_service.dart';
import 'native_event_service.dart';

/// App-level lifecycle service.
///
/// Detects foreground/background transitions via [WidgetsBindingObserver] and
/// emits events to JS so that [useVisible] / [useInvisible] hooks respond to
/// app-level state changes in addition to page-level (push/pop) visibility.
class LifecycleService extends BaseFuickService with WidgetsBindingObserver {
  @override
  String get name => 'Lifecycle';

  /// Current app lifecycle state.
  AppLifecycleState _state = AppLifecycleState.resumed;

  /// Whether the app is currently in the background (paused / inactive / hidden / detached).
  bool _isInBackground = false;

  LifecycleService() {
    registerAsyncMethod('getState', (_) async => _state.name);
  }

  @override
  void init(JsBridge context, FuickAppController? appController) {
    super.init(context, appController);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isDisposed) return;

    final prevState = _state;
    _state = state;

    // Determine if transitioning to background or foreground.
    final bool enteringBackground = _isBackgroundState(state);
    final bool enteringForeground = state == AppLifecycleState.resumed;

    if (enteringBackground && !_isInBackground) {
      _isInBackground = true;
      _emitToJS('appDidEnterBackground', {'state': state.name});
    } else if (enteringForeground && _isInBackground) {
      _isInBackground = false;
      _emitToJS('appWillEnterForeground', {'state': state.name});
    }

    if (state != prevState) {
      logger.d(
        '[Lifecycle] App state: ${prevState.name} → ${state.name} '
        '(background=$_isInBackground)',
      );
    }
  }

  /// Whether the given state means the app is not visible to the user.
  bool _isBackgroundState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        return true;
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        return false;
    }
  }

  void _emitToJS(String event, Map<String, dynamic> data) {
    final nativeEvent = controller?.getService<NativeEventService>();
    if (nativeEvent == null) {
      logger.w('[Lifecycle] NativeEventService not available, dropping $event');
      return;
    }
    nativeEvent.emit(event, data);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
