# FlutterProps：React children 到 Flutter 命名属性的映射机制

## 问题背景

### 结构性冲突

React 与 Flutter 在子组件组织方式上存在根本性差异：

| React 模型 | Flutter Widget 模型 |
|---|---|
| 每个父节点只有 **一个** `children` 数组 | 很多 Widget 通过 **多个命名属性** 接收子 Widget |
| `Parent > [Child1, Child2, Child3]` | `Scaffold(appBar: ..., body: ..., drawer: ...)` |

以 `Scaffold` 为例，它有 **6 个独立的子组件槽位**：

- `appBar`
- `body`
- `floatingActionButton`
- `drawer`
- `endDrawer`
- `bottomNavigationBar`

但 React 的渲染模型只能向父组件传递一个扁平的 children 列表，无法自然表达这些命名槽位。

### 为什么不能直接传 props？

直觉上可以把 `appBar` 作为 Scaffold 组件的普通 prop 传入：

```tsx
// 不可行
<Scaffold appBar={<AppBar title="Hello" />}>
  <Container>body content</Container>
</Scaffold>
```

**不可行的原因**：React Reconciler 要求所有需要生命周期管理的组件必须是 **真实的子节点**。如果将 `appBar` 作为 prop 传入，React 会将其视为普通对象——不会：
- 追踪其内部的状态变化
- 触发生命周期（mount/unmount/update）
- 在状态变更时触发重渲染

`<AppBar>` 需要参与完整的 Reconciliation 流程才能正常工作。

---

## 解决方案：FlutterProps 透明代理节点

### 设计原理

`FlutterProps` 是一个**虚拟包装器**，在 React 树中以普通 child 存在，但在 DSL 序列化时将其内容"提升"到父节点的命名属性中。

```
React 树结构:
Scaffold
  ├── FlutterProps(propsKey: 'appBar')
  │     └── AppBar(isBoundary)
  │           └── FlutterProps(propsKey: 'title')
  │                 └── Text("Hello")
  ├── FlutterProps(propsKey: 'drawer')
  │     └── Drawer
  └── Container                          ← 普通 children

              ↓ toDsl() 序列化后 ↓

DSL 输出:
{
  type: "Scaffold",
  props: {
    appBar: {                            ← 从 children 提升到 props
      type: "AppBar",
      props: {
        title: { type: "Text", props: { text: "Hello" }, children: [] }
      },
      children: []
    },
    drawer: { type: "Drawer", ... }      ← 从 children 提升到 props
  },
  children: [
    { type: "Container", ... }           ← 非 FlutterProps 的留在 children
  ]
}
```

### 关键特性

1. **透明的**：FlutterProps 节点本身**不生成 DSL 输出**，它的 DSL 内容被完全注入到父节点的 props 中
2. **真实的 React child**：FlutterProps 及其内容作为真实的 React children 存在，完整参与 Reconciliation
3. **可嵌套**：支持多层嵌套（如 Scaffold → AppBar → title），递归处理

### 组件实现

```tsx
// fuickjs/src/widgets/FlutterProps.tsx
export class FlutterProps extends React.Component<FlutterPropsProps> {
  render(): ReactNode {
    return React.createElement(
      'FlutterProps',
      { propsKey: this.props.propsKey },
      this.props.children
    );
  }
}
```

### 使用示例

```tsx
// Scaffold.tsx
export class Scaffold extends React.Component<ScaffoldProps> {
  render(): ReactNode {
    return React.createElement('Scaffold', { isBoundary: true, ...otherProps },
      appBar && React.createElement(FlutterProps, { propsKey: 'appBar' }, appBar),
      drawer && React.createElement(FlutterProps, { propsKey: 'drawer' }, drawer),
      floatingActionButton &&
        React.createElement(FlutterProps, { propsKey: 'floatingActionButton' }, floatingActionButton),
      // ... 其他命名槽位
      children,  // 普通的 children
    );
  }
}
```

目前使用 `FlutterProps` 的组件：`Scaffold`、`AppBar`、`AlertDialog`、`Tabs`、`SliverAppBar`、`ListTile`、`BottomNavigationBar`。

---

