export type ErrorSource = 'render' | 'event' | 'timer' | 'promise' | 'runtime' | 'unknown';

export type ErrorHandlerFn = (error: unknown, source: ErrorSource, detail?: unknown) => void;

let currentHandler: ErrorHandlerFn | null = null;
const globalListeners: ErrorHandlerFn[] = [];
let isNotifying = false;

function notify(error: unknown, source: ErrorSource, detail?: unknown) {
  if (isNotifying) {
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
