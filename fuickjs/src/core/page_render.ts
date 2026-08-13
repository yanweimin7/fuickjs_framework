import React from 'react';
import { createRenderer, Renderer } from './renderer';
import * as Router from '../router/router';
import type { GuardResult, RouteLocation } from '../router/router';
import { isGuardRedirect, extractRedirectTarget } from '../router/router';
import { PageContext } from './PageContext';
import { ErrorBoundary } from './ErrorBoundary';
import { LifecycleService } from '../services/LifecycleService';
import { markStart, report } from '../utils/perf-timing';
import { logDebug, perfLog } from '../utils/log';

let renderer: Renderer | null = null;
let globalErrorFallback: ((error: Error) => React.ReactNode) | null = null;
let routeGuardFallback: ((to: RouteLocation) => React.ReactNode) | null = null;

// Wire LifecycleService to the renderer's notifyLifecycle so that app-level
// foreground/background events are translated into page-level visible/invisible
// notifications — useVisible / useInvisible hooks get the benefit for free.
LifecycleService.setNotifier((pageId, type) => {
  const r = ensureRenderer();
  r.notifyLifecycle(pageId, type);
});

// 同 pageId 在途渲染状态：rendering=true 表示当前微任务正在 reconciler.update。
// 若期间有新 render() 进入，仅记录 pending 参数，等当前 update 完成后再合并执行。
// token 标识本次渲染归属：destroy() 删除 renderState（或新一轮渲染替换 state）后，
// 在途 doRenderAsync 在 await 恢复时校验 token 不匹配即放弃，避免复活已销毁页面。
type PendingRender = { path: string; params: unknown };
type RenderToken = object;
const renderState: Record<number, { rendering: boolean; token: RenderToken; pending?: PendingRender }> = {};

export function setGlobalErrorFallback(fallback: (error: Error) => React.ReactNode) {
  globalErrorFallback = fallback;
}

/** 设置守卫拒绝时的兜底 UI（默认显示"无权限访问"提示） */
export function setRouteGuardFallback(fallback: ((to: RouteLocation) => React.ReactNode) | null) {
  routeGuardFallback = fallback;
}

export function ensureRenderer() {
  if (renderer) return renderer;
  renderer = createRenderer();
  return renderer;
}

// ============================================================
// 兜底 UI 构造
// ============================================================

function defaultErrorFallback(error: Error) {
  return React.createElement(
    'Column',
    {
      mainAxisAlignment: 'center',
      crossAxisAlignment: 'center',
      padding: 20,
      decoration: { color: '#FFF0F0' },
    },
    React.createElement('Text', {
      text: 'Application Error',
      fontSize: 20,
      color: '#D32F2F',
      fontWeight: 'bold',
      margin: { bottom: 10 },
    }),
    React.createElement('Text', {
      text: error?.message || 'Unknown error occurred',
      fontSize: 14,
      color: '#333333',
      maxLines: 10,
      overflow: 'ellipsis',
    }),
  );
}

function buildNotFoundApp(path: string) {
  return React.createElement(
    'Column',
    { padding: 16, mainAxisAlignment: 'center', crossAxisAlignment: 'center' },
    React.createElement('Text', {
      text: '404',
      fontSize: 32,
      fontWeight: 'bold',
      color: '#999',
      margin: { bottom: 8 },
    }),
    React.createElement('Text', {
      text: `Route ${path} not found`,
      fontSize: 14,
      color: '#cc0000',
    }),
  );
}

function buildGuardRejectedApp(to: RouteLocation) {
  if (routeGuardFallback) {
    try {
      return routeGuardFallback(to);
    } catch (e) {
      console.error('[page_render] routeGuardFallback error:', e);
    }
  }
  return React.createElement(
    'Column',
    { padding: 16, mainAxisAlignment: 'center', crossAxisAlignment: 'center' },
    React.createElement('Text', {
      text: 'Access Denied',
      fontSize: 20,
      fontWeight: 'bold',
      color: '#D32F2F',
      margin: { bottom: 8 },
    }),
    React.createElement('Text', {
      text: `You don't have permission to access ${to.path}`,
      fontSize: 14,
      color: '#666',
    }),
  );
}

