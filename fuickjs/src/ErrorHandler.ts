export type ErrorSource = 'render' | 'event' | 'timer' | 'promise' | 'runtime' | 'unknown';

export type ErrorHandlerFn = (error: unknown, source: ErrorSource, detail?: unknown) => void;

let currentHandler: ErrorHandlerFn | null = null;
let isNotifying = false;

function notify(error: unknown, source: ErrorSource, detail?: unknown) {
  if (!currentHandler || isNotifying) {
    return;
  }
  try {
    isNotifying = true;
    currentHandler(error, source, detail);
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
  notify,
};
