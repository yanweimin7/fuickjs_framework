import React from 'react';
import { PageContainer } from './PageContainer';

export const TEXT_TYPE = 'Text';
let nextNodeId = 1;

export class Node {
  id: number;
  type: string;
  props: Record<string, unknown>;
  children: Node[] = [];
  parent?: Node;
  container?: PageContainer;
  private eventKeys: Set<string> = new Set();

  constructor(type: string, props: Record<string, unknown> | null, container?: PageContainer) {
    this.id = props && typeof props.id === 'number' ? props.id : nextNodeId++;
    this.type = type;
    this.props = {}; // Initialize empty props
    this.container = container;
    this.container?.registerNode(this);
    this.applyProps(props);
  }

  applyProps(newProps: Record<string, unknown> | null) {
    // Unregister old refId if it exists
    const oldRefId = this.props?.refId;
    if (oldRefId && typeof oldRefId === 'string') {
      this.container?.unregisterNode(this);
    }

    this.clearCallbacks();
    // Re-initialize props to ensure deleted props are removed
    this.props = {};

    if (newProps) {
      const propKeys = Object.keys(newProps);
      for (const key of propKeys) {
        if (key === 'children') continue;
        const value = newProps[key];
        this.props[key] = value;
      }
      // Recursively register callbacks to handle nested props and top-level callbacks
      this.registerCallbacksRecursive(newProps);
    }

    // Re-register with new refId
    this.container?.registerNode(this);
    // Note: We no longer call markChanged here.
    // It is the responsibility of hostConfig.commitUpdate to call markChanged if necessary.
    // This allows optimizations where we skip UI updates if only function references changed.
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
    if (this.container) {
      for (const key of this.eventKeys) {
        this.container.unregisterCallback(this.id, key);
      }
    }
    this.eventKeys.clear();
  }

  getCallback(key: string): ((...args: unknown[]) => unknown) | undefined {
    return this.container?.getCallback(this.id, key);
  }

  toDsl(): unknown {
    const type = this.type;
    if (!type) return null;

    // Strip 'flutter-' prefix and convert kebab-case to PascalCase for Flutter side recognition
    // if (type.startsWith('flutter-')) {
    //   type = type.substring(8)
    //     .split('-')
    //     .map(part => part.charAt(0).toUpperCase() + part.slice(1))
    //     .join('');
    // }

    const props = (this.container ? this.container.processProps(this.id, this.props, type) : {}) as Record<
      string,
      unknown
    >;

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

    return result;
  }

  destroy() {
    const stack: Node[] = [this];
    while (stack.length > 0) {
      const node = stack.pop()!;
      node.clearCallbacks();
      node.container?.unregisterNode(node);

      // Add children to stack in reverse order to maintain original destruction order if needed
      for (let i = node.children.length - 1; i >= 0; i--) {
        stack.push(node.children[i]);
      }
      // Clear children array to help GC and prevent double destruction
      node.children = [];
    }
  }
}
