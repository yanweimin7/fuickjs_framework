import 'package:flutter/material.dart';

import '../../container/fuick_action.dart';
import '../../logger.dart';
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
    final obscureText = props['obscureText'] == true;
    final maxLines = asIntOrNull(props['maxLines']);
    final keyboardType = _parseTextInputType(props['keyboardType'] as String?);
    final textInputAction =
        _parseTextInputAction(props['textInputAction'] as String?);
    final autofocus = props['autofocus'] == true;
    final textAlign = _parseTextAlign(props['textAlign'] as String?);
    final readOnly = props['readOnly'] == true;

    final enabled = props['enabled'] != false;
    final maxLength = asIntOrNull(props['maxLength']);
    final onChangedEvent = props['onChanged'];
    final onSubmittedEvent = props['onSubmitted'];
    final onFocusEvent = props['onFocus'];
    final onBlurEvent = props['onBlur'];

    return WidgetUtils.wrapPadding(
      props,
      FuickTextField(
        key: refId != null ? ValueKey(refId) : null,
        refId: refId,
        text: text,
        hintText: hint,
        border: border,
        obscureText: obscureText,
        maxLines: maxLines ?? 1,
        maxLength: maxLength,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofocus: autofocus,
        textAlign: textAlign ?? TextAlign.start,
        readOnly: readOnly,
        props: props,
        onChanged: (v) {
          FuickAction.event(context, onChangedEvent, value: v);
        },
        onSubmitted: (v) {
          FuickAction.event(context, onSubmittedEvent, value: v);
        },
        onFocus: onFocusEvent != null
            ? () => FuickAction.event(context, onFocusEvent)
            : null,
        onBlur: onBlurEvent != null
            ? () => FuickAction.event(context, onBlurEvent)
            : null,
      ),
    );
  }

  TextInputType? _parseTextInputType(String? value) {
    switch (value) {
      case 'text':
        return TextInputType.text;
      case 'multiline':
        return TextInputType.multiline;
      case 'number':
        return TextInputType.number;
      case 'phone':
        return TextInputType.phone;
      case 'datetime':
        return TextInputType.datetime;
      case 'emailAddress':
        return TextInputType.emailAddress;
      case 'url':
        return TextInputType.url;
      case 'visiblePassword':
        return TextInputType.visiblePassword;
      default:
        return null;
    }
  }

  // iOS 不支持 TextInputAction.none，会触发断言崩溃；
  // 将 'none' 映射为 unspecified（语义最接近：无特定动作）。
  TextInputAction? _parseTextInputAction(String? value) {
    switch (value) {
      case 'done':
        return TextInputAction.done;
      case 'go':
        return TextInputAction.go;
      case 'next':
        return TextInputAction.next;
      case 'search':
        return TextInputAction.search;
      case 'send':
        return TextInputAction.send;
      case 'none':
        return TextInputAction.unspecified;
      case 'unspecified':
        return TextInputAction.unspecified;
      default:
        return null;
    }
  }

  TextAlign? _parseTextAlign(String? value) {
    switch (value) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      case 'start':
        return TextAlign.start;
      case 'end':
        return TextAlign.end;
      default:
        return null;
    }
  }
}

class FuickTextField extends StatefulWidget implements FuickDslWidget {
  @override
  final String? refId;
  final String text;
  final String hintText;
  final String? border;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final TextAlign textAlign;
  final bool readOnly;
  final Map<String, dynamic> props;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFocus;
  final VoidCallback? onBlur;
  final ControllerCallback<TextEditingController>? onControllerCreated;
  final ControllerCallback<TextEditingController>? onDispose;

  const FuickTextField({
    super.key,
    this.refId,
    required this.text,
    required this.hintText,
    this.border,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    required this.props,
    this.onChanged,
    this.onSubmitted,
    this.onFocus,
    this.onBlur,
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
    _focusNode.addListener(_onFocusChanged);
    widget.onControllerCreated?.call(_controller);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.onFocus?.call();
    } else {
      widget.onBlur?.call();
    }
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
      logger.d('setSelection args: $args');
      final start = asIntOrNull(args['start']);
      final end = asIntOrNull(args['end']);
      logger.d('setSelection parsed: start=$start, end=$end');
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
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      readOnly: widget.readOnly,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: widget.border == 'none'
            ? InputBorder.none
            : widget.border == 'outline'
                ? const OutlineInputBorder()
                : null,
        counterText: widget.maxLength != null ? '' : null,
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      // iOS 16+ 在 Overlay/Dialog 中使用原生系统上下文菜单时，
      // TextInputConnection 可能因 Overlay rebuild 断开，
      // 导致 'TextInput._instance._currentConnection != null' 断言崩溃。
      // 使用 AdaptiveTextSelectionToolbar.buttonItems 替代原生菜单，避免此问题。
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: editableTextState.contextMenuButtonItems,
        );
      },
    );
  }
}
