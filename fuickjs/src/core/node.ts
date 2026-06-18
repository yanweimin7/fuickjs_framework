import React from 'react';
import { PageContainer } from './PageContainer';

export const TEXT_TYPE = 'Text';

// 已是绝对/网络/内联资源的 src，无需改写。
const ABSOLUTE_ASSET_RE = /^(https?:\/\/|file:\/\/|data:|\/)/i;

/**
 * 将 bundle 内相对图片路径透明解析为 file://<root>/assets/<src>。
 * - 业务照写相对路径（如 "images/logo.png"），无需任何 API。
 * - 无动态包（root 缺失）时原样返回，由 Flutter 走 Image.asset 兜底。
 * 数据源：引擎在 eval 前注入的 globalThis.__FUICK_BUNDLE__ = { name, root }。
 */
function resolveBundleAssetPath(src: unknown): unknown {
  if (typeof src !== 'string' || src.length === 0) return src;
  if (ABSOLUTE_ASSET_RE.test(src)) return src;
  const bundle = (globalThis as unknown as { __FUICK_BUNDLE__?: { root?: unknown } }).__FUICK_BUNDLE__;
  const root = bundle && bundle.root;
  if (!root || typeof root !== 'string') return src;
  const rel = src.replace(/^\.?\//, '');
  return `file://${root}/assets/${rel}`;
}

const IMAGE_ASSET_PROP_KEYS = ['src', 'url', 'errorSrc', 'errorUrl'];

export class Node {
  id: number;
  type: string;
  props: Record<string, unknown>;
  children: Node[] = [];
  parent?: Node;
  container?: PageContainer;
  private eventKeys: Set<string> = new Set();

  // DSL 缓存优化
  private _dslCache: unknown = null;
  private _dslCacheDirty: boolean = true;
  private _childrenDslCacheDirty: boolean = true;

  constructor(type: string, props: Record<string, unknown> | null, container?: PageContainer) {
    // Use container's nextNodeId to ensure unified id space
    this.id = container ? ++container.nextNodeId : 1;
    this.type = type;
    this.props = {}; // Initialize empty props
    this.container = container;
    this.container?.registerNode(this);
    this.applyProps(props);
  }

  /**
   * 应用新 props。
   * @param hasDslChanges 本次更新是否包含影响 DSL 的变更。默认 true（首次挂载/结构变更）。
   *   当仅有回调函数引用变化时（hostConfig.diffProps 判定 hasDslChanges=false），
   *   DSL 序列化结果不变——事件在 DSL 中表示为 { nodeId, eventKey, ... } 协议对象，
   *   不内嵌函数体，调用时按 (nodeId, eventKey) 在回调表中查找。
   *   因此此时无需失效 DSL 缓存，仅需照常重注册回调。
   */
  applyProps(newProps: Record<string, unknown> | null, hasDslChanges = true) {
    const oldRefId = this.props?.refId;
    if (oldRefId && typeof oldRefId === 'string') {
      this.container?.unregisterNode(this);
    }

    this.clearCallbacks();
    this.props = {};

    if (newProps) {
      const propKeys = Object.keys(newProps);
      for (const key of propKeys) {
        if (key === 'children') continue;
        const value = newProps[key];
        this.props[key] = value;
      }

      if (!this.container?.isFirstRender) {
        this.registerCallbacksRecursive(newProps);
      }
    }

    this.container?.registerNode(this);

    if (hasDslChanges) {
      this._dslCacheDirty = true;
      this._invalidateParentDslCache();
    }
  }

  private _isTransparent(): boolean {
    return this.type === 'FlutterProps' || this.type === 'flutter-props';
  }

  /**
   * 递归向上通知父节点 DSL 缓存失效
   */
  private _invalidateParentDslCache() {
    let current = this.parent;
    while (current) {
      const wasDirty = current._childrenDslCacheDirty;
      current._childrenDslCacheDirty = true;

      // 如果父节点是透明节点（如 FlutterProps），由于它的 toDsl 不会被直接调用（从而无法清除 dirty 标记），
      // 我们必须强制继续向上传递失效信号，直到到达一个真正的 Widget 节点。
      if (!wasDirty || current._isTransparent()) {
        current = current.parent;
      } else {
        // 父节点已经被标记，且不是透明节点，可以停止向上传播
        break;
      }
    }
  }

  /**
   * 标记当前节点 DSL 缓存失效（供外部调用）
   */
  invalidateDslCache() {
    this._dslCacheDirty = true;
    this._invalidateParentDslCache();
  }

  registerCallbacksRecursive(obj: unknown, initialPath: string = '') {
    const stack: { obj: unknown; path: string }[] = [{ obj, path: initialPath }];

    while (stack.length > 0) {
      const { obj: currentObj, path: currentPath } = stack.pop()!;

      if (!currentObj || typeof currentObj !== 'object') continue;

      // Check for React Element using React.isValidElement
      if (React.isValidElement(currentObj)) continue;

      if (Array.isArray(currentObj)) {
        for (let i = currentObj.length - 1; i >= 0; i--) {
          stack.push({
            obj: currentObj[i],
            path: currentPath ? `${currentPath}[${i}]` : `[${i}]`,
          });
        }
        continue;
      }

      const objRecord = currentObj as Record<string, unknown>;
      for (const key in objRecord) {
        if (currentPath === '' && (key === 'children' || key === 'key' || key === 'ref' || key === 'isBoundary'))
          continue;

        // Skip itemBuilder for ListView-like components
        if (key === 'itemBuilder') continue;

        const value = objRecord[key];
        const fullKey = currentPath ? `${currentPath}.${key}` : key;

        if (typeof value === 'function') {
          this.saveCallback(fullKey, value as (...args: unknown[]) => unknown);
        } else if (value && typeof value === 'object') {
          stack.push({ obj: value, path: fullKey });
        }
      }
    }
  }

  saveCallback(key: string, fn: (...args: unknown[]) => unknown) {
    this.eventKeys.add(key);
    this.container?.registerCallback(this.id, key, fn);
  }

  clearCallbacks() {
    // 优化：使用批量清除方法，避免逐个删除
    if (this.container && this.eventKeys.size > 0) {
      this.container.clearNodeCallbacks(this.id);
    }
    this.eventKeys.clear();
  }

  getCallback(key: string): ((...args: unknown[]) => unknown) | undefined {
    return this.container?.getCallback(this.id, key);
  }

  toDsl(): unknown {
    const dslCacheEnabled = this.container ? this.container.dslCacheEnabled : true;

    // 如果自身缓存有效且子树无变化，直接返回缓存
    if (dslCacheEnabled && !this._dslCacheDirty && !this._childrenDslCacheDirty && this._dslCache !== null) {
      return this._dslCache;
    }

    const type = this.type;
    if (!type) return null;

    const props = (this.container ? this.container.processProps(this.id, this.props, type) : {}) as Record<
      string,
      unknown
    >;

    // Image 资源相对路径 → 动态包绝对路径（透明，业务无感）。
    if (type === 'Image') {
      for (const k of IMAGE_ASSET_PROP_KEYS) {
        if (props[k] !== undefined) {
          props[k] = resolveBundleAssetPath(props[k]);
        }
      }
    }

    // Use refId from props if provided
    const refId = this.props?.refId;

    // Children are handled separately
    const children: unknown[] = [];
    for (const child of this.children) {
      if (child.type === 'FlutterProps' || child.type === 'flutter-props') {
        const propsKey = child.props?.propsKey as string;
        if (propsKey) {
          const propChildren = child.children.map((c) => c.toDsl()).filter((c) => c !== null);

          if (propChildren.length > 0) {
            const newValue = propChildren.length === 1 ? propChildren[0] : propChildren;
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
        const dslChild = child.toDsl();
        if (dslChild) {
          children.push(dslChild);
        }
      }
    }

    const result: Record<string, unknown> = {
      id: this.id,
      type: String(type),
      props: props,
      children: children,
    };

    if (refId) {
      const rawRefId = String(refId);
      const pageId = this.container?.pageId || 0;
      result.refId = rawRefId.indexOf(':') !== -1 ? rawRefId : `${pageId}:${rawRefId}`;
    }

    if (this.props?.isBoundary) {
      result.isBoundary = true;
    }

    // 更新缓存
    this._dslCache = result;
    this._dslCacheDirty = false;
    this._childrenDslCacheDirty = false;

    return result;
  }

  destroy() {
    const stack: Node[] = [this];
    while (stack.length > 0) {
      const node = stack.pop()!;
      node.clearCallbacks();
      node.container?.unregisterNode(node);

      // 清理 DSL 缓存
      node._dslCache = null;
      node._dslCacheDirty = true;
      node._childrenDslCacheDirty = true;

      // Add children to stack in reverse order to maintain original destruction order if needed
      for (let i = node.children.length - 1; i >= 0; i--) {
        stack.push(node.children[i]);
      }
      // Clear children array to help GC and prevent double destruction
      node.children = [];
      // 断开反向链，防止 parent/container 持有已销毁节点引用阻止整树 GC。
      node.parent = undefined;
      node.container = undefined;
    }
  }
}
