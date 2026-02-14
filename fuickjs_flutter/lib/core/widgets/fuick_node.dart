import 'package:flutter/material.dart';

import '../utils/extensions.dart';

class FuickNode {
  final int id;
  String type;
  bool isBoundary;
  Map<String, dynamic> props;
  List<FuickNode> children;
  int version = 0;
  final Map<String, dynamic> _resolvedProps = {};
  int _resolvedVersion = -1;

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
    bool changed = false;

    // 1. Update children
    if (children.length != newChildren.length) {
      changed = true;
    } else {
      for (int i = 0; i < children.length; i++) {
        if (children[i] != newChildren[i]) {
          changed = true;
          break;
        }
      }
    }

    // 2. Update props
    if (!changed && !identical(props, newProps)) {
      if (props.length != newProps.length) {
        changed = true;
      } else {
        for (final key in newProps.keys) {
          if (props[key] != newProps[key]) {
            changed = true;
            break;
          }
        }
      }
    }

    if (changed) {
      children = newChildren;
      props = newProps;
      version++;
    }
  }

  /// 按需处理属性中的节点升级
  dynamic _resolveValue(dynamic value, FuickNodeManager manager) {
    if (value is Map) {
      final type = value['type'];
      if (type is String && value.containsKey('id')) {
        if (type == 'flutter-props' ||
            type == 'FlutterProps' ||
            type == 'Props') {
          final childrenDsl = value['children'] as List?;
          if (childrenDsl == null || childrenDsl.isEmpty) return null;
          final upgradedChildren = childrenDsl
              .map((c) => _resolveValue(c, manager))
              .where((e) => e != null)
              .toList();
          if (upgradedChildren.isEmpty) return null;
          return upgradedChildren.length == 1
              ? upgradedChildren.first
              : upgradedChildren;
        }
        return manager.createNode(asMap(value), manager);
      }
      return value;
    }
    return value;
  }

  T? getProp<T>(String key, {FuickNodeManager? manager}) {
    if (_resolvedVersion != version) {
      _resolvedProps.clear();
      _resolvedVersion = version;
    }

    if (_resolvedProps.containsKey(key)) {
      final cached = _resolvedProps[key];
      if (cached is T) return cached;
      return null;
    }

    final val = props[key];
    if (val == null) return null;

    // 如果是 Map 且可能是节点，尝试升级
    if (val is Map && manager != null) {
      final resolved = _resolveValue(val, manager);
      _resolvedProps[key] = resolved;
      if (resolved is T) return resolved;
      return null;
    }

    if (val is T) {
      _resolvedProps[key] = val;
      return val;
    }
    return null;
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
    final props = (dsl['props'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final childrenDsl = (dsl['children'] as List?) ?? const [];

    // 1. Recursively create/update children
    List<FuickNode> children;
    if (childrenDsl.isEmpty) {
      children = const [];
    } else {
      children = childrenDsl.map((c) => createNode(asMap(c), manager)).toList();
    }

    // 2. Check for existing node to reuse
    final existingNode = _nodes[id];
    if (existingNode != null && existingNode.type == type) {
      existingNode.isBoundary = isBoundary;
      existingNode.update(props, children, manager);
      return existingNode;
    }

    // 3. Create new node if not found or type mismatch
    FuickNode node = FuickNode(
      id: id,
      type: type,
      isBoundary: isBoundary,
      props: props,
      children: children,
    );

    // 4. Cache node
    _nodes[id] = node;

    return node;
  }

  void applyPatches(List<dynamic> patches, FuickNodeManager manager) {
    for (final patch in patches) {
      if (patch is! Map) continue;
      final dsl = patch.cast<String, dynamic>();
      final id = asInt(dsl['id']);
      final node = createNode(dsl, manager);
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
        final newProps = ops[i++] as Map;
        final node = _nodes[id];
        if (node != null) {
          // 增量更新 props
          final mergedProps = Map<String, dynamic>.from(node.props);
          newProps.forEach((k, v) => mergedProps[k.toString()] = v);
          node.update(mergedProps, node.children, manager);
          manager.notify(id, node);
        }
      } else if (opCode == 2) {
        // INSERT: parentId, childId, index, childDsl
        final parentId = asInt(ops[i++]);
        i++; // skip childId as it is in childDsl
        final index = asInt(ops[i++]);
        final childDsl = ops[i++];

        final parent = _nodes[parentId];
        if (parent != null) {
          final childNode = createNode(asMap(childDsl), manager);
          if (index >= 0 && index <= parent.children.length) {
            parent.children.insert(index, childNode);
          } else {
            parent.children.add(childNode);
          }
          parent.version++;
          manager.notify(parentId, parent);
        }
      } else if (opCode == 3) {
        // DELETE: parentId, childId
        final parentId = asInt(ops[i++]);
        final childId = asInt(ops[i++]);

        final parent = _nodes[parentId];
        if (parent != null) {
          parent.children.removeWhere((c) => c.id == childId);
          parent.version++;
          manager.notify(parentId, parent);
        }
      }
    }
  }
}
