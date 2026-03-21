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
import { ErrorHandler } from '../ErrorHandler';

const globalAny = globalThis as any;

export function setupGlobals() {
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
  globalAny.base64ToArrayBuffer = base64ToArrayBuffer;

  if (typeof (globalAny as any).queueMicrotask === 'undefined') {
    (globalAny as any).queueMicrotask = function queueMicrotask(callback: () => void) {
      Promise.resolve().then(callback);
    };
  }

  if (!globalThis.performance) {
    globalThis.performance = performance as Performance;
  }

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
