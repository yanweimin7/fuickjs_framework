import 'package:flutter/material.dart';

import '../../container/fuick_app_controller.dart';
import '../../container/fuick_page_view.dart';
import '../widget_factory.dart';
import 'widget_parser.dart';

class OverlayParser extends WidgetParser {
  @override
  String get type => 'Overlay';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    return _OverlayHostWidget(
      visible: props['visible'] ?? true,
      overlayKey: props['overlayKey']?.toString(),
      children: factory.buildChildren(context, children),
    );
  }
}

class _OverlayHostWidget extends StatefulWidget {
  final bool visible;
  final String? overlayKey;
  final List<Widget> children;

  const _OverlayHostWidget({
    required this.visible,
    this.overlayKey,
    required this.children,
  });

  @override
  State<_OverlayHostWidget> createState() => _OverlayHostWidgetState();
}

class _OverlayHostWidgetState extends State<_OverlayHostWidget> {
  OverlayEntry? _entry;
  bool _scheduledInsert = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _scheduleInsert();
    }
  }

  @override
  void didUpdateWidget(_OverlayHostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _scheduleInsert();
      } else {
        _remove();
      }
    } else if (widget.visible && _entry != null) {
      _entry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _scheduleInsert() {
    if (_scheduledInsert) return;
    _scheduledInsert = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledInsert = false;
      if (mounted && widget.visible && _entry == null) {
        _insert();
      }
    });
  }

  void _insert() {
    final overlay = Overlay.of(context);
    final appScope = FuickAppScope.find(context);
    final pageScope = FuickPageScope.of(context);

    _entry = OverlayEntry(
      builder: (overlayContext) {
        Widget child = widget.children.isNotEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.children,
              )
            : const SizedBox.shrink();

        if (pageScope != null) {
          child = FuickPageScope(pageId: pageScope.pageId, child: child);
        }
        if (appScope != null) {
          child = FuickAppScope(controller: appScope, child: child);
        }

        return Material(
          type: MaterialType.transparency,
          child: child,
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
