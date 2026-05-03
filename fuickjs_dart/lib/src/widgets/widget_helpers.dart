import '../core/node.dart';
import '../core/page_container.dart';

/// Returns the current active PageContainer (set during build phase).
/// Throws if called outside a build context.
PageContainer requirePage() {
  final page = currentPage;
  if (page == null) {
    throw StateError(
        'Widget functions must be called inside a build() method.');
  }
  return page;
}

/// Register [fn] as an event on [node] and write the event descriptor into
/// node.props[eventKey].
void registerEvent(DslNode node, String eventKey, void Function() fn) {
  final page = requirePage();
  node.props[eventKey] = page.registerEvent(node.id, eventKey, fn);
}
