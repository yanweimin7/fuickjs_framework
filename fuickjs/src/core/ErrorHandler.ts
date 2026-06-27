import { ErrorReportService } from '../services/ErrorReportService';

export type ErrorSource = 'render' | 'event' | 'timer' | 'promise' | 'runtime' | 'unknown';

export type ErrorHandlerFn = (error: unknown, source: ErrorSource, detail?: unknown) => void;

let currentHandler: ErrorHandlerFn | null = null;
const globalListeners: ErrorHandlerFn[] = [];
let isNotifying = false;

function notify(error: unknown, source: ErrorSource, detail?: unknown) {
  if (isNotifying) {
    return;
  }
  // 兜底：没人注册 handler 时通过 ErrorReportService 上报到 Flutter，
  // 由 Flutter 侧做 sourcemap 还原并打印结构化错误（保留 source / detail 上下文）。
  const hasHandler = currentHandler != null || globalListeners.length > 0;
  if (!hasHandler) {
    ErrorReportService.report(error, source, detail);
    return;
  }
  try {
    isNotifying = true;
    if (currentHandler) {
      currentHandler(error, source, detail);
    }
    globalListeners.forEach((listener) => {
      try {
        listener(error, source, detail);
      } catch (e) {
        console.error('[ErrorHandler] Global listener error:', e);
      }
    });
  } catch (handlerError) {
    // handler 自身抛异常（含 re-throw 原始错误），同样走 ErrorReportService
    // 以获得 sourcemap 还原。保留原始 source / detail 上下文。
    try {
      ErrorReportService.report(handlerError, source, detail);
    } catch {}
  } finally {
    isNotifying = false;
  }
}

export const ErrorHandler = {
  set(handler: ErrorHandlerFn | null) {
    currentHandler = handler || null;
  },
  addListener(listener: ErrorHandlerFn) {
    globalListeners.push(listener);
    return () => {
      const index = globalListeners.indexOf(listener);
      if (index > -1) {
        globalListeners.splice(index, 1);
      }
    };
  },
  notify,
};
