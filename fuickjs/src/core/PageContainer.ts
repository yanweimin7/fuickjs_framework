import React from 'react';
import { Node, TEXT_TYPE } from './node';
import { IncrementalStrategy } from '../strategies/IncrementalStrategy';
import { DiffStrategy } from '../strategies/DiffStrategy';

export class PageContainer {
  pageId: number;
  root: Node | null = null;
  incrementalMode: boolean = true;
  dslCacheEnabled: boolean = true;

  public incrementalStrategy: IncrementalStrategy;
  public diffStrategy: DiffStrategy;

  // 优化：使用二维 Map 避免字符串拼接
  // 外层 Map 的 key 是 nodeId，内层 Map 的 key 是 eventKey
  private eventCallbacks: Map<number | string, Map<string, (...args: unknown[]) => unknown>> = new Map();
  private onVisibleCallbacks: Set<(...args: unknown[]) => unknown> = new Set();
  private onInvisibleCallbacks: Set<(...args: unknown[]) => unknown> = new Set();
  private nodes: Map<number | string, Node> = new Map();
  private nodesByRefId: Map<string, Node> = new Map();
  private _nextNodeId: number = 0;
  private _elementToDslIdCounter: number = 100000000;

  public get nextNodeId(): number {
    return this._nextNodeId;
  }
  public set nextNodeId(val: number) {
    this._nextNodeId = val;
  }

  public get elementToDslIdCounter(): number {
    return this._elementToDslIdCounter;
  }
  public set elementToDslIdCounter(val: number) {
    this._elementToDslIdCounter = val;
  }

  private isVisible: boolean = false;

  constructor(pageId: number) {
    this.pageId = pageId;
    this.incrementalStrategy = new IncrementalStrategy(this);
    this.diffStrategy = new DiffStrategy(this);
  }

  public registerNode(node: Node) {
    this.nodes.set(node.id, node);
    if (node.props?.refId) {
      this.nodesByRefId.set(String(node.props.refId), node);
    }
  }

  public unregisterNode(node: Node) {
    this.nodes.delete(node.id);
    if (node.props?.refId) {
      this.nodesByRefId.delete(String(node.props.refId));
    }
  }

  public getNodeByRefId(refId: string): Node | undefined {
    return this.nodesByRefId.get(refId);
  }

  public registerCallback(nodeId: number | string, eventKey: string, fn: (...args: unknown[]) => unknown) {
    let nodeCallbacks = this.eventCallbacks.get(nodeId);
    if (!nodeCallbacks) {
      nodeCallbacks = new Map();
      this.eventCallbacks.set(nodeId, nodeCallbacks);
    }
    nodeCallbacks.set(eventKey, fn);
  }

  public unregisterCallback(nodeId: number | string, eventKey: string) {
    const nodeCallbacks = this.eventCallbacks.get(nodeId);
    if (nodeCallbacks) {
      nodeCallbacks.delete(eventKey);
      // 如果该节点没有回调了，移除整个节点条目
      if (nodeCallbacks.size === 0) {
        this.eventCallbacks.delete(nodeId);
      }
    }
  }

  public getCallback(nodeId: number | string, eventKey: string): ((...args: unknown[]) => unknown) | undefined {
    return this.eventCallbacks.get(nodeId)?.get(eventKey);
  }

  /**
   * 清除指定节点的所有回调（用于节点销毁时）
   */
  public clearNodeCallbacks(nodeId: number | string) {
    this.eventCallbacks.delete(nodeId);
  }

  public registerVisibleCallback(fn: (...args: unknown[]) => unknown) {
    this.onVisibleCallbacks.add(fn);
    if (this.isVisible) {
      try {
        fn();
      } catch (e) {
        console.error(`Error in onVisible callback (immediate) for page ${this.pageId}:`, e);
      }
    }
  }

