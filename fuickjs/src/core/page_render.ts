import React from 'react';
import { createRenderer, Renderer } from './renderer';
import * as Router from '../router/router';
import { PageContext } from './PageContext';
import { ErrorBoundary } from './ErrorBoundary';
import { LifecycleService } from '../services/LifecycleService';
import { markStart, report } from '../utils/perf-timing';

let renderer: Renderer | null = null;
let globalErrorFallback: ((error: Error) => React.ReactNode) | null = null;

// Wire LifecycleService to the renderer's notifyLifecycle so that app-level
// foreground/background events are translated into page-level visible/invisible
// notifications — useVisible / useInvisible hooks get the benefit for free.
LifecycleService.setNotifier((pageId, type) => {
  const r = ensureRenderer();
  r.notifyLifecycle(pageId, type);
});

// 同 pageId 在途渲染状态：rendering=true 表示当前微任务正在 reconciler.update。
// 若期间有新 render() 进入，仅记录 pending 参数，等当前 update 完成后再合并执行。
type PendingRender = { path: string; params: unknown };
const renderState: Record<number, { rendering: boolean; pending?: PendingRender }> = {};

export function setGlobalErrorFallback(fallback: (error: Error) => React.ReactNode) {
  globalErrorFallback = fallback;
}

export function ensureRenderer() {
  if (renderer) return renderer;
  renderer = createRenderer();
  return renderer;
}

function doRender(pageId: number, path: string, params: unknown) {
  markStart(pageId);
  const t0 = Date.now();
  const r = ensureRenderer();

  const t1 = Date.now();
  const factory = Router.match(path);
  const t2 = Date.now();

  let app: React.ReactNode;
  if (typeof factory === 'function') {
    app = factory(params || {});
  } else {
    app = React.createElement(
      'Column',
      { padding: 16, mainAxisAlignment: 'center' },
      React.createElement('Text', { text: `Route ${path} not found`, fontSize: 16, color: '#cc0000' }),
    );
  }
  const t3 = Date.now();

  const fallbackUI =
    globalErrorFallback ||
    ((error: Error) =>
      React.createElement(
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
      ));

  const wrappedApp = React.createElement(
    PageContext.Provider,
    { value: { pageId } },
    React.createElement(
      ErrorBoundary,
      {
        fallback: fallbackUI,
      },
      app,
    ),
  );
  const t4 = Date.now();

  r.update(wrappedApp, pageId);

  const t5 = Date.now();
  console.log(
    `[Perf] page=${pageId} path=${path} total=${t5 - t0}ms |` +
      ` ensureRenderer=${t1 - t0}ms |` +
      ` router.match=${t2 - t1}ms |` +
      ` createElement=${t3 - t2}ms |` +
      ` wrapContext=${t4 - t3}ms |` +
      ` reconciler.update=${t5 - t4}ms`,
  );
  // 合并打印三阶段耗时：JS→DSL / DSL传输 / 总计
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

  renderState[pageId] = { rendering: true };
  try {
    doRender(pageId, path, params);
  } finally {
    // 处理在途累积的最新一笔；丢弃中间被覆盖的旧 pending（最新即正确）。
    const next = renderState[pageId]?.pending;
    if (next) {
      renderState[pageId] = { rendering: false };
      // 异步调度避免同步重入导致 reconciler 仍在 commit 阶段。
      Promise.resolve().then(() => render(pageId, next.path, next.params));
    } else {
      delete renderState[pageId];
    }
  }
}

export function destroy(pageId: number) {
  const r = ensureRenderer();
  // 清掉在途渲染记录，防止 destroy 后还触发 pending 重渲染。
  delete renderState[pageId];
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
