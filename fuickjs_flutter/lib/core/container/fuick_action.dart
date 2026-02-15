import 'package:flutter/material.dart';

import 'fuick_app_controller.dart';

class FuickAction {
  static void event(BuildContext context, dynamic eventObj,
      {dynamic value, FuickAppController? controller}) {
    // Use find() instead of of() to avoid creating a dependency,
    // which allows calling this method safely during dispose() or when the widget is unmounting.
    final ctrl = controller ?? FuickAppScope.find(context);
    if (ctrl == null) {
      // It's possible that the context is unmounted or the scope is gone.
      // Just ignore in that case.
      return;
    }
    ctrl.ctx.invoke('FuickAppController', 'dispatchEvent', [
      eventObj,
      value,
    ]);
  }
}
