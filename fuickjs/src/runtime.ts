import * as PageRender from './page_render';
import * as Console from './ex/console';
import * as Timer from './ex/timer';
import { fetch } from './ex/fetch';
import { ErrorHandler } from './ErrorHandler';

export function bindGlobals() {
  setupPolyfills();

  // 显式挂载到 globalThis，确保 Flutter 侧可以访问到
  Object.assign(globalThis, {
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

function setupPolyfills() {
  // Console
  const oldConsole = globalThis.console || {};
  globalThis.console = {
    ...oldConsole,
    log: Console.log,
    warn: Console.warn,
    error: Console.error,
  } as unknown as Console;

  // Timer
  globalThis.setTimeout = Timer.setTimeout as unknown as typeof setTimeout;
  globalThis.clearTimeout = Timer.clearTimeout as unknown as typeof clearTimeout;
  globalThis.setInterval = Timer.setInterval as unknown as typeof setInterval;
  globalThis.clearInterval = Timer.clearInterval as unknown as typeof clearInterval;

  // Fetch
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  globalThis.fetch = fetch;

  // Performance
  if (!globalThis.performance) {
    (globalThis as unknown as { performance: unknown }).performance = {
      now: () => Date.now(),
    };
  }
  const globalAny = globalThis as unknown as Record<string, unknown>;
  const handleError = (error: unknown, source: 'promise' | 'runtime', detail?: unknown) => {
    ErrorHandler.notify(error, source, detail);
  };

  if (typeof globalAny.addEventListener === 'function') {
    const addEventListener = globalAny.addEventListener as (
      type: string,
      listener: (
        event: Event | { reason?: unknown; error?: unknown; message?: unknown; preventDefault?: () => void },
      ) => void,
    ) => void;

    addEventListener('unhandledrejection', (event) => {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      handleError(event?.reason ?? event, 'promise', event);
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      if (typeof event?.preventDefault === 'function') {
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-ignore
        event.preventDefault();
      }
    });
    addEventListener('error', (event) => {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      handleError(event?.error ?? event?.message ?? event, 'runtime', event);
    });
  } else {
    globalAny.onunhandledrejection = (event: { reason?: unknown; preventDefault?: () => void }) => {
      handleError(event?.reason ?? event, 'promise', event);
      if (typeof event?.preventDefault === 'function') {
        event.preventDefault();
      }
    };
    globalAny.onerror = (message: unknown, source: unknown, lineno: unknown, colno: unknown, error: unknown) => {
      handleError(error ?? message, 'runtime', { message, source, lineno, colno });
    };
  }
}
