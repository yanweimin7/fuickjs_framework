import 'package:flutter/material.dart';
import '../container/fuick_app_controller.dart';
import '../service/fuick_command_bus.dart';

abstract class FuickWidget implements StatefulWidget {
  String? get refId;
}

mixin FuickCommandListenerMixin<T extends FuickWidget> on State<T> {
  FuickCommandBus? _commandBus;

  String? get refId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newBus = FuickAppScope.of(context)?.commandBus;
    if (_commandBus != newBus) {
      _unregisterCommandListener(refId);
      _commandBus = newBus;
      _registerCommandListener();
    }
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateCommandListener(oldWidget.refId);
  }

  void _registerCommandListener() {
    if (refId != null && _commandBus != null) {
      _commandBus!.addListener(refId!, onCommand);
    }
  }

  void _unregisterCommandListener(String? id) {
    if (id != null && _commandBus != null) {
      _commandBus!.removeListener(id, onCommand);
    }
  }

  /// Updates the command listener when the refId changes.
  /// Call this from [didUpdateWidget].
  void updateCommandListener(String? oldRefId) {
    if (refId != oldRefId) {
      _unregisterCommandListener(oldRefId);
      _registerCommandListener();
    }
  }

  void onCommand(String method, dynamic args);

  @override
  void dispose() {
    _unregisterCommandListener(refId);
    super.dispose();
  }
}
