import React from 'react';
import ComponentStore from '../store/ComponentStore';
import * as Router from '../router/router';
import type { GuardResult, RouteConfig } from '../router/router';
import { isGuardRedirect, extractRedirectTarget } from '../router/router';
import { getRuntimeConfig } from '../runtime/runtime';
import { logDebug } from '../utils/log';

/** 安全执行守卫链，异常视为拒绝 */
async function runGuardsSafely(to: Router.RouteLocation, from: Router.RouteLocation | null): Promise<GuardResult> {
  try {
    return await Router.runGuards(to, from);
  } catch (e) {
    console.error('[Navigator] Guard error:', e);
    return false;
  }
}

/** 根据路由配置与 params 反向构造完整路径（用于命名路由跳转） */
function buildPath(route: RouteConfig, params: Record<string, unknown>): string {
  const parts = route.path.split('/').filter(Boolean);
  const result: string[] = [];
  for (const p of parts) {
    if (p.startsWith(':')) {
      const key = p.slice(1);
      result.push(encodeURIComponent(String(params[key] ?? '')));
    } else {
      result.push(p);
    }
  }
  return '/' + result.join('/');
}

export class NavigatorService {
  /**
   * 跳转到指定路径，等待目标页面 pop(result) 后返回。
   * 守卫拒绝时 resolve 为 null。
   * @param path    路径，支持参数占位 /news/:id 或完整路径 /news/123
   * @param params  调用方传入的参数，与路径参数合并后传给页面组件
   * @param pageId  发起跳转的页面 id（用于守卫的 from）
   * @param rootNavigator 是否使用根 Navigator
   * @param prewarmMs 预热时长
   */
  static async push(
    path: string,
    params: unknown,
    pageId?: number | null,
    rootNavigator?: boolean,
    prewarmMs?: number,
  ): Promise<unknown> {
    const from = pageId != null ? Router.getLocation(pageId) : null;
    const to = Router.resolve(path, params);
    if (!to) {
      // 未匹配 JS 路由：开启 nativeFallback 时交给 Native 侧（宿主路由）处理
      if (Router.isNativeFallbackEnabled()) {
        logDebug(`[Navigator] No JS route for ${path}, delegating to native`);
        return NavigatorService.pushRaw(path, params, pageId, true, prewarmMs);
      }
      console.warn(`[Navigator] No route matched for ${path}`);
      return null;
    }

    const guardResult = await runGuardsSafely(to, from);
    if (guardResult === false) return null;
    if (isGuardRedirect(guardResult)) {
      const target = extractRedirectTarget(guardResult);
      return NavigatorService.push(target.path, target.params ?? params, pageId, rootNavigator, prewarmMs);
    }

    return NavigatorService.pushRaw(path, to.params, pageId, rootNavigator, prewarmMs);
  }

  /**
   * pushAndWait 已在 push 中默认实现（push 本身就是等待 pop 返回）。
   * 保留此方法仅为向后兼容，等价于 push。
   * @deprecated 请直接使用 push。
   */
  static pushAndWait(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return NavigatorService.push(path, params, pageId, rootNavigator);
  }

  /**
   * 替换当前路由（不可返回）。同样跑守卫。
   */
  static async pushReplace(
    path: string,
    params: unknown,
    pageId?: number | null,
    rootNavigator?: boolean,
  ): Promise<unknown> {
    const from = pageId != null ? Router.getLocation(pageId) : null;
    const to = Router.resolve(path, params);
    if (!to) {
      // 未匹配 JS 路由：开启 nativeFallback 时交给 Native 侧（宿主路由）处理
      if (Router.isNativeFallbackEnabled()) {
        logDebug(`[Navigator] No JS route for ${path}, delegating to native`);
        return dartCallNativeAsync('Navigator.pushReplace', {
          path,
          params,
          pageId,
          rootNavigator: true,
        });
      }
      console.warn(`[Navigator] No route matched for ${path}`);
      return null;
    }

    const guardResult = await runGuardsSafely(to, from);
    if (guardResult === false) return null;
    if (isGuardRedirect(guardResult)) {
      const target = extractRedirectTarget(guardResult);
      return NavigatorService.pushReplace(target.path, target.params ?? params, pageId, rootNavigator);
    }

    return dartCallNativeAsync('Navigator.pushReplace', {
      path,
      params: to.params,
      pageId,
      rootNavigator,
    });
  }

  /** pushReplace 的语义化别名。 */
  static replace(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return NavigatorService.pushReplace(path, params, pageId, rootNavigator);
  }

  /** 重定向：替换当前路由且不可返回。与 replace 等价，语义用于守卫外部主动重定向。 */
  static redirect(path: string, params: unknown, pageId?: number | null, rootNavigator?: boolean): Promise<unknown> {
    return NavigatorService.pushReplace(path, params, pageId, rootNavigator);
  }

  /**
   * 通过命名路由跳转。根据路由配置的 path 模板与 params 反向构造完整路径。
   * @param name   路由配置中的 name 字段
   * @param params 路径参数（必填字段）+ 业务参数
   */
  static pushByName(
    name: string,
    params?: unknown,
    pageId?: number | null,
    rootNavigator?: boolean,
    prewarmMs?: number,
  ): Promise<unknown> {
    const route = Router.getRouteByName(name);
    if (!route) {
      console.warn(`[Navigator] No route named "${name}"`);
      return Promise.resolve(null);
    }
    const path = buildPath(route, (params as Record<string, unknown>) || {});
    return NavigatorService.push(path, params, pageId, rootNavigator, prewarmMs);
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
    // 弹窗走内部路由，不跑业务守卫
    return NavigatorService.pushRaw('/_generic_dialog', finalParams, pageId, rootNavigator);
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
    return NavigatorService.pushRaw('/_generic_dialog', finalParams, pageId, rootNavigator);
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

  /**
   * 内部跳转（不跑守卫）：供 showDialog / showBottomSheet 等框架内部路由使用。
   * 业务通常不应直接调用此方法。
   */
  private static pushRaw(
    path: string,
    params: unknown,
    pageId?: number | null,
    rootNavigator?: boolean,
    prewarmMs?: number,
  ): Promise<unknown> {
    const routeConfig = Router.getConfig(path);
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
}
