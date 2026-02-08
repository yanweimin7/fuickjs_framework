import React from 'react';
import ComponentStore from './ComponentStore';

export class NavigatorService {
  static push(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return dartCallNative('Navigator.push', { path, params, pageId, rootNavigator });
  }

  static pushReplace(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return dartCallNative('Navigator.pushReplace', { path, params, pageId, rootNavigator });
  }

  static showModal(path: string, params: unknown, options?: { minHeight?: number, maxHeight?: number }, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    const finalParams = {
      ...(params as object || {}),
      presentation: 'bottomSheet',
      minHeight: options?.minHeight,
      maxHeight: options?.maxHeight,
    };
    return this.push(path, finalParams, pageId, rootNavigator);
  }

  static showDialog(pathOrComponent: string | React.ReactNode, params?: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    if (React.isValidElement(pathOrComponent) || typeof pathOrComponent !== 'string') {
      return this.showComponentDialog('/_generic_dialog', pathOrComponent as React.ReactNode, params, pageId, rootNavigator);
    }
    const finalParams = {
      ...(params as object || {}),
      presentation: 'dialog',
    };
    return this.push(pathOrComponent as string, finalParams, pageId, rootNavigator);
  }

  static showComponentDialog(path: string, component: React.ReactNode, params?: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    const id = ComponentStore.getInstance().register(component);
    const finalParams = {
      ...(params as object || {}),
      componentId: id,
      presentation: 'dialog',
    };
    return this.push(path, finalParams, pageId, rootNavigator);
  }

  static pop(pageId?: number | null, rootNavigator?: boolean, result?: unknown) {
    dartCallNative('Navigator.pop', { pageId, rootNavigator, result });
  }
}
