import React from 'react';
import { PageContainer } from './PageContainer';
import { Node } from './node';
import { perfLog } from '../utils/log';

function deepEqual(objA: unknown, objB: unknown): boolean {
  if (objA === objB) return true;
  if (!objA || !objB || typeof objA !== 'object' || typeof objB !== 'object') return false;

  // Handle React elements - perform deep comparison
  if (React.isValidElement(objA) || React.isValidElement(objB)) {
    return false;
  }

  const recordA = objA as Record<string, unknown>;
  const recordB = objB as Record<string, unknown>;

  const keysA = Object.keys(recordA);
  const keysB = Object.keys(recordB);

  if (keysA.length !== keysB.length) return false;

  for (const key of keysA) {
    if (!Object.prototype.hasOwnProperty.call(recordB, key)) return false;

    const valA = recordA[key];
    const valB = recordB[key];

    // Recursively check for deep equality
    if (valA && valB && typeof valA === 'object' && typeof valB === 'object') {
      if (!deepEqual(valA, valB)) return false;
    } else if (valA !== valB) {
      return false;
    }
  }

  return true;
}

/**
 * 对比新旧属性，计算出更新 Payload 以及是否影响 DSL 布局。
 *
 * 核心逻辑：
 * 1. 只有属性值真正发生变化（浅比较或深度比较）时，才会被加入 payload，用于更新 JS 侧的 Node 属性。
 * 2. 引入 `hasDslChanges` 标记，用于区分“逻辑更新”和“UI更新”：
 *    - 如果只是回调函数（Function）的引用变化，虽然需要更新 JS 侧的事件注册表，但生成的 DSL（eventKey）是不变的，
 *      因此不需要通知 Flutter 重绘 UI（hasDslChanges = false）。
 *    - 如果是基础类型、React Element 或普通对象的实质性结构变化，则必须通知 Flutter 更新 UI（hasDslChanges = true）。
 */
function diffProps(
  oldProps: Record<string, unknown>,
  newProps: Record<string, unknown>,
): { payload: unknown[]; hasDslChanges: boolean } | null {
  const updatePayload: unknown[] = [];
  let hasChanges = false;
  let hasDslChanges = false;

  // 1. 遍历旧属性，检查是否有被删除或被修改的属性
  for (const key in oldProps) {
    if (key === 'children') continue; // children 单独处理，不在此处 diff

    // 情况 A: 属性被删除
    if (!(key in newProps)) {
      updatePayload.push(key, null);
      hasChanges = true;
      hasDslChanges = true; // 属性删除必然影响 DSL 结构
    }
    // 情况 B: 属性值引用发生变化
    else if (oldProps[key] !== newProps[key]) {
      const oldVal = oldProps[key];
      const newVal = newProps[key];

      // B1: 新旧值都是函数
      if (typeof oldVal === 'function' && typeof newVal === 'function') {
        // 函数引用变化需要更新 JS 侧的回调映射，但对于 DSL 来说，
        // eventKey (如 "onClick") 依然指向同一个 ID，因此不算作 DSL 变更。
        // 从而避免不必要的 Flutter UI 刷新。
        updatePayload.push(key, newVal);
        hasChanges = true;

        // Special Case: itemBuilder change implies data source change, must update UI
        if (key === 'itemBuilder') {
          hasDslChanges = true;
        }
      }
      // B2: 涉及 React Element (组件)
      else if (React.isValidElement(oldVal) || React.isValidElement(newVal)) {
        // 如果属性是 React 组件（如 title={<Text />}），只要引用变了，就直接视为 DSL 变更。
        // 为了性能，不做昂贵的深度递归比较 (Deep Compare)。
        updatePayload.push(key, newVal);
        hasChanges = true;
        hasDslChanges = true;
      }
      // B3: 普通对象或数组
      else if (oldVal && newVal && typeof oldVal === 'object' && typeof newVal === 'object') {
        // 先进行标准深度比较，确认内容是否真的变了
        if (!deepEqual(oldVal, newVal)) {
          updatePayload.push(key, newVal);
          hasChanges = true;

          // 如果内容变了，进一步检查是否仅仅是内部的函数引用变了？
          // isDslEqual 会忽略函数引用的差异。
          // 如果 isDslEqual 返回 false，说明有非函数的实质性数据变化，需要更新 UI。
          if (!isDslEqual(oldVal, newVal)) {
            hasDslChanges = true;
          }
        }
      }
      // B4: 基础数据类型 (String, Number, Boolean 等)
      else {
        updatePayload.push(key, newVal);
        hasChanges = true;
        hasDslChanges = true; // 基础类型变化必然影响 UI
      }
    }
  }

  // 2. 遍历新属性，检查是否有新增的属性
  for (const key in newProps) {
    if (key === 'children') continue;
    if (!(key in oldProps)) {
      updatePayload.push(key, newProps[key]);
      hasChanges = true;
      hasDslChanges = true; // 新增属性必然影响 DSL
    }
  }

  return hasChanges ? { payload: updatePayload, hasDslChanges } : null;
}

