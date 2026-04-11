import { TimerService } from '../services/TimerService';
import { ErrorHandler } from '../core/ErrorHandler';

let nextTimerId = 1;
const timerMap = new Map<number, { fn: (...args: any[]) => unknown; type: 'timeout' | 'interval' }>();

export function setTimeout(fn: (...args: any[]) => unknown, ms?: number): number {
  const id = nextTimerId++;
  const delay = ms || 0;

  if (delay === 0) {
    // Optimization: Use Promise.resolve() for zero delay to run in microtask
    Promise.resolve().then(() => {
      try {
        fn();
      } catch (e) {
        console.error(`[Timer] Error in microtask timeout callback:`, e);
        ErrorHandler.notify(e, 'timer', { id });
      }
    });
    return id;
  }

  timerMap.set(id, { fn, type: 'timeout' });

  try {
    TimerService.createTimer(id, delay, false);
  } catch {
    // If native call fails (e.g. during test or mock), run immediately
    try {
      fn();
    } catch (innerE) {
      console.error(`[Timer] Error in immediate timer callback:`, innerE);
      ErrorHandler.notify(innerE, 'timer', { id });
    }
  }
  return id;
}

export function clearTimeout(id: number) {
  timerMap.delete(id);
  TimerService.deleteTimer(id);
}

export function setInterval(fn: (...args: any[]) => unknown, ms?: number): number {
  const id = nextTimerId++;
  timerMap.set(id, { fn, type: 'interval' });
  TimerService.createTimer(id, ms || 0, true);
  return id;
}

export function clearInterval(id: number) {
  timerMap.delete(id);
  TimerService.deleteTimer(id);
}

export function handleTimer(id: number) {
  const entry = timerMap.get(id);
  if (entry) {
    if (entry.type === 'timeout') {
      timerMap.delete(id);
    }
    try {
      if (typeof entry.fn === 'function') {
        entry.fn();
      } else {
        console.error(`[Timer] Callback for timer ${id} is not a function:`, entry.fn);
      }
    } catch (e) {
      console.error(`[Timer] Error in timer ${id} callback:`, e);
      ErrorHandler.notify(e, 'timer', { id });
    }
  }
}