  public unregisterVisibleCallback(fn: (...args: unknown[]) => unknown) {
    this.onVisibleCallbacks.delete(fn);
  }

  public registerInvisibleCallback(fn: (...args: unknown[]) => unknown) {
    this.onInvisibleCallbacks.add(fn);
  }

  public unregisterInvisibleCallback(fn: (...args: unknown[]) => unknown) {
    this.onInvisibleCallbacks.delete(fn);
  }

  public notifyVisible() {
    this.isVisible = true;
    this.onVisibleCallbacks.forEach((fn) => {
      try {
        fn();
      } catch (e) {
        console.error(`Error in onVisible callback for page ${this.pageId}:`, e);
      }
    });
  }

  public notifyInvisible() {
    this.isVisible = false;
    this.onInvisibleCallbacks.forEach((fn) => {
      try {
        fn();
      } catch (e) {
        console.error(`Error in onInvisible callback for page ${this.pageId}:`, e);
      }
    });
  }

  public setIncrementalMode(enabled: boolean) {
    this.incrementalMode = enabled;
  }

  public setDslCacheEnabled(enabled: boolean) {
    this.dslCacheEnabled = enabled;
  }

  public recordUpdate(node: Node, updatePayload: unknown[]) {
    if (this.incrementalMode) {
      this.incrementalStrategy.recordUpdate(node, updatePayload);
    } else {
      this.diffStrategy.markChanged(node);
    }
  }

  public recordInsert(parent: Node, child: Node, index: number) {
    if (this.incrementalMode) {
      this.incrementalStrategy.recordInsert(parent, child, index);
    } else {
      this.diffStrategy.markChanged(parent);
    }
  }

  public recordRemoval(parent: Node, child: Node) {
    if (this.incrementalMode) {
      this.incrementalStrategy.recordRemoval(parent, child);
    } else {
      this.diffStrategy.markChanged(parent);
    }
  }

  public markChanged(node: Node | null) {
    this.diffStrategy.markChanged(node);
  }

  createInstance(type: string, props: unknown): Node {
    const node = new Node(type, props as Record<string, unknown>, this);
    this.markChanged(node);
    return node;
  }

  createTextInstance(text: string): Node {
    const node = new Node(TEXT_TYPE, { text }, this);
    this.markChanged(node);
    return node;
  }

  appendChild(parent: Node, child: Node) {
    // If child already has a parent, remove it first (handle moves)
    if (child.parent) {
      const oldIndex = child.parent.children.indexOf(child);
      if (oldIndex >= 0) {
        child.parent.children.splice(oldIndex, 1);
        child.parent.invalidateDslCache(); // Invalidate old parent cache
        if (this.incrementalMode) {
          this.recordRemoval(child.parent, child);
        } else {
          this.markChanged(child.parent);
        }
      }
    } else {
      // Even if it doesn't have a parent, it might already be in this parent's children
      // due to appendInitialChild or other reasons.
      const oldIndex = parent.children.indexOf(child);
      if (oldIndex >= 0) {
        parent.children.splice(oldIndex, 1);
      }
    }

    child.parent = parent;
    parent.children.push(child);
    parent.invalidateDslCache(); // Invalidate new parent cache

    if (this.incrementalMode) {
      this.recordInsert(parent, child, parent.children.length - 1);
    } else {
      this.markChanged(parent);
    }
  }

