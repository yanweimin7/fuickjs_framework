/**
 * 宿主环境判定。
 *
 * fuickjs 跑在三类宿主上：
 *  - `browser`：Flutter Web 主线程。原生 `console`/`setTimeout`/`fetch`/`window`/
 *    `localStorage` 全部可用，无需注入任何 polyfill 或别名。
 *  - `browser-worker`：Flutter Web 的 DSL 生产 Worker（见 docs/flutter-web-support.md §6）。
 *    有全套原生 JS/Web API，但**没有 DOM，也没有 localStorage**；且 Worker 无法
 *    同步调用主线程，因此绝不能把 console/timer 路由到 `dartCallNative`。
 *  - `engine`：QuickJS isolate。宿主是 Dart/原生环境，无任何 Web API，需要注入
 *    polyfill 把能力路由到 Dart 服务，并挂 `window`/`self` 别名供业务代码使用。
 *
 * 判据优先级：显式标记 > `document` 探测。
 *
 * 之所以要显式标记而不能只靠鸭子判定：Worker 里既没有 `document` 也没有 DOM，
 * 单看 `document` 会把它误判成 `engine`，从而注入 Dart 路由版的 console/timer
 * —— 而那条路径依赖同步桥，在 Worker 里根本无法工作。标记由框架自己的 Worker
 * 入口（src/worker/entry.ts）在加载 bundle 前写入，确定性强，不依赖宿主特征。
 */

export type FuickHost = 'browser' | 'browser-worker' | 'engine';

const HOST_FLAG = '__FUICK_HOST__';

export function getHost(): FuickHost {
  const explicit = (globalThis as Record<string, unknown>)[HOST_FLAG];
  if (explicit === 'browser' || explicit === 'browser-worker' || explicit === 'engine') {
    return explicit;
  }
  // 无标记时按 DOM 探测。注意 bindGlobals 会往引擎全局挂 `window` 别名，
  // 所以判据必须是本库从不注入的 `document`，否则会自指误判。
  if (typeof globalThis.document !== 'undefined') return 'browser';
  return 'engine';
}

/**
 * 是否为带 DOM 的浏览器主线程。
 *
 * 用于「要不要注入 `window`/`self` 别名」：Worker 与 QuickJS 都没有 `window`，
 * 业务代码里的 `window.xxx` 需要别名兜底，因此这里对两者都返回 false。
 */
export function isBrowserHost(): boolean {
  return getHost() === 'browser';
}

/**
 * 宿主是否自带原生 Web API（console / timer / fetch / WebSocket / XHR / URL /
 * Blob / navigator 等）。为 true 时不得用 polyfill 覆盖：
 *  - 浏览器主线程覆盖会与 Dart 侧实现成环导致爆栈（console/timer 两条历史 bug）；
 *  - Worker 里覆盖会把 console/timer 路由到同步桥，而 Worker 无法同步调主线程。
 */
export function hasNativeWebApis(): boolean {
  return getHost() !== 'engine';
}

/**
 * 宿主是否自带 `localStorage` / `sessionStorage`。
 *
 * 单独一个判据的原因：Worker 有原生 fetch/console/timer，却**没有** Web Storage
 * （规范只把它暴露给 Window）。所以 Worker 必须走 ex/storage.ts 的内存 + 异步
 * 回写实现，不能跟着 hasNativeWebApis 一起跳过。
 */
export function hasNativeStorage(): boolean {
  return getHost() === 'browser';
}
