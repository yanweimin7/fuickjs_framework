import { Node } from '../core/node';
import { PageContainer } from '../core/PageContainer';
import { UIService } from '../services/UIService';
import { MutationOp } from './types';
import { perfLog } from '../utils/log';

export class IncrementalStrategy {
  private container: PageContainer;
  public mutationQueue: MutationOp[] = [];

  constructor(container: PageContainer) {
    this.container = container;
  }

  public recordUpdate(node: Node, updatePayload: unknown[]) {
    const props: Record<string, unknown> = {};
    for (let i = 0; i < updatePayload.length; i += 2) {
      const key = updatePayload[i] as string;
      const val = updatePayload[i + 1];
      if (key === 'children') continue;
      props[key] = val;
    }

    // Use processProps to handle callbacks and conversions
    const processed = this.container.processProps(node.id, props, node.type);

    // OpCode 1: UPDATE (id, props)
    this.mutationQueue.push({ type: 1, id: node.id, props: processed });

    const flutterProps = this.getFlutterPropsAncestor(node);
    if (flutterProps) {
      this.recordHostUpdateFromFlutterProps(flutterProps);
    }

    // Always check for boundary refresh, even if it's in FlutterProps
    // because the host itself might be a boundary or need to trigger one.
    this.enqueueBoundaryRefresh(node);
  }

  public recordInsert(parent: Node, child: Node, index: number) {
    const flutterProps = this.getFlutterPropsAncestor(parent);
    if (flutterProps) {
      this.recordHostUpdateFromFlutterProps(flutterProps);
      return;
    }

    if (child.type === 'FlutterProps' || child.type === 'flutter-props') {
      this.recordHostUpdateFromFlutterProps(child);
      return;
    }

    if (parent.type === 'FlutterProps' || parent.type === 'flutter-props') {
      this.recordHostUpdateFromFlutterProps(parent);
      return;
    }

    const childDsl = child.toDsl();
    // OpCode 2: INSERT (parentId, childId, index, childDsl)
    this.mutationQueue.push({
      type: 2,
      parentId: parent.id,
      childId: child.id,
      index,
      childDsl,
    });
    this.enqueueBoundaryRefresh(parent);
  }

  public recordRemoval(parent: Node, child: Node) {
    const flutterProps = this.getFlutterPropsAncestor(parent);
    if (flutterProps) {
      this.recordHostUpdateFromFlutterProps(flutterProps);
      return;
    }

    if (child.type === 'FlutterProps' || child.type === 'flutter-props') {
      this.recordHostUpdateFromFlutterProps(child);
      return;
    }

    if (parent.type === 'FlutterProps' || parent.type === 'flutter-props') {
      this.recordHostUpdateFromFlutterProps(parent);
      return;
    }

    // OpCode 3: REMOVE (parentId, childId)
    this.mutationQueue.push({ type: 3, parentId: parent.id, childId: child.id });
    this.enqueueBoundaryRefresh(parent);
  }

  ///如果是属性节点，要找到最近的非props节点，比如 appbar的title属性，要找到appbar节点
  private getFlutterPropsAncestor(node: Node): Node | null {
    let current: Node | null = node;
    while (current) {
      if (current.type === 'FlutterProps' || current.type === 'flutter-props') {
        return current;
      }
      current = current.parent || null;
    }
    return null;
  }

  public clear() {
    this.mutationQueue = [];
  }

  public commit() {
    if (this.mutationQueue.length === 0) return;

    const pageId = this.container.pageId;

    const optimizedOps: (MutationOp | null)[] = [];
    const lastUpdateIndexById = new Map<string, number>();

    for (const op of this.mutationQueue) {
      if (op.type === 1) {
        // UPDATE
        const key = String(op.id);
        const prevIndex = lastUpdateIndexById.get(key);
        if (prevIndex !== undefined) {
          const prevOp = optimizedOps[prevIndex];
          if (prevOp && prevOp.type === 1) {
            // Merge props instead of replacing the op to avoid losing incremental updates
            const prevProps = (prevOp.props || {}) as Record<string, unknown>;
            const nextProps = (op.props || {}) as Record<string, unknown>;
            prevOp.props = { ...prevProps, ...nextProps };
            continue;
          }
        }
        lastUpdateIndexById.set(key, optimizedOps.length);
        optimizedOps.push(op);
      } else {
        optimizedOps.push(op);
      }
    }

    const flattenedOps: unknown[] = [];
    for (const op of optimizedOps) {
      if (op) {
        if (op.type === 1) {
          flattenedOps.push(1, op.id, op.props);
        } else if (op.type === 2) {
          flattenedOps.push(2, op.parentId, op.childId, op.index, op.childDsl);
        } else if (op.type === 3) {
          flattenedOps.push(3, op.parentId, op.childId);
        }
      }
    }
    UIService.patchOps(Number(pageId), flattenedOps);
    perfLog(`[JS] commit(patchOps) page=${pageId}`);
    this.mutationQueue = [];
  }

  private getBoundaryNode(node: Node | null): Node | null {
    if (!node) return null;
    let current = node;
    while (current.parent && !current.props?.isBoundary) {
      current = current.parent;
    }
    return current;
  }

  private enqueueBoundaryRefresh(node: Node) {
    const boundary = this.getBoundaryNode(node);
    if (boundary && boundary !== node) {
      this.mutationQueue.push({ type: 1, id: boundary.id, props: {} });
    }
  }

