import 'package:flutter/material.dart';
import '../../container/fuick_action.dart';
import '../widget_factory.dart';
import '../widget_utils.dart';
import 'widget_parser.dart';

class ButtonParser extends WidgetParser {
  @override
  String get type => 'Button';

  @override
  Widget parse(BuildContext context, Map<String, dynamic> props,
      dynamic children, WidgetFactory factory) {
    final text = (props['text'] ?? '').toString();
    final event = props['onTap'];
    final disabled = props['disabled'] == true;
    final loading = props['loading'] == true;
    final bgColor =
        WidgetUtils.colorFromHex(props['backgroundColor'] as String?);
    final textColor = WidgetUtils.colorFromHex(props['textColor'] as String?);
    final fontSize = WidgetUtils.asDoubleOrNull(props['fontSize']);
    final borderRadius = WidgetUtils.asDoubleOrNull(props['borderRadius']);
    final elevation = WidgetUtils.asDoubleOrNull(props['elevation']);
    final outlined = props['outlined'] == true;
    final borderColor =
        WidgetUtils.colorFromHex(props['borderColor'] as String?);
    final borderWidth = WidgetUtils.asDoubleOrNull(props['borderWidth']) ?? 1.0;
    final minWidth = WidgetUtils.asDoubleOrNull(props['minWidth']);
    final minHeight = WidgetUtils.asDoubleOrNull(props['minHeight']);
    final paddingH = WidgetUtils.asDoubleOrNull(props['paddingH']);
    final paddingV = WidgetUtils.asDoubleOrNull(props['paddingV']);

    final shape = borderRadius != null
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: outlined
                ? BorderSide(
                    color: borderColor ?? bgColor ?? Colors.blue,
                    width: borderWidth,
                  )
                : BorderSide.none,
          )
        : outlined
            ? RoundedRectangleBorder(
                side: BorderSide(
                  color: borderColor ?? bgColor ?? Colors.blue,
                  width: borderWidth,
                ),
              )
            : null;

    final minimumSize = (minWidth != null || minHeight != null)
        ? Size(minWidth ?? 64, minHeight ?? 36)
        : null;

    final padding = (paddingH != null || paddingV != null)
        ? EdgeInsets.symmetric(
            horizontal: paddingH ?? 16,
            vertical: paddingV ?? 8,
          )
        : null;

    Widget child;
    if (loading) {
      child = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: outlined ? (bgColor ?? Colors.blue) : Colors.white,
        ),
      );
    } else {
      child = Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
        ),
      );
    }

    final onPressed =
        disabled || loading ? null : () => FuickAction.event(context, event);

    if (outlined) {
      final style = OutlinedButton.styleFrom(
        foregroundColor: textColor ?? bgColor,
        side: BorderSide(
          color: borderColor ?? bgColor ?? Colors.blue,
          width: borderWidth,
        ),
        shape: shape,
        minimumSize: minimumSize,
        padding: padding,
        elevation: elevation,
      );
      return WidgetUtils.wrapPadding(
        props,
        OutlinedButton(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
      );
    }

    final style = ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: textColor,
      disabledBackgroundColor: bgColor?.withValues(alpha: 0.5),
      shape: shape,
      elevation: elevation,
      minimumSize: minimumSize,
      padding: padding,
    );

    return WidgetUtils.wrapPadding(
      props,
      ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    );
  }
}
