import '../core/node.dart';
import '../core/page_container.dart';

/// Base class for all FuickJS widget descriptors.
abstract class FWidget implements DslSerializable {
  Map<String, dynamic>? _props;
  List<FWidget>? _children;

  /// The widget type name sent to Flutter (e.g. 'Container', 'Text').
  String get widgetType;

  /// Set a scalar or serializable prop. Null values are ignored.
  void setProp(String key, dynamic value) {
    if (value == null) return;
    (_props ??= {})[key] = _serialize(value);
  }

  /// Register a zero-arg event callback.
  void setEvent(String eventKey, void Function() fn) {
    final page = currentPage;
    if (page == null) return;
    _pendingNodeId ??= allocId();
    (_props ??= {})[eventKey] = page.registerEvent(_pendingNodeId!, eventKey, fn);
  }

  /// Add child widgets (for layout widgets).
  void addChildren(List<FWidget>? children) {
    if (children == null) return;
    (_children ??= []).addAll(children);
  }

  /// Add a single child widget.
  void addChild(FWidget? child) {
    if (child != null) (_children ??= []).add(child);
  }

  int? _pendingNodeId;

  /// Convert this widget descriptor to a [DslNode].
  DslNode toDslNode() {
    final id = _pendingNodeId ?? allocId();
    _pendingNodeId = null;
    final children = _children;
    return DslNode.withId(
      id,
      widgetType,
      _props ?? const {},
      children == null ? const [] : [for (final c in children) c.toDslNode()],
    );
  }

  static dynamic _serialize(dynamic value) {
    if (value is FWidget) return value.toJson();
    if (value is List) return value.map(_serialize).toList();
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), _serialize(v)));
    return value;
  }

  @override
  Map<String, dynamic> toJson() => toDslNode().toJson();
}
