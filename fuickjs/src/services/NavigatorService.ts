import React from 'react';
import ComponentStore from '../store/ComponentStore';
import { getConfig } from '../router/router';
import { getRuntimeConfig } from '../runtime/runtime';

export class NavigatorService {
  static async push(
    path: string,
    params: unknown,
    pageId?: number | null,
    rootNavigator?: boolean,
    prewarmMs?: number,
  ): Promise<unknown> {
    const routeConfig = getConfig(path);
    const runtimeConfig = getRuntimeConfig();
    let effectivePrewarmMs = prewarmMs ?? routeConfig?.prewarmMs;
    if (!runtimeConfig.prewarm) {
      effectivePrewarmMs = undefined;
    } else {
      if (!effectivePrewarmMs) {
        effectivePrewarmMs = runtimeConfig.prewarmMs;
      }
    }
    return dartCallNativeAsync('Navigator.push', {
      path,
      params,
      pageId,
      rootNavigator,
      prewarmMs: effectivePrewarmMs,
    });
  }

  static pushReplace(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return dartCallNativeAsync('Navigator.pushReplace', { path, params, pageId, rootNavigator });
  }

  static showDialog(
    component: React.ReactNode,
    params?: unknown,
    pageId?: number | null,
    rootNavigator?: boolean,
  ): Promise<unknown> {
    const id = ComponentStore.getInstance().register(component);
    const finalParams = {
      ...((params as object) || {}),
      componentId: id,
      presentation: 'dialog',
    };
    return NavigatorService.push('/_generic_dialog', finalParams, pageId, rootNavigator);
  }

  static showBottomSheet(
    component: React.ReactNode,
    options?: { minHeight?: number; maxHeight?: number; backgroundColor?: string },
    pageId?: number | null,
    rootNavigator?: boolean,
  ): Promise<unknown> {
    const id = ComponentStore.getInstance().register(component);
    const finalParams = {
      componentId: id,
      presentation: 'bottomSheet',
      minHeight: options?.minHeight,
      maxHeight: options?.maxHeight,
      backgroundColor: options?.backgroundColor,
    };
    return NavigatorService.push('/_generic_dialog', finalParams, pageId, rootNavigator);
  }

  static pop(pageId?: number | null, rootNavigator?: boolean, result?: unknown) {
    // worker isolate 中 NavigationService 不在白名单, 必须 async。
    // 这里 fire-and-forget 即可, 不阻塞业务。
    void dartCallNativeAsync('Navigator.pop', { pageId, rootNavigator, result });
  }

  static popTo(name: string, pageId?: number | null) {
    void dartCallNativeAsync('Navigator.popTo', { name, pageId });
  }

  static popAll(pageId?: number | null) {
    void dartCallNativeAsync('Navigator.popAll', { pageId });
  }

  static prewarm(path: string, params: unknown, pageId?: number | null, prewarmMs = 50): void {
    NavigatorService.prewarmAndWait(path, params, pageId, prewarmMs).catch(() => {});
  }

  static prewarmAndWait(path: string, params: unknown, pageId?: number | null, prewarmMs = 50): Promise<unknown> {
    return dartCallNativeAsync('Navigator.prewarm', { path, params, pageId, prewarmMs });
  }

  static cancelPrewarm(path: string): void {
    void dartCallNativeAsync('Navigator.cancelPrewarm', { path });
  }
}
