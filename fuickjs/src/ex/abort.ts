import { EventTarget, Event } from './events';

export class AbortSignal extends EventTarget {
  aborted: boolean = false;
  reason: any;
  onabort: ((event: Event) => void) | null = null;

  constructor() {
    super();
  }

  static abort(reason?: any): AbortSignal {
    const signal = new AbortSignal();
    signal.aborted = true;
    signal.reason = reason;
    return signal;
  }

  static timeout(milliseconds: number): AbortSignal {
    const signal = new AbortSignal();
    setTimeout(() => {
      const event = new Event('abort');
      signal.aborted = true;
      signal.reason = new Error('TimeoutError');
      if (signal.onabort) signal.onabort(event);
      signal.dispatchEvent(event);
    }, milliseconds);
    return signal;
  }
}

export class AbortController {
  signal: AbortSignal = new AbortSignal();

  abort(reason?: any) {
    if (this.signal.aborted) return;
    this.signal.aborted = true;
    this.signal.reason = reason || new Error('AbortError');
    const event = new Event('abort');
    if (this.signal.onabort) this.signal.onabort(event);
    this.signal.dispatchEvent(event);
  }
}
