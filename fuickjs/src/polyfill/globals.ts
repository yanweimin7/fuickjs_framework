import * as Console from '../ex/console';
import * as Timer from '../ex/timer';
import { fetch } from '../ex/fetch';
import { atob, btoa } from '../ex/base64';
import { URL, URLSearchParams } from '../ex/url';
import { Event, CustomEvent, EventTarget } from '../ex/events';
import { AbortController, AbortSignal } from '../ex/abort';
import { XMLHttpRequest } from '../ex/xhr';
import { performance } from '../ex/performance';
import { localStorage, sessionStorage } from '../ex/storage';
import { WebSocket, base64ToArrayBuffer } from '../ex/websocket';
import { Headers } from '../ex/headers';
import { Blob } from '../ex/blob';
import { ErrorHandler } from '../core/ErrorHandler';
import { navigator, initNavigator } from './navigator';
import { hasNativeStorage, hasNativeWebApis } from '../utils/env';

const globalAny = globalThis as any;

export function setupGlobals() {
  // 自带原生 Web API 的宿主（浏览器主线程 / Worker）无需任何 native-API 替换：
  // - 主线程：Dart 侧这些 API 在 web 上也走浏览器原生（如 Dart Timer → 浏览器
  //   setTimeout），替换会与之成环导致死循环爆栈（console/timer 两条历史 bug）。
  // - Worker：替换会把 console/timer 路由到同步桥 dartCallNative，而 Worker
  //   无法同步调用主线程，一调即废。
  // 仅引擎宿主（QuickJS）才注入 polyfill 路由到 Dart 服务。见 utils/env.ts。
  if (!hasNativeWebApis()) {
    globalThis.console = Console as any;
    globalThis.setTimeout = Timer.setTimeout as any;
    globalThis.clearTimeout = Timer.clearTimeout as any;
    globalThis.setInterval = Timer.setInterval as any;
    globalThis.clearInterval = Timer.clearInterval as any;
    globalThis.fetch = fetch as any;
    globalThis.atob = atob;
    globalThis.btoa = btoa;
    globalThis.URL = URL as any;
    globalThis.URLSearchParams = URLSearchParams as any;
    globalThis.Event = Event as any;
    globalThis.CustomEvent = CustomEvent as any;
    globalThis.EventTarget = EventTarget as any;
    globalThis.AbortController = AbortController as any;
    globalThis.AbortSignal = AbortSignal as any;
    globalThis.Headers = Headers as any;
    globalThis.XMLHttpRequest = XMLHttpRequest as any;
    globalThis.WebSocket = WebSocket as any;
    globalThis.Blob = Blob as any;

    Object.defineProperty(globalThis, 'navigator', {
      value: navigator,
      writable: false,
      configurable: false,
    });

    // Kick off async device info fetch — non-blocking, navigator works with
    // sensible defaults immediately.
    initNavigator().catch(() => {});
  }

  // Web Storage 与上面分开判定：规范只把 localStorage/sessionStorage 暴露给
  // Window，Worker 里没有，所以 Worker 虽然有原生 fetch/console/timer，仍需要
  // ex/storage.ts 的内存实现（写入异步回写 Dart，不走同步桥）。
  if (!hasNativeStorage()) {
    Object.defineProperty(globalThis, 'localStorage', {
      value: localStorage,
      writable: false,
      configurable: false,
    });
    Object.defineProperty(globalThis, 'sessionStorage', {
      value: sessionStorage,
      writable: false,
      configurable: false,
    });
  }

  globalAny.base64ToArrayBuffer = base64ToArrayBuffer;

  if (typeof (globalAny as any).queueMicrotask === 'undefined') {
    (globalAny as any).queueMicrotask = function queueMicrotask(callback: () => void) {
      Promise.resolve().then(callback);
    };
  }

  if (!globalThis.performance) {
    globalThis.performance = performance as Performance;
  }

  const handleError = (error: unknown, source: 'promise' | 'runtime', detail?: unknown) => {
    ErrorHandler.notify(error, source, detail);
  };

  if (typeof globalAny.addEventListener === 'function') {
    globalAny.addEventListener('unhandledrejection', (event: any) => {
      handleError(event?.reason ?? event, 'promise', event);
      if (typeof event?.preventDefault === 'function') {
        event.preventDefault();
      }
    });
    globalAny.addEventListener('error', (event: any) => {
      handleError(event?.error ?? event?.message ?? event, 'runtime', event);
    });
  } else {
    globalAny.onunhandledrejection = (event: any) => {
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