## TS 端 4 处关键处理

### 1. `node.ts:toDsl()` — 全量 DSL 序列化时的属性提升

```typescript
// node.ts:210-233
for (const child of this.children) {
  if (isTransparentType(child.type)) {
    const propsKey = child.props?.propsKey as string;
    if (propsKey) {
      const propChildren = child.children.map((c) => c.toDsl()).filter((c) => c !== null);
      if (propChildren.length > 0) {
        const newValue = propChildren.length === 1 ? propChildren[0] : propChildren;
        // 处理同一 propsKey 的多次出现（如 AppBar 的多个 actions）
        if (props[propsKey]) {
          if (Array.isArray(props[propsKey])) {
            (props[propsKey] as unknown[]).push(newValue);
          } else {
            props[propsKey] = [props[propsKey], newValue];
          }
        } else {
          props[propsKey] = newValue;
        }
      }
    }
  } else {
    // 非 FlutterProps 子节点保持原样
    children.push(child.toDsl());
  }
}
```

**目的**：在全量序列化时，将 `FlutterProps` 子节点的内容注入父节点的 `props[propsKey]`，而非 `children`。

### 2. `node.ts:_isTransparent()` — 透明节点标记

```typescript
// core/constants.ts —— JS 侧唯一的透明节点 type 判定，Dart 侧对应 kTransparentNodeTypes
export const TRANSPARENT_TYPES = ['FlutterProps', 'flutter-props'] as const;

export function isTransparentType(type: unknown): boolean {
  return type === 'FlutterProps' || type === 'flutter-props';
}

// node.ts
private _isTransparent(): boolean {
  return isTransparentType(this.type);
}
```

**目的**：标记 `FlutterProps` 为透明节点。当 DSL 缓存失效信号向上传播时，透明节点会被"穿透"，继续向上传递到真正的实体 Widget 节点：

```typescript
// node.ts:96-111
private _invalidateParentDslCache() {
  let current = this.parent;
  while (current) {
    current._childrenDslCacheDirty = true;
    // 如果父节点是透明节点，它的 toDsl 不会被直接调用，必须继续向上传播
    if (!wasDirty || current._isTransparent()) {
      current = current.parent;
    } else {
      break;
    }
  }
}
```

### 3. `PageContainer.ts:processDslChild()` — page 节点的属性提升

```typescript
// PageContainer.ts:511-533
private processDslChild(processedProps, dslChildren, childDsl) {
  if (isTransparentType(child.type)) {
    const propsKey = child.props?.propsKey;
    // 将内容提升到 processedProps[propsKey]
    // 支持单 child 打平、多 child 合并
  } else {
    dslChildren.push(child);
  }
}
```

与 `node.ts:toDsl()` 逻辑相同，但作用于 **PageContainer**（页面根容器）的 DSL 序列化。

### 4. `IncrementalStrategy` — 增量更新中的数据一致性（最复杂）

这是 `FlutterProps` 特殊处理中最复杂的部分。

### 4a. 任何节点更新后检查 FlutterProps 上下文

```typescript
// IncrementalStrategy.ts:30-33
public recordUpdate(node: Node, updatePayload: unknown[]) {
  // ... 生成 UPDATE op ...
  const flutterProps = this.getFlutterPropsAncestor(node);
  if (flutterProps) {
    this.recordHostUpdateFromFlutterProps(flutterProps);
  }
}
```

### 4b. 插入/删除节点时重定向操作

```typescript
// IncrementalStrategy.ts:40-55
public recordInsert(parent: Node, child: Node, index: number) {
  const flutterProps = this.getFlutterPropsAncestor(parent);
  if (flutterProps) {
    // 不生成 INSERT op，改为更新宿主节点的属性
    this.recordHostUpdateFromFlutterProps(flutterProps);
    return;
  }
  if (child.type === 'FlutterProps') {
    this.recordHostUpdateFromFlutterProps(child);
    return;
  }
  if (parent.type === 'FlutterProps') {
    this.recordHostUpdateFromFlutterProps(parent);
    return;
  }
  // ... 正常 INSERT op ...
}
```

