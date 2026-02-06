import { Node } from '../node';
import { PageContainer } from '../PageContainer';
import { UIService } from '../services/UIService';
import { MutationOp } from './types';

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
    this.enqueueBoundaryRefresh(node);
  }

  public recordInsert(parent: Node, child: Node, index: number) {
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

  public clear() {
    this.mutationQueue = [];
  }

  public commit() {
    if (this.mutationQueue.length === 0) return;

    const commitStart = Date.now();
    const pageId = this.container.pageId;

    const optimizedOps: (MutationOp | null)[] = [];
    const lastUpdateIndexById = new Map<string, number>();

    for (const op of this.mutationQueue) {
      if (op.type === 1) {
        const key = String(op.id);
        const prevIndex = lastUpdateIndexById.get(key);
        if (prevIndex !== undefined) {
          optimizedOps[prevIndex] = null;
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
    console.log(
          `[JS Performance] commit(patchOps) page=${pageId} `,
        );
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
    this.enqueueBoundaryRefresh(host);
  }
}
