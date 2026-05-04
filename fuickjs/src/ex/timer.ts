import { TimerService } from '../services/TimerService';
import { ErrorHandler } from '../core/ErrorHandler';

let nextTimerId = 1;
const timerMap = new Map<number, { fn: (...args: any[]) => unknown; type: 'timeout' | 'interval' }>();

export function setTimeout(fn: (...args: any[]) => unknown, ms?: number): number {
  const id = nextTimerId++;
  const delay = ms || 0;
  console.log(`[Timer] setTimeout() id=${id}, delay=${delay}ms, activeTimers=${timerMap.size}`);

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
  } catch (e) {
    // If native call fails (e.g. during test or mock), run immediately
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
  const existed = timerMap.has(id);
  timerMap.delete(id);
  try {
    TimerService.deleteTimer(id);
  } catch (e) {
    console.warn(`[Timer] clearTimeout(${id}) native deleteTimer failed:`, e);
  }
  console.log(`[Timer] clearTimeout() id=${id}, existed=${existed}, remainingTimers=${timerMap.size}`);
}

export function setInterval(fn: (...args: any[]) => unknown, ms?: number): number {
  const id = nextTimerId++;
  timerMap.set(id, { fn, type: 'interval' });
  console.log(`[Timer] setInterval() id=${id}, delay=${ms || 0}ms, activeTimers=${timerMap.size}`);
  try {
    TimerService.createTimer(id, ms || 0, true);
  } catch (e) {
    console.warn(`[Timer] setInterval(${id}) native createTimer failed:`, e);
  }
  return id;
}

export function clearInterval(id: number) {
  const existed = timerMap.has(id);
  const entry = timerMap.get(id);
  timerMap.delete(id);
  try {
    TimerService.deleteTimer(id);
  } catch (e) {
    console.warn(`[Timer] clearInterval(${id}) native deleteTimer failed:`, e);
  }
  console.log(`[Timer] clearInterval() id=${id}, existed=${existed}, type=${entry?.type}, remainingTimers=${timerMap.size}`);
}

export function handleTimer(id: number) {
  const entry = timerMap.get(id);
  if (entry) {
    console.log(`[Timer] handleTimer() id=${id}, type=${entry.type}, willDelete=${entry.type === 'timeout'}`);
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
    console.warn(`[Timer] handleTimer() id=${id} not found in timerMap. Already cleared or never registered. activeTimers=${timerMap.size}, ids=[${Array.from(timerMap.keys()).join(',')}]`);
  }
}