  /**
   * 在 fuickjs 的架构中， 依次（递归）触发刷新 是确保 DSL 数据一致性 和 Flutter 组件状态同步 的核心机制。以下是为什么要这么做的深度解析：

### 1. 维护 DSL 的层级一致性
在 Flutter 侧，像 AppBar 这样的组件并不是作为 Scaffold 的子节点（Children）存在的，而是作为 Scaffold 的一个 属性（Property） 。

当你在 JS 层嵌套组件时，结构如下：

- Scaffold (Host A)
  - FlutterProps (key: 'appBar')
    - AppBar (Host B)
      - FlutterProps (key: 'title')
        - Text (Node C)
如果不递归更新：

1. 当 Text (Node C) 变化时，如果只更新 AppBar (Host B) 的 title 属性。
2. Scaffold (Host A) 里的 props['appBar'] 仍然保存着 AppBar 的 旧版本 DSL 。
3. 一旦 Scaffold 触发任何重绘（比如背景色变了），它会重新解析自己的 props 。此时它拿到旧的 appBar DSL 并传给 Flutter，Flutter 会根据旧 DSL 还原 AppBar ，导致你之前的 title 更新被 覆盖（回滚） 。
递归更新的作用： 通过递归调用 recordHostUpdateFromFlutterProps ，我们确保了：

- AppBar 的 title 属性更新了。
- Scaffold 的 appBar 属性也同步更新为包含新标题的 AppBar DSL。
- 整个路径上的所有祖先节点都持有最新的数据镜像。
### 2. 触发正确的重绘边界 (Boundary)
Flutter 端的 FuickNode 只有在被标记为 isBoundary 时才会有对应的 StatefulWidget 和 setState 能力。

- 很多时候，内部的小组件（如 Text ）并不是 Boundary。
- 真正持有刷新能力的是外层的 AppBar 或 Scaffold （它们在 AppBar.tsx 和 Scaffold.tsx 中都被标记了 isBoundary: true ）。
依次触发刷新 确保了更新信号能从最底层的变更点，一直传递到最近的那个 有能力执行刷新的祖先节点 。

### 3. 解决 Flutter 属性节点的特殊性
在 Flutter 中， appBar 属性通常要求是一个 PreferredSizeWidget 。在 scaffold_parser.dart 中可以看到，它是通过 factory.build 实时构建的。

如果祖先节点（Scaffold）不知道其属性内部发生了变化，它就不会重新调用 build 来生成新的 appBar 实例，导致 UI 停留在旧状态。

### 总结
依次触发刷新是为了：

1. 防丢失 ：防止父组件重绘时用旧 DSL 覆盖子组件的新状态。
2. 通信号 ：确保更新信号能触达到最近的 Boundary 节点。
3. 准同步 ：保证 Flutter 侧属性注入（Property Injection）逻辑能获取到最新的组件快照。
   * @param flutterPropsNode 
   * @returns 
   */
  private recordHostUpdateFromFlutterProps(flutterPropsNode: Node) {
    const host = flutterPropsNode.parent;
    if (!host) return;

    const propsKey = flutterPropsNode.props?.propsKey as string;
    if (!propsKey) return;

    // Logic from PageContainer.ts
    const allValues: unknown[] = [];
    let hasMultiple = false;

    for (const child of host.children) {
      if (child.type === 'FlutterProps' || child.type === 'flutter-props') {
        const key = child.props?.propsKey as string;
        if (key === propsKey) {
          const childrenDsl = child.children.map((c) => c.toDsl()).filter((c) => c !== null);
          if (childrenDsl.length > 0) {
            allValues.push(...childrenDsl);
          }
          if (child !== flutterPropsNode && child.props?.propsKey === propsKey) {
            hasMultiple = true;
          }
        }
      }
    }

    let finalValue: unknown;
    if (allValues.length === 0) {
      finalValue = null;
    } else if (allValues.length === 1 && !hasMultiple) {
      const accumulatedValues: unknown[] = [];

      for (const child of host.children) {
        if ((child.type === 'FlutterProps' || child.type === 'flutter-props') && child.props?.propsKey === propsKey) {
          const childrenDsl = child.children.map((c) => c.toDsl()).filter((c) => c !== null);
          if (childrenDsl.length > 0) {
            const val = childrenDsl.length === 1 ? childrenDsl[0] : childrenDsl;
            accumulatedValues.push(val);
          }
        }
      }

      if (accumulatedValues.length === 0) {
        finalValue = null;
      } else if (accumulatedValues.length === 1) {
        finalValue = accumulatedValues[0];
      } else {
        finalValue = accumulatedValues;
      }
    } else {
      finalValue = allValues;
    }

    // Push UPDATE op for Host
    this.mutationQueue.push({
      type: 1,
      id: host.id,
      props: { [propsKey]: finalValue },
    });

    // Recursively update if the host itself is part of a FlutterProps
    if (host.parent) {
      const parentFlutterProps = this.getFlutterPropsAncestor(host.parent);
      if (parentFlutterProps) {
        this.recordHostUpdateFromFlutterProps(parentFlutterProps);
      } else {
        this.enqueueBoundaryRefresh(host);
      }
    } else {
      this.enqueueBoundaryRefresh(host);
    }
  }
}
