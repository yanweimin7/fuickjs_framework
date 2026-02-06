import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../../utils/extensions.dart';
import '../fuick_command_listener_mixin.dart';
import '../fuick_dsl_cache_mixin.dart';
import '../fuick_state_widgets.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class TextFieldParser extends WidgetParser {
  @override
  String get type => 'TextField';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final hint = (props['hintText'] ?? props['hint'] ?? '') as String;
    final text = (props['text'] ?? '') as String;
    final refId = props['refId'] as String?;
    final border = props['border'] as String?;

    final onChangedEvent = props['onChanged'];
    final onSubmittedEvent = props['onSubmitted'];

    return WidgetUtils.wrapPadding(
      props,
      FuickTextField(
        key: refId != null ? ValueKey(refId) : null,
        refId: refId,
        text: text,
        hintText: hint,
        border: border,
        props: props,
        onChanged: (v) {
          FuickAction.event(context, onChangedEvent, value: v);
        },
        onSubmitted: (v) {
          FuickAction.event(context, onSubmittedEvent, value: v);
        },
      ),
    );
  }
}

class FuickTextField extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  final String text;
  final String hintText;
  final String? border;
  final Map<String, dynamic> props;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ControllerCallback<TextEditingController>? onControllerCreated;
  final ControllerCallback<TextEditingController>? onDispose;

  const FuickTextField({
    super.key,
    this.refId,
    required this.text,
    required this.hintText,
    this.border,
    required this.props,
    this.onChanged,
    this.onSubmitted,
    this.onControllerCreated,
    this.onDispose,
  });

  @override
  dynamic get cacheKey => null;

  @override
  int? get itemCount => null;

  @override
  State<FuickTextField> createState() => _FuickTextFieldState();
}

class _FuickTextFieldState extends State<FuickTextField>
    with
        FuickCommandListenerMixin<FuickTextField>,
        FuickDslCacheMixin<FuickTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  String? get refId => widget.refId;
  @override
  dynamic get cacheKey => widget.cacheKey;
  @override
  int? get itemCount => widget.itemCount;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
    widget.onControllerCreated?.call(_controller);
  }

  @override
  void onCustomCommand(String method, dynamic args) {
    if (method == 'setText') {
      final newText = (args is String ? args : args['text'] as String?) ?? '';
      _controller.text = newText;
    } else if (method == 'clear') {
      _controller.clear();
    } else if (method == 'focus') {
      _focusNode.requestFocus();
    } else if (method == 'unfocus') {
      _focusNode.unfocus();
    } else if (method == 'setSelection') {
      debugPrint('setSelection args: $args');
      final start = asIntOrNull(args['start']);
      final end = asIntOrNull(args['end']);
      debugPrint('setSelection parsed: start=$start, end=$end');
      if (start != null && end != null) {
        _controller.selection =
            TextSelection(baseOffset: start, extentOffset: end);
        _focusNode.requestFocus();
      }
    } else if (method == 'selectAll') {
      _focusNode.requestFocus();
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    }
  }

  @override
  void didUpdateWidget(FuickTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.text = widget.text;
    }

    if (widget.refId != oldWidget.refId) {
      if (oldWidget.refId != null) {
        oldWidget.onDispose?.call(_controller);
      }
      if (widget.refId != null) {
        widget.onControllerCreated?.call(_controller);
      }
    }
  }

  @override
  void dispose() {
    widget.onDispose?.call(_controller);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: widget.border == 'none' ? InputBorder.none : null,
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
