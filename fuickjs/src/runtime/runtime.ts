import * as PageRender from '../core/page_render';
import * as Timer from '../ex/timer';
import { setDebug } from '../utils/log';
import { isBrowserHost } from '../utils/env';
import { i18n } from '../i18n/i18n';
import '../polyfill';

export interface FuickConfig {
  prewarm?: boolean;
  prewarmMs?: number;
  debug?: boolean;
}

let _config: FuickConfig = {
  prewarm: false,
  prewarmMs: 50,
};

export function configure(options: FuickConfig) {
  _config = { ..._config, ...options };
  if (options.debug !== undefined) {
    setDebug(options.debug);
  }
}

export function getRuntimeConfig(): FuickConfig {
  return _config;
}

export function bindGlobals() {
  // window/self 在浏览器里是只读 getter，不能覆盖（会抛 "Cannot set property
  // window" 且导致后面的 fuickjs 不被赋值）。浏览器主线程两者本就存在，无需注入。
  // 引擎宿主与 Worker 都没有 window，挂别名供业务代码写 window.xxx；Worker 自带
  // self，下面的 typeof 判空会跳过它，只补 window。
  const g = globalThis as Record<string, unknown>;
  if (!isBrowserHost()) {
    if (typeof g.window === 'undefined') g.window = globalThis;
    if (typeof g.self === 'undefined') g.self = globalThis;
  }
  g.fuickjs = {
    render: PageRender.render,
    destroy: PageRender.destroy,
    getItemDSL: PageRender.getItemDSL,
    disposeItem: PageRender.disposeItem,
    notifyLifecycle: PageRender.notifyLifecycle,
    dispatchEvent: (eventObj: unknown, payload: unknown) => {
      const r = PageRender.ensureRenderer();
      r.dispatchEvent(eventObj, payload);
    },
    handleTimer: Timer.handleTimer,
    configure,
    getConfig: getRuntimeConfig,
    i18n,
  };
}

export const Runtime = {
  bindGlobals,
  configure,
  getConfig: getRuntimeConfig,
};
