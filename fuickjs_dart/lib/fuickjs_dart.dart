/// FuickJS Dart — write Flutter-style UI in Dart, compile to JS via dart2js,
/// render dynamically in Flutter via the FuickJS DSL pipeline.
library fuickjs_dart;

// Core
export 'src/core/node.dart';
export 'src/core/router.dart';
export 'src/core/renderer.dart';

// State
export 'src/state/stateful_widget.dart';

// Widget types
export 'src/widgets/types.dart';

// FWidget base class
export 'src/widgets/fwidget.dart';

// Widgets
export 'src/widgets/container.dart';
export 'src/widgets/text.dart';
export 'src/widgets/column.dart';
export 'src/widgets/row.dart';
export 'src/widgets/stack.dart';
export 'src/widgets/image.dart';
export 'src/widgets/icon.dart';
export 'src/widgets/divider.dart';
export 'src/widgets/sized_box.dart';
export 'src/widgets/scroll_view.dart';
export 'src/widgets/expanded.dart';
export 'src/widgets/opacity.dart';
export 'src/widgets/scaffold.dart';

// Runtime (dart2js JS interop entry point)
export 'src/runtime/globals.dart';
export 'src/runtime/native.dart';
