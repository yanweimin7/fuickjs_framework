import 'package:flutter/material.dart';

import '../utils/extensions.dart';

class FuickNode {
  final int id;
  String type;
  bool isBoundary;
  Map<String, dynamic> props;
  List<FuickNode> children;

  FuickNode({
    required this.id,
    required this.type,
    required this.props,
    required this.children,
    this.isBoundary = false,
  });

  void update(
    Map<String, dynamic> newProps,
    List<FuickNode> newChildren,
    FuickNodeManager manager,
  ) {
    props = _processProps(newProps, manager);
    children = newChildren;
  }

  Map<String, dynamic> _processProps(
    Map<String, dynamic> rawProps,
    FuickNodeManager manager,
  ) {
    if (rawProps.isEmpty) return rawProps;
    final Map<String, dynamic> processed = {};
    rawProps.forEach((key, value) {
      processed[key] = _findAndUpgradeNodes(value, manager);
    });
    return processed;
  }

  dynamic _findAndUpgradeNodes(dynamic value, FuickNodeManager manager) {
    if (value == null) return null;
    if (value is num || value is String || value is bool) return value;

    if (value is Map) {
      if (value.containsKey('id') && value.containsKey('type')) {
        final String type = value['type'];

        ///挂载到属性上的节点要解析出来 ， 比如  appBar={<AppBar title={<Text text="title" />} />}
        if (type == 'flutter-props' ||
            type == 'FlutterProps' ||
            type == 'Props') {
          // Special handling for FlutterProps: extract and upgrade its children
          final childrenDsl = value['children'] as List?;
          if (childrenDsl == null || childrenDsl.isEmpty) return null;

          final upgradedChildren = childrenDsl
              .map((c) => _findAndUpgradeNodes(c, manager))
              .where((e) => e != null)
              .toList();

          if (upgradedChildren.isEmpty) return null;
          return upgradedChildren.length == 1
              ? upgradedChildren.first
              : upgradedChildren;
        }

        // 这是一个 DSL 节点，升级为 FuickNode
        return manager.createNode(
          Map<String, dynamic>.from(value),
          manager,
        );
      }

      // Plain map, process its values
      final Map<String, dynamic> processedMap = {};
      bool changed = false;
      value.forEach((k, v) {
        final upgraded = _findAndUpgradeNodes(v, manager);
        processedMap[k.toString()] = upgraded;
        if (upgraded != v) changed = true;
      });
      return changed ? processedMap : value;
    } else if (value is List) {
      final List<dynamic> processedList = [];
      bool changed = false;
      for (final e in value) {
        final upgraded = _findAndUpgradeNodes(e, manager);
        processedList.add(upgraded);
        if (upgraded != e) changed = true;
      }
      return changed ? processedList : value;
    }
    return value;
  }
}

typedef FuickNodeListener = void Function(FuickNode node);

class FuickNodeManager {
  final Map<int, Set<FuickNodeListener>> _listeners = {};
  final Map<int, FuickNode> _nodes = {};

  void addListener(int id, FuickNodeListener listener) {
    _listeners.putIfAbsent(id, () => {}).add(listener);
  }

  void removeListener(int id, FuickNodeListener listener) {
    _listeners[id]?.remove(listener);
    if (_listeners[id]?.isEmpty ?? false) {
      _listeners.remove(id);
    }
  }

  void notify(int id, FuickNode node) {
    _nodes[id] = node;
    final callbacks = _listeners[id];
    if (callbacks != null) {
      for (final callback in List.from(callbacks)) {
        callback(node);
      }
    }
  }