删除 `FlutterProps` 透明节点本身时，增量策略必须在节点销毁前记录 removal。记录过程需要
沿透明节点的 `parent` 找到实体宿主，并在宿主剩余 children 中重新计算该 `propsKey`：
没有剩余内容时下发 `null`，避免 Flutter 继续显示已经移除的命名槽位。节点销毁随后再
清理回调、缓存和 parent/container 反向引用。

### 4c. `recordHostUpdateFromFlutterProps()` — 核心递归冒泡逻辑

```typescript
// IncrementalStrategy.ts:219-278
private recordHostUpdateFromFlutterProps(flutterPropsNode: Node) {
  const host = flutterPropsNode.parent;
  const propsKey = flutterPropsNode.props?.propsKey;

  // 1. 遍历兄弟节点，收集所有同 propsKey 的 FlutterProps 的 DSL
  // 2. 生成宿主节点的 UPDATE op：{ [propsKey]: finalValue }
  // 3. 查询宿主是否也在某个 FlutterProps 子树内
  // 4. 如果是 → 递归冒泡到外层 FlutterProps
  // 5. 如果否 → 触发 boundary refresh 确保 UI 刷新
}
```

---

## 增量更新中的数据一致性问题

这是需要递归冒泡更新的根本原因。考虑这个嵌套场景：

```
Scaffold (isBoundary)
  └── FlutterProps(key: 'appBar')
        └── AppBar (isBoundary)
              └── FlutterProps(key: 'title')
                    └── Text("Hello")
```

### 如果不递归更新会发生什么

1. 当 `Text("Hello")` → `Text("World")` 变化时，只更新 `AppBar.props.title`
2. `Scaffold.props.appBar` 仍然保存着**旧版 AppBar DSL**（title 为 "Hello"）
3. 一旦 Scaffold 因任何原因重绘（如背景色变化），它会用旧 DSL 重新构建 AppBar
4. 之前的 title 更新被**覆盖丢失**

### 递归更新的作用

通过 `recordHostUpdateFromFlutterProps()` 递归冒泡：

1. `AppBar.props.title` 更新为包含 "World" 的 Text DSL
2. `Scaffold.props.appBar` 同步更新为包含最新 title 的 AppBar DSL
3. 整条路径上的所有祖先节点持有最新的数据镜像

### 递归的终止条件

- 发现宿主节点不再是某个 `FlutterProps` 的子节点 → 触发 `enqueueBoundaryRefresh`（标记 boundary 以触发 UI 刷新）
- 如果宿主继续嵌套在更外层的 `FlutterProps` 内 → 继续递归

---

## Flutter 侧处理

Flutter 侧的 `FuickNode._resolveValue()` 也识别 `FlutterProps` 节点：

```dart
// fuick_node.dart
if (kTransparentNodeTypes.contains(type)) {
  // 从 children 中提取实际值
  final upgradedChildren = childrenDsl
    .map((c) => _resolveValue(c, manager, depth + 1))
    .where((e) => e != null)
    .toList();
  if (upgradedChildren.isEmpty) return null;
  return upgradedChildren.length == 1 ? upgradedChildren.first : upgradedChildren;
}
```

当 DSL 中的 props 值包含内联的 `FlutterProps` 节点时（来自增量更新路径），Flutter 侧执行相同语义的"展开"：将 children 提升为实际值。

---

## 总结

`FlutterProps` 是 React 扁平 children 模型与 Flutter 多命名属性模型的**适配层**。它将所有特殊性集中在这个透明节点上，使得上层组件（Scaffold、AppBar 等）可以同时受益于：

1. **React Reconciliation**：子组件以真实 child 存在，完整参与生命周期、状态追踪和重渲染
2. **Flutter 属性注入**：DSL 序列化时内容被正确映射到命名属性
3. **增量更新数据一致性**：通过递归冒泡保证嵌套命名槽位的整条链路数据同步

新增使用 `FlutterProps` 的组件时，需要在以下位置增加对应处理：
- 组件自身的 render 中用 `FlutterProps` 包装命名槽位子组件
- 无需修改 `node.ts`、`IncrementalStrategy.ts`、`DiffStrategy.ts`——这些文件已通用处理
