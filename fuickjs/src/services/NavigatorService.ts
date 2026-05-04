import React from 'react';
import ComponentStore from '../store/ComponentStore';
import { getConfig } from '../router/router';

export class NavigatorService {
  static async push(
    path: string,
    params: unknown,
    pageId?: number | null,
    rootNavigator?: boolean,
    prewarmMs?: number,
  ): Promise<unknown> {
    const effectivePrewarmMs = prewarmMs ?? getConfig(path)?.prewarmMs;
    return dartCallNativeAsync('Navigator.push', {
      path,
      params,
      pageId,
      rootNavigator,
      prewarmMs: effectivePrewarmMs,
    });
  }

  static pushReplace(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return dartCallNative('Navigator.pushReplace', { path, params, pageId, rootNavigator });
  }

  static showDialog(component: React.ReactNode, params?: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    const id = ComponentStore.getInstance().register(component);
    const finalParams = {
      ...(params as object || {}),
      componentId: id,
      presentation: 'dialog',
    };
    return NavigatorService.push('/_generic_dialog', finalParams, pageId, rootNavigator);
  }

  static showBottomSheet(component: React.ReactNode, options?: { minHeight?: number; maxHeight?: number; backgroundColor?: string }, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
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
    dartCallNative('Navigator.pop', { pageId, rootNavigator, result });
  }

  static prewarm(path: string, params: unknown, pageId?: number | null, prewarmMs = 50): void {
    NavigatorService.prewarmAndWait(path, params, pageId, prewarmMs).catch(() => {});
  }

  static prewarmAndWait(path: string, params: unknown, pageId?: number | null, prewarmMs = 50): Promise<unknown> {
    return dartCallNativeAsync('Navigator.prewarm', { path, params, pageId, prewarmMs });
  }

  static cancelPrewarm(path: string): void {
    dartCallNative('Navigator.cancelPrewarm', { path });
  }
}
