import React from 'react';
import { GenericPage } from '../widgets/GenericPage';

// ============================================================
// 类型定义
// ============================================================

/** 页面组件工厂：接收合并后的 params（路径参数 + 调用方传入） */
export type ComponentFactory = (params?: unknown) => React.ReactNode;

/** 守卫返回值：true/void 放行；false 取消；string 重定向；对象重定向带参数 */
export type GuardResult = boolean | void | string | { path: string; params?: unknown };

/** 路由守卫：可同步或异步 */
export type Guard = (to: RouteLocation, from: RouteLocation | null) => Promise<GuardResult> | GuardResult;

/** 单条路由配置 */
export interface RouteConfig {
  /** 路径模式，支持 :param 占位，如 /news/:id；'*' 表示 404 兜底 */
  path: string;
  /** 页面组件工厂 */
  component?: ComponentFactory;
  /** 静态重定向字符串或函数 */
  redirect?: string | ((to: RouteLocation) => string | { path: string; params?: unknown });
  /** 命名路由，可通过 pushByName 跳转 */
  name?: string;
  /** 业务自定义元信息（鉴权标记、页面标题等） */
  meta?: Record<string, unknown>;
  /** 路由级守卫，仅对当前路由生效 */
  beforeEnter?: Guard;
  /** 预热时长（ms），与旧 API prewarmMs 一致 */
  prewarmMs?: number;
}

/** 全局路由配置 */
export interface RouterConfig {
  routes: RouteConfig[];
  /** 全局守卫，对所有跳转生效（顺序执行） */
  guards?: Guard[];
  /** 404 兜底组件（等价于 routes 中放一条 path:'*'） */
  notFound?: ComponentFactory;
}

/** 当前路由位置快照 */
export interface RouteLocation {
  /** 完整路径（含参数值），如 /news/123 */
  path: string;
  /** 匹配到的路由配置 */
  matched: RouteConfig;
  /** 合并后的参数：路径参数 + 调用方传入 */
  params: Record<string, unknown>;
  /** 路由名称（若配置） */
  name?: string;
  /** 路由元信息 */
  meta: Record<string, unknown>;
}

// ============================================================
// 内部状态
// ============================================================

const routes: RouteConfig[] = [];
const routesByName: Map<string, RouteConfig> = new Map();
let globalGuards: Guard[] = [];
let notFoundFactory: ComponentFactory | null = null;

/** pageId → 当前 RouteLocation，用于守卫的 from 参数与 useRoute hook */
const pageLocations: Map<number, RouteLocation> = new Map();

// 框架内部路由：通用对话框容器
routes.push({
  path: '/_generic_dialog',
  component: (args) => React.createElement(GenericPage, args as any),
});

// ============================================================
// 路径匹配（轻量自实现，不引入 path-to-regexp 依赖）
// ============================================================

/**
 * 匹配单个 pattern 与 path。
 * 返回提取的路径参数对象；不匹配返回 null。
 *  - pattern === '*'  匹配任意（404 兜底）
 *  - pattern 段以 ':' 开头视为参数占位
 */
function matchPath(pattern: string, path: string): Record<string, string> | null {
  if (pattern === '*') return {};

  // 去掉 query string
  const cleanPath = path.split('?')[0];
  const patternParts = pattern.split('/').filter(Boolean);
  const pathParts = cleanPath.split('/').filter(Boolean);

  if (patternParts.length !== pathParts.length) return null;

  const params: Record<string, string> = {};
  for (let i = 0; i < patternParts.length; i++) {
    const p = patternParts[i];
    const v = pathParts[i];
    if (p.startsWith(':')) {
      params[p.slice(1)] = decodeURIComponent(v);
    } else if (p !== v) {
      return null;
    }
  }
  return params;
}

// ============================================================
// 路由解析
// ============================================================

/**
 * 解析路径为 RouteLocation。
 * 优先级：精确/参数匹配 → 404 兜底（path:'*' 或 notFound）→ null
 */
export function resolve(path: string, callerParams?: unknown): RouteLocation | null {
  let matchedRoute: RouteConfig | null = null;
  let pathParams: Record<string, string> | null = null;

  for (const route of routes) {
    const m = matchPath(route.path, path);
    if (m !== null) {
      matchedRoute = route;
      pathParams = m;
      break;
    }
  }

  // 404 兜底
  if (!matchedRoute) {
    if (notFoundFactory) {
      matchedRoute = { path: '*', component: notFoundFactory };
      pathParams = {};
    } else {
      return null;
    }
  }

  const params: Record<string, unknown> = {
    ...(pathParams || {}),
    ...((callerParams as Record<string, unknown>) || {}),
  };

  return {
    path,
    matched: matchedRoute,
    params,
    name: matchedRoute.name,
    meta: matchedRoute.meta || {},
  };
}

