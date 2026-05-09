import * as PageRender from '../core/page_render';
import * as Timer from '../ex/timer';
import { setDebug } from '../utils/log';
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
  Object.assign(globalThis, {
    window: globalThis,
    self: globalThis,
    fuickjs: {
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
    },
  });
}

export const Runtime = {
  bindGlobals,
  configure,
  getConfig: getRuntimeConfig,
};