function buildLoadingApp() {
  return React.createElement(
    'Column',
    { mainAxisAlignment: 'center', crossAxisAlignment: 'center' },
    React.createElement('Text', { text: 'Loading...', fontSize: 14, color: '#999' }),
  );
}

function wrapWithProviders(pageId: number, app: React.ReactNode): React.ReactNode {
  const fallbackUI = globalErrorFallback || defaultErrorFallback;
  return React.createElement(
    PageContext.Provider,
    { value: { pageId } },
    React.createElement(ErrorBoundary, { fallback: fallbackUI }, app),
  );
}

// ============================================================
// 核心渲染（异步：守卫可能 await）
// ============================================================

async function doRenderAsync(pageId: number, path: string, params: unknown, token: RenderToken) {
  markStart(pageId);
  const t0 = Date.now();
  const r = ensureRenderer();
  const t1 = Date.now();

  // 本次渲染是否已被取消（destroy 删除 renderState，或被新一轮渲染替换）。
  const isCancelled = () => renderState[pageId]?.token !== token;

  const to = Router.resolve(path, params);
  const t2 = Date.now();

  // 1. 路由未匹配且无 404 兜底
  if (!to || !to.matched.component) {
    console.warn(`[Router] No route matched for ${path}`);
    r.update(wrapWithProviders(pageId, buildNotFoundApp(path)), pageId);
    return;
  }

  // 2. 跑守卫（首屏 from=null，跳转 from=当前 pageId 的 location）
  const from = Router.getLocation(pageId);
  let guardResult: GuardResult;
  try {
    guardResult = await Router.runGuards(to, from);
  } catch (e) {
    console.error('[Router] Guard error:', e);
    guardResult = false;
  }

  // await 期间页面可能已被 destroy，继续 update 会重建容器复活页面。
  if (isCancelled()) {
    console.warn(`[page_render] render cancelled for pageId=${pageId}, path=${path} (page destroyed or superseded)`);
    return;
  }

  // 3. 守卫拒绝
  if (guardResult === false) {
    console.warn(`[Router] Guard rejected navigation to ${path}`);
    r.update(wrapWithProviders(pageId, buildGuardRejectedApp(to)), pageId);
    return;
  }

  // 4. 守卫重定向：通知 Flutter 替换当前路由，本页渲染 loading 占位
  if (isGuardRedirect(guardResult)) {
    const target = extractRedirectTarget(guardResult);
    logDebug(`[Router] Guard redirecting ${path} → ${target.path}`);
    void dartCallNativeAsync('Navigator.pushReplace', {
      path: target.path,
      params: target.params ?? {},
      pageId,
    });
    r.update(wrapWithProviders(pageId, buildLoadingApp()), pageId);
    return;
  }

  // 5. 守卫通过，正常渲染
  Router.recordLocation(pageId, to);
  const t3 = Date.now();
  const factory = to.matched.component!;
  // factory 在 React render 之外同步执行，抛错不会被 ErrorBoundary 捕获；
  // 不包裹会变成 unhandled rejection，这里兜底渲染错误 UI。
  let app: React.ReactNode;
  try {
    app = factory(to.params);
  } catch (e) {
    console.error(`[page_render] Page component factory threw for ${path}:`, e);
    const fallbackUI = globalErrorFallback || defaultErrorFallback;
    app = fallbackUI(e instanceof Error ? e : new Error(String(e)));
  }
  const t4 = Date.now();

  r.update(wrapWithProviders(pageId, app), pageId);
  const t5 = Date.now();

  perfLog(
    `[Perf] page=${pageId} path=${path} total=${t5 - t0}ms |` +
      ` ensureRenderer=${t1 - t0}ms |` +
      ` router.resolve=${t2 - t1}ms |` +
      ` createElement=${t4 - t3}ms |` +
      ` reconciler.update=${t5 - t4}ms`,
  );
  report(pageId, path);
}

