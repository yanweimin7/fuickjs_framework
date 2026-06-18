export type ErrorSource = 'render' | 'event' | 'timer' | 'promise' | 'runtime' | 'unknown';

export type ErrorHandlerFn = (error: unknown, source: ErrorSource, detail?: unknown) => void;

let currentHandler: ErrorHandlerFn | null = null;
const globalListeners: ErrorHandlerFn[] = [];
let isNotifying = false;

function notify(error: unknown, source: ErrorSource, detail?: unknown) {
  if (isNotifying) {
    return;
  }
  // 兜底：没人注册 handler 时默认走 console.error，确保任何未捕获异常
  // 都会经过 ConsoleService → Flutter 日志（带 sourcemap 解析）。
  const hasHandler = currentHandler != null || globalListeners.length > 0;
  if (!hasHandler) {
    console.error(error);
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
    try {
      console.error('[ErrorHandler] Handler error:', handlerError);
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
