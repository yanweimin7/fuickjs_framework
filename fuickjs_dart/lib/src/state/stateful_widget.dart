import '../core/node.dart';
import '../core/page_container.dart';
import '../widgets/fwidget.dart';

/// Base class for all page-level widgets.
abstract class FuickWidget {
  const FuickWidget();
}

/// Stateless widget — build() is called on every rebuild.
abstract class StatelessWidget extends FuickWidget {
  const StatelessWidget();

  FWidget build();
}

/// Stateful widget — holds mutable state via a State object.
abstract class StatefulWidget extends FuickWidget {
  const StatefulWidget();

  State createState();
}

/// State associated with a [StatefulWidget].
abstract class State<T extends StatefulWidget> {
  late T widget;
  late PageContainer _container;

  /// Called once after the state is created. Override to initialize fields.
  void initState() {}

  /// Mutate state and trigger a UI rebuild.
  void setState(void Function() fn) {
    fn();
    _container.rebuild();
  }

  FWidget build();
}

/// Build a widget tree under [page], storing the state/widget reference so
/// that PageContainer.rebuild() can re-invoke build() on state changes.
DslNode buildWidget(FuickWidget widget, PageContainer page) {
  final prev = currentPage;
  setActivePage(page);
  try {
    if (widget is StatelessWidget) {
      page.rootWidget = widget;
      page.rootState = null;
      return widget.build().toDslNode();
    } else if (widget is StatefulWidget) {
      final state = widget.createState()
        ..widget = widget
        .._container = page;
      state.initState();
      page.rootState = state;
      page.rootWidget = null;
      return state.build().toDslNode();
    }
    throw ArgumentError('Unknown widget type: ${widget.runtimeType}');
  } finally {
    setActivePage(prev);
  }
}