export function render(pageId: number, path: string, params: unknown) {
  const state = renderState[pageId];
  if (state && state.rendering) {
    // 同 pageId 已有渲染在途，仅保留最新参数，等当前完成后合并执行，
    // 避免 reconciler 嵌套触发 React #327 与中间帧抖动。
    state.pending = { path, params };
    console.warn(`[page_render] coalescing render for pageId=${pageId}, path=${path}`);
    return;
  }

  const token: RenderToken = {};
  renderState[pageId] = { rendering: true, token };
  void doRenderAsync(pageId, path, params, token)
    .catch((e) => {
      console.error(`[page_render] doRenderAsync failed for pageId=${pageId}, path=${path}:`, e);
    })
    .finally(() => {
      // 仅当 state 仍属于本次渲染时才收尾：destroy() 或后续新渲染可能已替换/删除 state，
      // 此时不能误删他人的状态。
      const current = renderState[pageId];
      if (!current || current.token !== token) return;
      // 处理在途累积的最新一笔；丢弃中间被覆盖的旧 pending（最新即正确）。
      const next = current.pending;
      if (next) {
        renderState[pageId] = { rendering: false, token };
        // 异步调度避免同步重入导致 reconciler 仍在 commit 阶段。
        // 执行前必须再校验 token：微任务等待期间 destroy() 可能已删除 state
        // （或被新一轮渲染替换），此时直接调 render 会复活已销毁的页面。
        //
        // 场景（纯 JS 语义）：
        //   1) render(A) 在途，撞上 render(B) → B 进 pending
        //   2) A 的 .finally 调度微任务 M：render(B)
        //   3) ★ 若 M 执行前 Flutter 调 destroy(pageId)，state 被删
        //   4) M 执行时入口只看 `state && state.rendering`，undefined 直接放行
        //      → ensureRoot 重建 container/root，JS 侧复活 Flutter 已不认的页面
        //
        // 在当前 QuickJS 引擎下，runJobs 是 do-while 排空到底的同步循环，
        // .finally 与微任务 M 必然同一次 drain 连续执行，Flutter destroy 插不进
        // 两者之间，所以最危险的第 3 步实际不可达。校验仍保留，是为了：
        //   - 不依赖引擎 drain 实现细节（JSC 后端模型不同；日后若改成"每次 N 个 job"
        //     或 drain 中同步桥接重入，窗口立刻变成可达）
        //   - 把正确性放在 JS 语义层，三行成本换掉一个隐式依赖
        Promise.resolve().then(() => {
          if (renderState[pageId]?.token === token) {
            render(pageId, next.path, next.params);
          }
        });
      } else {
        delete renderState[pageId];
      }
    });
}

export function destroy(pageId: number) {
  const r = ensureRenderer();
  // 清掉在途渲染记录与路由状态，防止 destroy 后还触发 pending 重渲染。
  delete renderState[pageId];
  Router.clearLocation(pageId);
  LifecycleService._onPageLifecycle(pageId, 'invisible');
  r.destroy(pageId);
}

export function getItemDSL(pageId: number, refId: string, index: number) {
  const r = ensureRenderer();
  return r.getItemDSL(pageId, refId, index);
}

export function disposeItem(pageId: number, refId: string, index: number) {
  const r = ensureRenderer();
  r.disposeItem(pageId, refId, index);
}

export function elementToDsl(pageId: number, element: React.ReactNode) {
  const r = ensureRenderer();
  return r.elementToDsl(pageId, element);
}

export function notifyLifecycle(pageId: number, type: 'visible' | 'invisible') {
  LifecycleService._onPageLifecycle(pageId, type);
  const r = ensureRenderer();
  r.notifyLifecycle(pageId, type);
}

export function getContainer(pageId: number) {
  const r = ensureRenderer();
  return r.getContainer(pageId);
}