  insertBefore(parent: Node, child: Node, beforeChild: Node) {
    // If child already has a parent, remove it first (handle moves)
    if (child.parent) {
      const oldIndex = child.parent.children.indexOf(child);
      if (oldIndex >= 0) {
        child.parent.children.splice(oldIndex, 1);
        child.parent.invalidateDslCache(); // Invalidate old parent cache
        // If it's the same parent, we will mark it changed later with the new insertion
        if (child.parent !== parent) {
          if (this.incrementalMode) {
            this.recordRemoval(child.parent, child);
          } else {
            this.markChanged(child.parent);
          }
        } else {
          // Same parent move. In incremental mode, we still need REMOVE + INSERT?
          // Or just INSERT (if simplified)?
          // Usually move = remove + insert.
          if (this.incrementalMode) {
            this.recordRemoval(parent, child);
          }
        }
      }
    } else {
      // Ensure it's not already in the target parent's children
      const oldIndex = parent.children.indexOf(child);
      if (oldIndex >= 0) {
        parent.children.splice(oldIndex, 1);
      }
    }

    child.parent = parent;
    const i = parent.children.indexOf(beforeChild);
    if (i >= 0) {
      parent.children.splice(i, 0, child);
    } else {
      parent.children.push(child);
    }
    parent.invalidateDslCache(); // Invalidate parent cache

    if (this.incrementalMode) {
      // If i is -1, it was pushed, index is length-1
      const newIndex = i >= 0 ? i : parent.children.length - 1;
      this.recordInsert(parent, child, newIndex);
    } else {
      this.markChanged(parent);
    }
  }

  removeChild(parent: Node, child: Node) {
    const i = parent.children.indexOf(child);
    if (i >= 0) parent.children.splice(i, 1);
    parent.invalidateDslCache(); // Invalidate parent cache
    child.destroy();

    if (this.incrementalMode) {
      this.recordRemoval(parent, child);
    } else {
      this.markChanged(parent);
    }
  }

  appendChildToContainer(child: Node) {
    this.root = child;
    this.markChanged(child);
    // Force a full render since the root has changed.
    // This ensures that even in incremental mode, the new root is sent to Flutter via renderUI.
    this.diffStrategy.rendered = false;
  }

  removeChildFromContainer(child: Node) {
    if (this.root === child) {
      this.root = null;
    }
    child.destroy();
  }

  commitTextUpdate(node: Node, text: string) {
    const oldText = node.props.text;
    const newText = String(text);
    if (oldText === newText) return;

    node.props.text = newText;
    node.invalidateDslCache(); // Ensure DSL cache is invalidated

    if (this.incrementalMode) {
      this.recordUpdate(node, ['text', newText]);
    } else {
      this.markChanged(node);
    }
  }

  public commit() {
    try {
      if (!this.diffStrategy.rendered) {
        this.diffStrategy.commit();
      } else if (this.incrementalMode) {
        this.incrementalStrategy.commit();
      } else {
        this.diffStrategy.commit();
      }
    } catch (e) {
      console.error(`[PageContainer] Error during commit for page ${this.pageId}:`, e);
    } finally {
      this.clear();
    }
  }

  public getItemDSL(refId: string, index: number): unknown {
    const node = this.getNodeByRefId(refId);
    if (!node) {
      return null;
    }

    const itemBuilder = (node.props as Record<string, unknown>)?.itemBuilder;
    if (typeof itemBuilder !== 'function') {
      return null;
    }

    try {
      const element = (itemBuilder as (index: number) => React.ReactNode)(index);
      const dsl = this.elementToDsl(element);
      return dsl;
    } catch (e) {
      console.error(`[PageContainer] Error in itemBuilder for refId ${refId} at index ${index}:`, e);
      return null;
    }
  }

  public static readonly MAX_ELEMENT_DEPTH = 512;

