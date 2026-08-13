/**
 * 透明节点（FlutterProps）的 type 字符串。
 *
 * 这类节点不产出自己的 DSL，其 children 会被提升到父节点的 props[propsKey]，
 * 因此序列化、缓存失效传播、增量 diff 三条路径都要识别它。
 *
 * Flutter 侧的同名常量在 `fuickjs_flutter/lib/core/widgets/fuick_node.dart`
 * (`kTransparentNodeTypes`)，两侧必须保持一致。
 */
export const TRANSPARENT_TYPES = ['FlutterProps', 'flutter-props'] as const;

/** 框架自身产出透明节点时使用的 type（`flutter-props` 仅为兼容手写 JSX 的别名）。 */
export const FLUTTER_PROPS_TYPE = TRANSPARENT_TYPES[0];

export function isTransparentType(type: unknown): boolean {
  return type === 'FlutterProps' || type === 'flutter-props';
}