function isDslEqual(valA: unknown, valB: unknown): boolean {
  if (valA === valB) return true;

  // Treat functions as equal for DSL purposes (eventKey doesn't change if function ref changes)
  if (typeof valA === 'function' && typeof valB === 'function') return true;

  if (!valA || !valB || typeof valA !== 'object' || typeof valB !== 'object') return false;

  // React Element check
  if (React.isValidElement(valA) || React.isValidElement(valB)) {
    return false;
  }

  // Array check
  if (Array.isArray(valA) !== Array.isArray(valB)) return false;
  if (Array.isArray(valA) && Array.isArray(valB)) {
    if (valA.length !== valB.length) return false;
    for (let i = 0; i < valA.length; i++) {
      if (!isDslEqual(valA[i], valB[i])) return false;
    }
    return true;
  }

  const recordA = valA as Record<string, unknown>;
  const recordB = valB as Record<string, unknown>;

  // Object check
  const keysA = Object.keys(recordA);
  const keysB = Object.keys(recordB);
  if (keysA.length !== keysB.length) return false;

  for (const key of keysA) {
    if (!Object.prototype.hasOwnProperty.call(recordB, key)) return false;
    if (!isDslEqual(recordA[key], recordB[key])) return false;
  }

  return true;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const createHostConfig = (): any => {
  let currentUpdatePriority = 16; // DefaultEventPriority
  return {
    now: Date.now,
    supportsMutation: true,
    supportsPersistence: false,
    supportsMicrotasks: true,
    scheduleMicrotask: (callback: () => void) => {
      if (typeof queueMicrotask === 'function') {
        queueMicrotask(() => {
          callback();
        });
      } else {
        Promise.resolve().then(() => {
          callback();
        });
      }
    },
    scheduleTimeout: (handler: (...args: unknown[]) => void, timeout: number) => {
      return setTimeout(handler, timeout);
    },
    cancelTimeout: (handle: unknown) => {
      clearTimeout(handle as number);
    },
    noTimeout: -1,
    isPrimaryRenderer: true,
    // React 19: priority API renamed from getCurrentEventPriority
    getCurrentUpdatePriority: () => currentUpdatePriority,
    setCurrentUpdatePriority: (priority: number) => {
      currentUpdatePriority = priority;
    },
    resolveUpdatePriority: () => currentUpdatePriority,
    getInstanceFromNode: () => null,
    beforeActiveInstanceBlur: () => {},
    afterActiveInstanceBlur: () => {},
    prepareScopeUpdate: () => {},
    getInstanceFromScope: () => null,
    // React 19: portal mount hook
    preparePortalMount: () => {},
    // React 19: Transition support (no-op for custom renderer)
    NotPendingTransition: null,
    HostTransitionContext: {
      $$typeof: Symbol.for('react.context'),
      _currentValue: null,
      _currentValue2: null,
      _threadCount: 0,
      Consumer: null as unknown,
      Provider: null as unknown,
    },
    // React 19: Form action (no-op)
    resetFormInstance: () => {},
    // React 19: post-paint callback (no-op)
    requestPostPaintCallback: () => {},
    // React 19: eager transition hint (no-op)
    shouldAttemptEagerTransition: () => false,
    // React 19: scheduler tracing (no-op)
    trackSchedulerEvent: () => {},
    // React 19: event info (no-op)
    resolveEventType: () => null,
    resolveEventTimeStamp: () => -1,
    // React 19: Suspense commit hooks (no-op — this renderer doesn't suspend)
    maySuspendCommit: () => false,
    preloadInstance: () => true,
    startSuspendingCommit: () => {},
    suspendInstance: () => {},
    waitForCommitToBeReady: () => null,
    getPublicInstance: (inst: Node) => inst,
    getRootHostContext: (_root: PageContainer) => null,
    getChildHostContext: (_parentHostContext: unknown, _type: string, _root: PageContainer) => null,
    shouldSetTextContent: (_type: string, _props: Record<string, unknown>) => false,
    createInstance: (type: string, props: Record<string, unknown>, container: PageContainer) => {
      return container.createInstance(type, props);
    },
    createTextInstance: (text: string, container: PageContainer) => {
      return container.createTextInstance(text);
    },
    appendInitialChild: (parent: Node, child: Node) => {
      child.parent = parent;
      parent.children.push(child);
      parent.invalidateDslCache(); // Invalidate parent cache
      if (parent.container) {
        parent.container.markChanged(parent);
      }
    },
    finalizeInitialChildren: (
      _instance: Node,
      _type: string,
      _props: Record<string, unknown>,
      _rootContainer: PageContainer,
      _hostContext: unknown,
    ) => false,
    appendChildToContainer: (container: PageContainer, child: Node) => {
      container.appendChildToContainer(child);
    },
    appendChild: (parent: Node, child: Node) => {
      if (parent.container) {
        parent.container.appendChild(parent, child);
      } else {
        child.parent = parent;
        parent.children.push(child);
      }
    },
    insertBefore: (parent: Node, child: Node, beforeChild: Node) => {
      if (parent.container) {
        parent.container.insertBefore(parent, child, beforeChild);
      } else {
        child.parent = parent;
        const i = parent.children.indexOf(beforeChild);
        if (i >= 0) {
          parent.children.splice(i, 0, child);
        } else {
          parent.children.push(child);
        }
      }
    },
    removeChild: (parent: Node, child: Node) => {
      if (parent.container) {
        parent.container.removeChild(parent, child);
      } else {
        const i = parent.children.indexOf(child);
        if (i >= 0) parent.children.splice(i, 1);
        child.destroy();
      }
    },
    removeChildFromContainer: (container: PageContainer, child: Node) => {
      container.removeChildFromContainer(child);
    },
    insertInContainerBefore: (container: PageContainer, child: Node, _beforeChild: Node) => {
      container.appendChildToContainer(child);
    },
    resetTextContent: (_instance: Node) => {},
    detachDeletedInstance: (instance: Node) => {
      instance.destroy();
    },
    clearContainer: (container: PageContainer) => {
      container.root = null;
    },
    // React 19: prepareUpdate's return value (updatePayload) is no longer passed to
    // commitUpdate, so there is no benefit to diffing here. Always return a truthy
    // sentinel so React schedules commitUpdate, and do the real diff there once.
    prepareUpdate: () => true,
    commitUpdate: (
      instance: Node,
      _type: string,
      oldProps: Record<string, unknown>,
      newProps: Record<string, unknown>,
      _internalInstanceHandle: unknown,
    ) => {
      const result = diffProps(oldProps, newProps);
      if (!result) return;

      const { payload, hasDslChanges } = result;
      instance.applyProps(newProps, hasDslChanges);

      if (hasDslChanges && instance.container) {
        const container = instance.container;
        if (instance === container.root) {
          const changedKeys = payload.filter((_: unknown, i: number) => i % 2 === 0);
          perfLog(
            `[HostConfig] markChanged ROOT node=${instance.id} type=${instance.type} due to DSL changes in props: ${changedKeys.join(',')}`,
          );
        }

        if (typeof container.recordUpdate === 'function') {
          container.recordUpdate(instance, payload);
        } else {
          container.markChanged(instance);
        }
      }
    },
    commitTextUpdate: (textInstance: Node, _oldText: string, newText: string) => {
      textInstance.props.text = String(newText);
      if (textInstance.container) {
        textInstance.container.commitTextUpdate(textInstance, newText);
      }
    },
    resetAfterCommit: (container: PageContainer) => {
      container.commit();
    },
    prepareForCommit: (_container: PageContainer) => {},
    supportsHydration: false,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
};