  public elementToDsl(element: React.ReactNode, depth: number = 0): unknown {
    if (!element) return null;
    if (depth > PageContainer.MAX_ELEMENT_DEPTH) {
      console.warn(
        `[PageContainer] elementToDsl depth exceeded ${PageContainer.MAX_ELEMENT_DEPTH} on page ${this.pageId}; truncating`,
      );
      return null;
    }

    let currentElement: React.ReactNode = element;

    while (true) {
      if (!currentElement) return null;

      if (typeof currentElement === 'string' || typeof currentElement === 'number') {
        return { type: 'Text', props: { text: String(currentElement) } };
      }

      if (Array.isArray(currentElement)) {
        return currentElement.map((e) => this.elementToDsl(e, depth + 1)).filter((e) => e !== null);
      }

      const elAny = currentElement as unknown as Record<string, unknown>;

      if (elAny.type) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        let type: any = elAny.type;
        const originalProps = (elAny.props as Record<string, unknown>) || {};

        // Handle React.memo and React.forwardRef (can be nested)
        while (typeof type === 'object' && type !== null && (type as { type: unknown }).type) {
          type = (type as { type: unknown }).type;
        }

        if (typeof type === 'function') {
          // Handle class components
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          if ((type as any).prototype && (type as any).prototype.isReactComponent) {
            const instance = new (type as new (props: unknown) => React.Component)(originalProps);
            instance.context = { pageId: this.pageId };

            // Support refs in elementToDsl (important for itemBuilder)
            if (elAny.ref) {
              if (typeof elAny.ref === 'function') {
                (elAny.ref as (instance: unknown) => void)(instance);
              } else if (typeof elAny.ref === 'object' && elAny.ref !== null) {
                (elAny.ref as React.MutableRefObject<unknown>).current = instance;
              }
            }

            currentElement = instance.render();
            continue;
          }
          // Handle functional components
          currentElement = (type as (props: unknown) => React.ReactNode)(originalProps);
          continue;
        }

        // It's a primitive (string) type
        const { children, ...props } = originalProps;

        // Ensure we have a nodeId for event mapping (always use framework-generated id)
        const nodeId = ++this.elementToDslIdCounter;

        // Process props using the common logic
        const processedProps = this.processProps(nodeId, props, String(type), [], depth + 1);

        const dslChildren: unknown[] = [];
        const childrenToProcess = Array.isArray(children) ? children : children ? [children] : [];

        for (const child of childrenToProcess) {
          const childDsl = this.elementToDsl(child, depth + 1);
          if (childDsl) {
            if (Array.isArray(childDsl)) {
              for (const item of childDsl) {
                this.processDslChild(processedProps as Record<string, unknown>, dslChildren, item);
              }
            } else {
              this.processDslChild(processedProps as Record<string, unknown>, dslChildren, childDsl);
            }
          }
        }

        const result: Record<string, unknown> = {
          id: nodeId,
          type: String(type),
          props: processedProps,
          children: dslChildren,
        };

        if (props.refId) {
          const rawRefId = String(props.refId);
          result.refId = rawRefId.indexOf(':') !== -1 ? rawRefId : `${this.pageId}:${rawRefId}`;
        }

        if (props.isBoundary) {
          result.isBoundary = true;
        }

        return result;
      }
      return null;
    }
  }

  private processDslChild(processedProps: Record<string, unknown>, dslChildren: unknown[], childDsl: unknown) {
    const child = childDsl as Record<string, unknown>;
    if (child.type === 'FlutterProps' || child.type === 'flutter-props') {
      const propsKey = (child.props as Record<string, unknown>)?.propsKey as string;
      if (propsKey) {
        const propChildren = (child.children as unknown[]) || [];
        if (propChildren.length > 0) {
          const newValue = propChildren.length === 1 ? propChildren[0] : propChildren;
          if (processedProps[propsKey]) {
            if (Array.isArray(processedProps[propsKey])) {
              (processedProps[propsKey] as unknown[]).push(newValue);
            } else {
              processedProps[propsKey] = [processedProps[propsKey], newValue];
            }
          } else {
            processedProps[propsKey] = newValue;
          }
        }
      }
    } else {
      dslChildren.push(child);
    }
  }

  /**
   * 递归处理组件属性，将 React/JS 特有的属性转换为 Flutter 可识别的 DSL 格式
   *
   * 处理逻辑包括：
   * 1. 识别并转换函数回调为 Flutter 事件对象 (isFuickEvent)
   * 2. 递归处理嵌套的对象和数组
   * 3. 过滤掉 React 内部使用的私有属性
   * 4. 处理嵌套的 React 元素 (Element to DSL)
   *
   * @param nodeId 当前属性所属节点的 ID，用于事件回调定位
   * @param props 原始属性对象
   * @param nodeType 节点类型 (如 'ListView', 'Text')，用于特殊逻辑处理
   * @param path 当前处理的属性路径 (如 'decoration.color')，用于生成唯一的事件 key
   * @returns 处理后的 DSL 属性对象
   */
  processProps(
    nodeId: number,
    props: unknown,
    nodeType?: string,
    path: (string | number)[] = [],
    depth: number = 0,
  ): unknown {
    // Case 1: 基础类型或空值直接返回
    if (!props || typeof props !== 'object') return props;

    // Case 2: 如果属性值是一个 React 元素，将其转换为 DSL 结构
    // 例如：AppBar 的 title 属性传入了一个 <Text> 组件
    if (React.isValidElement(props)) return this.elementToDsl(props, depth + 1);

    // Case 3: 处理数组，递归转换数组中的每个元素
    if (Array.isArray(props)) {
      return props.map((item, index) => {
        const newPath = [...path, index];
        return this.processProps(nodeId, item, nodeType, newPath, depth + 1);
      });
    }

    const processedProps: Record<string, unknown> = {};
    const propsObj = props as Record<string, unknown>;

    for (const key in propsObj) {
      // Case 4: 过滤 React 内部属性
      // children 已在 elementToDsl 中单独处理，key/ref/isBoundary 仅在 JS 层使用，不传递给 Flutter
      if (path.length === 0 && (key === 'children' || key === 'key' || key === 'ref' || key === 'isBoundary')) continue;

      // Case 5: 列表类组件的 itemBuilder 特殊处理
      // itemBuilder 是按需调用的数据源，不是普通点击事件，不应被转换为 Flutter Event 对象。
      // 它会在 Flutter 侧通过 getItemDSL 接口反向调用 JS 来获取每一项的 DSL。
      if (key === 'itemBuilder') {
        continue;
      }

      const value = propsObj[key];

      if (typeof value === 'function') {
        // Case 6: 处理函数回调
        // 仅在需要注册回调时才构建完整的 path 字符串，避免不必要的字符串拼接开销
        const fullKey = this.buildPath(path, key);

        // 将 JS 函数注册到 PageContainer，并返回一个 Flutter 可识别的事件协议对象
        this.registerCallback(nodeId, fullKey, value as (...args: unknown[]) => unknown);

        // 构造 Flutter 侧解析的事件描述对象
        processedProps[key] = {
          id: Number(nodeId), // 节点 ID
          nodeId: Number(nodeId), // 节点 ID (兼容性保留)
          eventKey: String(fullKey), // 唯一的事件标识符 (包含路径)
          pageId: Number(this.pageId), // 页面 ID
          isFuickEvent: true, // 标识这是一个需要 JS 回调的事件
        };
      } else if (value && typeof value === 'object') {
        // Case 7: 递归处理嵌套对象
        // 例如：decoration: { color: '#ff0000', border: { ... } }
        const newPath = [...path, key];
        processedProps[key] = this.processProps(nodeId, value, nodeType, newPath, depth + 1);
      } else {
        // Case 8: 基础数据类型 (string, number, boolean) 直接赋值
        processedProps[key] = value;
      }
    }
    return processedProps;
  }

  private buildPath(path: (string | number)[], key: string): string {
    if (path.length === 0) return key;
    let result = '';
    for (const segment of path) {
      if (typeof segment === 'number') {
        result += `[${segment}]`;
      } else {
        result += result ? `.${segment}` : segment;
      }
    }
    return result + (result ? `.${key}` : key);
  }

  clear() {
    this.diffStrategy.clear();
    this.incrementalStrategy.clear();
  }
}
