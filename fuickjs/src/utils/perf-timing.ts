/**
 * Per-page渲染耗时跟踪 — 记录 JS 侧三个关键时间点，用于在 doRender 收尾时
 * 打出一条合并的 [PerfTiming] 日志：
 *
 * 阶段1 t_js_to_dsl: JS 收到 render 请求 → DSL 序列化完成（toDsl 结束）
 * 阶段2 t_transfer:    dartCallNative('UI.renderUI') 同步 FFI 往返耗时
 *                     （此阶段内包含了 Flutter 侧的 createNode 解析时间）
 * 阶段3 t_flutter:     Flutter 侧 FuickPageView._handleRenderDsl 的 buildNode 耗时
 *
 * 调用方：
 * - page_render.doRender()    → markStart / report
 * - DiffStrategy.commit()    → markDslReady / markSendEnd
 * - Flutter FuickPageView    → markFlutterCreateNode（通过 JS 侧日志间接体现）
 */
interface PageTiming {
  start: number;
  dslReady?: number;
  sendEnd?: number;
}

const timings: Record<number, PageTiming> = {};

export function markStart(pageId: number): void {
  timings[pageId] = { start: Date.now() };
}

export function markDslReady(pageId: number): void {
  const t = timings[pageId];
  if (t) t.dslReady = Date.now();
}

export function markSendEnd(pageId: number): void {
  const t = timings[pageId];
  if (t) t.sendEnd = Date.now();
}

export function report(pageId: number, path: string): void {
  const t = timings[pageId];
  if (!t) return;
  const end = Date.now();
  const dslReady = t.dslReady ?? end;
  const sendEnd = t.sendEnd ?? end;
  console.log(
    `[PerfTiming] page=${pageId} path=${path} |` +
      ` t_js_to_dsl=${dslReady - t.start}ms |` +
      ` t_transfer=${sendEnd - dslReady}ms |` +
      ` t_total=${end - t.start}ms`,
  );
  delete timings[pageId];
}
