import * as PageRender from '../core/page_render';
import * as Timer from '../ex/timer';
import '../polyfill';

export function bindGlobals() {
  Object.assign(globalThis, {
    window: globalThis,
    self: globalThis,
    fuickjs: {
      render: PageRender.render,
      destroy: PageRender.destroy,
      getItemDSL: PageRender.getItemDSL,
      notifyLifecycle: PageRender.notifyLifecycle,
      dispatchEvent: (eventObj: unknown, payload: unknown) => {
        const r = PageRender.ensureRenderer();
        r.dispatchEvent(eventObj, payload);
      },
      handleTimer: Timer.handleTimer,
    },
  });
}

export const Runtime = {
  bindGlobals,
};
