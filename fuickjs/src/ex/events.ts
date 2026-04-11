export class Event {
  type: string;
  cancelable: boolean;
  defaultPrevented: boolean = false;
  timeStamp: number;

  constructor(type: string, options: { cancelable?: boolean } = {}) {
    this.type = type;
    this.cancelable = options.cancelable || false;
    this.timeStamp = Date.now();
  }

  preventDefault() {
    if (this.cancelable) {
      this.defaultPrevented = true;
    }
  }
}

export class CustomEvent extends Event {
  detail: any;

  constructor(type: string, options: { detail?: any; cancelable?: boolean } = {}) {
    super(type, options);
    this.detail = options.detail;
  }
}

export type EventListener = (event: Event) => void;

export class EventTarget {
  private listeners: Map<string, Set<EventListener>> = new Map();

  addEventListener(type: string, listener: EventListener): void {
    let typeListeners = this.listeners.get(type);
    if (!typeListeners) {
      typeListeners = new Set();
      this.listeners.set(type, typeListeners);
    }
    typeListeners.add(listener);
  }

  removeEventListener(type: string, listener: EventListener): void {
    const typeListeners = this.listeners.get(type);
    if (typeListeners) {
      typeListeners.delete(listener);
    }
  }

  dispatchEvent(event: Event): boolean {
    const typeListeners = this.listeners.get(event.type);
    if (typeListeners) {
      for (const listener of typeListeners) {
        try {
          listener(event);
        } catch (e) {
          console.error(`Error in event listener for ${event.type}:`, e);
        }
      }
    }
    return !event.defaultPrevented;
  }
}
