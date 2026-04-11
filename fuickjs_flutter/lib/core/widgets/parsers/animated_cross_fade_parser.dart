import 'package:flutter/material.dart';

import '../widget_factory.dart';
import '../widget_utils.dart';
import '../../utils/extensions.dart';
import 'widget_parser.dart';

class AnimatedCrossFadeParser extends WidgetParser {
  @override
  String get type => 'AnimatedCrossFade';

  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> props,
    dynamic children,
    WidgetFactory factory,
  ) {
    final firstChildDsl = props['firstChild'];
    final secondChildDsl = props['secondChild'];
    final durationMs = asInt(props['duration'] ?? 300);
    final stateStr = props['crossFadeState'] as String?;

    final crossFadeState = stateStr == 'showSecond'
        ? CrossFadeState.showSecond
        : CrossFadeState.showFirst;

    return AnimatedCrossFade(
      firstChild: firstChildDsl != null
          ? factory.build(context, firstChildDsl)
          : const SizedBox.shrink(),
      secondChild: secondChildDsl != null
          ? factory.build(context, secondChildDsl)
          : const SizedBox.shrink(),
      crossFadeState: crossFadeState,
      duration: Duration(milliseconds: durationMs),
      firstCurve: WidgetUtils.parseCurve(props['firstCurve'] as String?),
      secondCurve: WidgetUtils.parseCurve(props['secondCurve'] as String?),
      sizeCurve: WidgetUtils.parseCurve(props['sizeCurve'] as String?),
      alignment: WidgetUtils.alignment(props['alignment'] as String?) ?? Alignment.topCenter,
    );
  }
}
