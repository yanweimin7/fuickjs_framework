import { TimerService } from '../services/TimerService';
import { ErrorHandler } from '../core/ErrorHandler';

let nextTimerId = 1;
const timerMap = new Map<number, { fn: (...args: any[]) => unknown; type: 'timeout' | 'interval'; native?: boolean }>();

export function setTimeout(fn: (...args: any[]) => unknown, ms?: number): number {
  const id = nextTimerId++;
  const delay = ms || 0;

  if (delay === 0) {
    Promise.resolve().then(() => {
      try {
        fn();
      } catch (e) {
        console.error(`[Timer] Error in microtask timeout callback:`, e);
        ErrorHandler.notify(e, 'timer', { id });
      }
    });
    timerMap.set(id, { fn, type: 'timeout', native: false });
    return id;
  }

  timerMap.set(id, { fn, type: 'timeout', native: true });

  try {
    TimerService.createTimer(id, delay, false);
  } catch (e) {
    console.warn(`[Timer] setTimeout(${id}) native createTimer failed, running callback immediately. Error:`, e);
    timerMap.delete(id);
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
  if (id == null || id === undefined) return;
  const entry = timerMap.get(id);
  timerMap.delete(id);
  if (entry?.native !== false) {
    try {
      TimerService.deleteTimer(id);
    } catch (e) {
      console.warn(`[Timer] clearTimeout(${id}) native deleteTimer failed:`, e);
    }
  }
}

export function setInterval(fn: (...args: any[]) => unknown, ms?: number): number {
  const id = nextTimerId++;
  timerMap.set(id, { fn, type: 'interval', native: true });
  try {
    TimerService.createTimer(id, ms || 0, true);
  } catch (e) {
    console.warn(`[Timer] setInterval(${id}) native createTimer failed:`, e);
  }
  return id;
}

export function clearInterval(id: number) {
  if (id == null || id === undefined) return;
  const entry = timerMap.get(id);
  timerMap.delete(id);
  if (entry?.native !== false) {
    try {
      TimerService.deleteTimer(id);
    } catch (e) {
      console.warn(`[Timer] clearInterval(${id}) native deleteTimer failed:`, e);
    }
  }
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
  } else {
    console.warn(`[Timer] handleTimer(${id}) not found in timerMap. activeTimers=${timerMap.size}`);
  }
}