  FuickNode createNode(Map<String, dynamic> dsl, FuickNodeManager manager) {
    final id = asInt(dsl['id']);
    final type = dsl['type'] as String;
    final isBoundary = dsl['isBoundary'] == true;
    final props = dsl['props'] as Map? ?? {};
    final childrenDsl = (dsl['children'] as List?) ?? [];

    // 1. Recursively create/update children
    final List<FuickNode> children = childrenDsl
        .map((c) => createNode(c as Map<String, dynamic>, manager))
        .toList();

    // 2. Check for existing node to reuse
    final existingNode = _nodes[id];
    if (existingNode != null && existingNode.type == type) {
      existingNode.isBoundary = isBoundary;
      existingNode.update(
        Map<String, dynamic>.from(props),
        children,
        manager,
      );
      return existingNode;
    }

    // 3. Create new node if not found or type mismatch
    FuickNode node = FuickNode(
      id: id,
      type: type,
      isBoundary: isBoundary,
      props: {},
      children: [],
    );

    // 4. Update props and children
    node.update(Map<String, dynamic>.from(props), children, manager);

    // 5. Cache node
    _nodes[id] = node;

    return node;
  }

  void applyPatches(List<dynamic> patches, FuickNodeManager manager) {
    for (final patch in patches) {
      if (patch is! Map) continue;
      final dsl = Map<String, dynamic>.from(patch);
      final id = asInt(dsl['id']);

      // createNode now handles reuse internally
      final node = createNode(dsl, manager);

      // Trigger UI refresh for the patched node
      manager.notify(id, node);
    }
  }

  void applyOps(List<dynamic> ops, FuickNodeManager manager) {
    int i = 0;
    while (i < ops.length) {
      final opCode = asInt(ops[i++]);
      if (opCode == 1) {
        // UPDATE: id, props
        final id = asInt(ops[i++]);
        final props = ops[i++] as Map;
        final node = _nodes[id];
        if (node != null) {
          final processed = node._processProps(
            Map<String, dynamic>.from(props),
            manager,
          );
          node.props.addAll(processed);
          manager.notify(id, node);
        } else {
          debugPrint(
              '[FuickNodeManager] UPDATE op failed: Node $id not found. Props: $props');
        }
      } else if (opCode == 2) {
        // INSERT: parentId, childId, index, childDsl
        final parentId = asInt(ops[i++]);
        final childId = asInt(ops[i++]);
        final index = asInt(ops[i++]);
        final childDsl = ops[i++];

        final parent = _nodes[parentId];
        if (parent != null) {
          // Ensure child is removed from old location/nodes if it existed (handled by explicit REMOVE op usually, but safety check?)
          // Usually REMOVE op comes before INSERT for moves.
          // But createNode will overwrite _nodes[childId].
          final childNode = createNode(
            Map<String, dynamic>.from(childDsl),
            manager,
          );

          if (index >= 0 && index <= parent.children.length) {
            parent.children.insert(index, childNode);
          } else {
            parent.children.add(childNode);
          }
          manager.notify(parentId, parent);
        } else {
          debugPrint(
              '[FuickNodeManager] INSERT op failed: Parent $parentId not found. Child: $childId');
        }
      } else if (opCode == 3) {
        // REMOVE: parentId, childId
        final parentId = asInt(ops[i++]);
        final childId = asInt(ops[i++]);

        final parent = _nodes[parentId];
        if (parent != null) {
          parent.children.removeWhere((c) => c.id == childId);
          _removeNodeRecursive(childId);
          manager.notify(parentId, parent);
        } else {
          debugPrint(
              '[FuickNodeManager] REMOVE op failed: Parent $parentId not found. Child: $childId');
        }
      } else {
        debugPrint(
            '[FuickNodeManager] Unknown OpCode: $opCode at index ${i - 1}');
      }
    }
  }

  void _removeNodeRecursive(int id) {
    final node = _nodes[id];
    if (node != null) {
      for (final child in node.children) {
        _removeNodeRecursive(child.id);
      }
      _nodes.remove(id);
      _listeners.remove(id);
    }
  }

  void clear() {
    _listeners.clear();
    _nodes.clear();
  }
}

class FuickNodeManagerProvider extends InheritedWidget {
  final FuickNodeManager manager;

  const FuickNodeManagerProvider({
    super.key,
    required this.manager,
    required super.child,
  });

  static FuickNodeManager? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FuickNodeManagerProvider>()
        ?.manager;
  }

  @override
  bool updateShouldNotify(FuickNodeManagerProvider oldWidget) {
    return manager != oldWidget.manager;
  }
}