// ============================================================
// 守卫
// ============================================================

/**
 * 检查路由是否配置了 redirect。
 * 返回重定向目标；无 redirect 返回 null。
 */
export function checkRedirect(to: RouteLocation): { path: string; params?: unknown } | null {
  const route = to.matched;
  if (!route.redirect) return null;
  if (typeof route.redirect === 'string') {
    return { path: route.redirect };
  }
  const result = route.redirect(to);
  return typeof result === 'string' ? { path: result } : result;
}

/**
 * 执行守卫链：redirect → 全局守卫 → 路由级 beforeEnter。
 * 任一环节返回非放行值即短路返回该值。
 */
export async function runGuards(to: RouteLocation, from: RouteLocation | null): Promise<GuardResult> {
  // 1. 静态/函数重定向优先于守卫
  const redirectTarget = checkRedirect(to);
  if (redirectTarget) return redirectTarget;

  // 2. 全局守卫
  for (const guard of globalGuards) {
    const r = await guard(to, from);
    if (r !== true && r !== undefined && r !== null) return r;
  }
  // 3. 路由级守卫
  if (to.matched.beforeEnter) {
    const r = await to.matched.beforeEnter(to, from);
    if (r !== true && r !== undefined && r !== null) return r;
  }
  return true;
}

/** 判断守卫结果是否为"放行" */
export function isGuardPassed(result: GuardResult): boolean {
  return result === true || result === undefined || result === null;
}

/** 判断守卫结果是否为重定向 */
export function isGuardRedirect(result: GuardResult): result is string | { path: string; params?: unknown } {
  if (typeof result === 'string' && result.length > 0) return true;
  if (result && typeof result === 'object' && 'path' in result) return true;
  return false;
}

/** 提取重定向目标 */
export function extractRedirectTarget(result: string | { path: string; params?: unknown }): {
  path: string;
  params?: unknown;
} {
  return typeof result === 'string' ? { path: result } : result;
}

// ============================================================
// pageId ↔ RouteLocation 状态
// ============================================================

export function recordLocation(pageId: number, location: RouteLocation): void {
  pageLocations.set(pageId, location);
}

export function getLocation(pageId: number): RouteLocation | null {
  return pageLocations.get(pageId) ?? null;
}

export function clearLocation(pageId: number): void {
  pageLocations.delete(pageId);
}

// ============================================================
// 公开 API
// ============================================================

/**
 * 声明式路由配置（推荐）。
 * 可重复调用：routes 累积；guards/notFound 后者覆盖。
 */
export function config(options: RouterConfig): void {
  if (options.routes) {
    for (const r of options.routes) {
      routes.push(r);
      if (r.name) routesByName.set(r.name, r);
    }
  }
  if (options.guards) {
    globalGuards = options.guards.slice();
  }
  if (options.notFound) {
    notFoundFactory = options.notFound;
    // 同时入 routes 表，便于 resolve 统一处理
    const exists = routes.some((r) => r.path === '*');
    if (!exists) {
      routes.push({ path: '*', component: options.notFound });
    }
  }
}

/**
 * 旧 API 兼容：注册单个路由。
 * 等价于 config({ routes: [{ path, component: factory, prewarmMs }] })。
 */
export function register(path: string, componentFactory: ComponentFactory, routeConfig?: { prewarmMs?: number }): void {
  const route: RouteConfig = {
    path,
    component: componentFactory,
    prewarmMs: routeConfig?.prewarmMs,
  };
  routes.push(route);
}

/** 注册全局守卫（追加，非覆盖） */
export function addGuard(guard: Guard): void {
  globalGuards.push(guard);
}

/** 通过名称查找路由配置 */
export function getRouteByName(name: string): RouteConfig | undefined {
  return routesByName.get(name);
}

/** 旧 API 兼容：返回工厂函数 */
export function match(path: string): ComponentFactory | undefined {
  const loc = resolve(path);
  return loc?.matched.component;
}

/** 旧 API 兼容：返回路由配置（结构扩展，prewarmMs 仍可读） */
export function getConfig(path: string): RouteConfig | undefined {
  return resolve(path)?.matched;
}

/** 仅用于测试/调试：清空所有路由与守卫 */
export function _reset(): void {
  routes.length = 0;
  routesByName.clear();
  globalGuards = [];
  notFoundFactory = null;
  pageLocations.clear();
  // 重新注册框架内部路由
  routes.push({
    path: '/_generic_dialog',
    component: (args) => React.createElement(GenericPage, args as any),
  });
}

export const Router = {
  config,
  register,
  addGuard,
  getRouteByName,
  match,
  getConfig,
  resolve,
  runGuards,
  recordLocation,
  getLocation,
  clearLocation,
};
