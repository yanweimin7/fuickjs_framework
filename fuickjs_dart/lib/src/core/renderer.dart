import 'page_container.dart';
import '../state/stateful_widget.dart';

/// Manages active pages. Called by globals.dart render/destroy.
class Renderer {
  static final _pages = <int, PageContainer>{};

  /// Mount a widget to a page. Builds the DSL and pushes to Flutter.
  static void mount(int pageId, FuickWidget widget) {
    final page = PageContainer(pageId);
    _pages[pageId] = page;

    final root = buildWidget(widget, page);
    page.root = root;
    page.rebuild();
  }

  /// Destroy a page and free its callbacks.
  static void destroy(int pageId) {
    _pages.remove(pageId);
  }

  /// Dispatch an event from Flutter to the correct page's callback.
  /// eventObj is already dartify()-ed (a Dart Map) when called from globals.dart.
  static void dispatchEvent(dynamic eventObj, dynamic payload) {
    final map = eventObj as Map<Object?, Object?>?;
    if (map == null) return;
    final pageId = (map['pageId'] as num?)?.toInt();
    if (pageId == null) return;
    _pages[pageId]?.dispatch(map, payload);
  }

  /// Returns the DSL JSON string for the current root of [pageId].
  static String? getDsl(int pageId) => _pages[pageId]?.root?.toJsonString();
}
