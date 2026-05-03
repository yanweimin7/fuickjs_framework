import 'dart:convert';

int _nextId = 0;

int allocId() => ++_nextId;

/// Represents a DSL node compatible with FuickJS Flutter parser format:
/// { id, type, props, children }
class DslNode {
  final int id;
  final String type;
  final Map<String, dynamic> props;
  final List<DslNode> children;

  DslNode(this.type, this.props, [List<DslNode>? children])
      : id = allocId(),
        children = children ?? [];

  /// Create a node with a pre-allocated id (used by FWidget).
  DslNode.withId(this.id, this.type, this.props, [List<DslNode>? children])
      : children = children ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'props': _serializeProps(props),
        'children': [for (final c in children) c.toJson()],
      };

  String toJsonString() => jsonEncode(toJson());
}

Map<String, dynamic> _serializeProps(Map<String, dynamic> props) {
  if (props.isEmpty) return props;
  final result = <String, dynamic>{};
  for (final entry in props.entries) {
    final v = entry.value;
    result[entry.key] = v is DslSerializable ? v.toJson() : v;
  }
  return result;
}

/// Internal interface so FWidget props can be serialized without circular import.
abstract interface class DslSerializable {
  Map<String, dynamic> toJson();
}
