import { Event, EventTarget, EventListener } from './events';

// WebSocket ready states
export const enum WebSocketReadyState {
  CONNECTING = 0,
  OPEN = 1,
  CLOSING = 2,
  CLOSED = 3,
}

// WebSocket events
export class CloseEvent extends Event {
  code: number;
  reason: string;
  wasClean: boolean;

  constructor(type: string, options: { code?: number; reason?: string; wasClean?: boolean } = {}) {
    super(type);
    this.code = options.code ?? 1000;
    this.reason = options.reason ?? '';
    this.wasClean = options.wasClean ?? false;
  }
}

export class MessageEvent extends Event {
  data: string | ArrayBuffer | Blob;
  origin: string;
  lastEventId: string;

  constructor(
    type: string,
    options: { data?: string | ArrayBuffer | Blob; origin?: string; lastEventId?: string } = {},
  ) {
    super(type);
    this.data = options.data ?? '';
    this.origin = options.origin ?? '';
    this.lastEventId = options.lastEventId ?? '';
  }
}

export interface WebSocketEventMap {
  open: Event;
  message: MessageEvent;
  error: Event;
  close: CloseEvent;
}

let socketIdCounter = 0;

export class WebSocket extends EventTarget {
  private _socketId: string;
  private _url: string;
  private _protocols: string | string[];
  private _readyState: WebSocketReadyState = WebSocketReadyState.CONNECTING;
  private _bufferedAmount = 0;
  private _extensions = '';
  private _protocol = '';

  // Event handlers
  onopen: ((this: WebSocket, event: Event) => void) | null = null;
  onmessage: ((this: WebSocket, event: MessageEvent) => void) | null = null;
  onerror: ((this: WebSocket, event: Event) => void) | null = null;
  onclose: ((this: WebSocket, event: CloseEvent) => void) | null = null;

  constructor(url: string, protocols?: string | string[]) {
    super();
    this._socketId = `ws_${++socketIdCounter}_${Date.now()}`;
    this._url = url;
    this._protocols = protocols ?? [];

    // Initialize WebSocket connection through native service
    this._initConnection();
  }

  // Getters
  get url(): string {
    return this._url;
  }

  get readyState(): number {
    return this._readyState;
  }

  get bufferedAmount(): number {
    return this._bufferedAmount;
  }

  get extensions(): string {
    return this._extensions;
  }

  get protocol(): string {
    return this._protocol;
  }

  get CONNECTING(): number {
    return WebSocketReadyState.CONNECTING;
  }

  get OPEN(): number {
    return WebSocketReadyState.OPEN;
  }

  get CLOSING(): number {
    return WebSocketReadyState.CLOSING;
  }

  get CLOSED(): number {
    return WebSocketReadyState.CLOSED;
  }

  // Static constants
  static get CONNECTING(): number {
    return WebSocketReadyState.CONNECTING;
  }

  static get OPEN(): number {
    return WebSocketReadyState.OPEN;
  }

  static get CLOSING(): number {
    return WebSocketReadyState.CLOSING;
  }

  static get CLOSED(): number {
    return WebSocketReadyState.CLOSED;
  }

  /** Remove the globalThis reference so this instance can be GC'd */
  private _cleanupGlobalRef(): void {
    const key = `_ws_${this._socketId}`;
    const existed = (globalThis as unknown as Record<string, unknown>)[key] !== undefined;
    delete (globalThis as unknown as Record<string, unknown>)[key];
    console.log(`[WebSocket] _cleanupGlobalRef() socketId=${this._socketId}, key=${key}, existed=${existed}`);
  }

  private async _initConnection(): Promise<void> {
    console.log(`[WebSocket] _initConnection() socketId=${this._socketId}, url=${this._url}`);
    try {
      if (typeof dartCallNativeAsync !== 'function') {
        throw new Error('dartCallNativeAsync is not available.');
      }

      // Register this socket instance globally so native can send events back
      const globalKey = `_ws_${this._socketId}`;
      (globalThis as unknown as Record<string, unknown>)[globalKey] = this;
      console.log(`[WebSocket] Registered on globalThis: ${globalKey}`);

      const result = (await dartCallNativeAsync('WebSocket.connect', {
        socketId: this._socketId,
        url: this._url,
        protocols: Array.isArray(this._protocols) ? this._protocols : [this._protocols],
      })) as { success: boolean; protocol?: string; extensions?: string; error?: string };

      console.log(`[WebSocket] connect result for socketId=${this._socketId}: success=${result.success}, error=${result.error}`);

      if (result.success) {
        this._readyState = WebSocketReadyState.OPEN;
        this._protocol = result.protocol ?? '';
        this._extensions = result.extensions ?? '';

        const openEvent = new Event('open');
        this.dispatchEvent(openEvent);
        if (this.onopen) {
          this.onopen(openEvent);
        }
      } else {
        this._readyState = WebSocketReadyState.CLOSED;
        console.warn(`[WebSocket] Connection failed for socketId=${this._socketId}: ${result.error}`);
        const errorEvent = new Event('error');
        this.dispatchEvent(errorEvent);
        if (this.onerror) {
          this.onerror(errorEvent);
        }

        const closeEvent = new CloseEvent('close', {
          code: 1006,
          reason: result.error ?? 'Connection failed',
          wasClean: false,
        });
        this.dispatchEvent(closeEvent);
        if (this.onclose) {
          this.onclose(closeEvent);
        }

        this._cleanupGlobalRef();
      }
    } catch (error) {
      this._readyState = WebSocketReadyState.CLOSED;
      console.error(`[WebSocket] Exception in _initConnection for socketId=${this._socketId}:`, error);
      const errorEvent = new Event('error');
      this.dispatchEvent(errorEvent);
      if (this.onerror) {
        this.onerror(errorEvent);
      }

      const closeEvent = new CloseEvent('close', {
        code: 1006,
        reason: error instanceof Error ? error.message : 'Connection failed',
        wasClean: false,
      });
      this.dispatchEvent(closeEvent);
      if (this.onclose) {
        this.onclose(closeEvent);
      }

      this._cleanupGlobalRef();
    }
  }

  // Called by native when a message is received
  _handleMessage(data: string | ArrayBuffer): void {
    if (this._readyState !== WebSocketReadyState.OPEN) {
      return;
    }

    const messageEvent = new MessageEvent('message', { data });
    this.dispatchEvent(messageEvent);
    if (this.onmessage) {
      this.onmessage(messageEvent);
    }
  }

  // Called by native when the connection is closed
  _handleClose(code: number, reason: string, wasClean: boolean): void {
    console.log(`[WebSocket] _handleClose() socketId=${this._socketId}, code=${code}, reason=${reason}, wasClean=${wasClean}`);
    this._readyState = WebSocketReadyState.CLOSED;

    const closeEvent = new CloseEvent('close', { code, reason, wasClean });
    this.dispatchEvent(closeEvent);
    if (this.onclose) {
      this.onclose(closeEvent);
    }

    // Clean up global reference
    this._cleanupGlobalRef();
  }

  // Called by native when an error occurs
  _handleError(): void {
    console.warn(`[WebSocket] _handleError() socketId=${this._socketId}, readyState=${this._readyState}`);
    const errorEvent = new Event('error');
    this.dispatchEvent(errorEvent);
    if (this.onerror) {
      this.onerror(errorEvent);
    }
  }

  send(data: string | ArrayBuffer | Blob | ArrayBufferView): void {
    if (this._readyState === WebSocketReadyState.CONNECTING) {
      throw new Error('WebSocket is not open: readyState 0 (CONNECTING)');
    }

    if (this._readyState !== WebSocketReadyState.OPEN) {
      // Silently fail if not open (per WebSocket spec)
      console.warn(`[WebSocket] send() called on non-OPEN socket socketId=${this._socketId}, state=${this._readyState}`);
      return;
    }

    let messageData: string;

    if (typeof data === 'string') {
      messageData = data;
    } else if (data instanceof ArrayBuffer) {
      // Convert ArrayBuffer to base64 string for transmission
      messageData = arrayBufferToBase64(data);
    } else if (ArrayBuffer.isView(data)) {
      // Handle TypedArrays and DataView
      const buffer = (data.buffer as ArrayBuffer).slice(data.byteOffset, data.byteOffset + data.byteLength);
      messageData = arrayBufferToBase64(buffer);
    } else {
      // For Blob, we would need to read it first, but for simplicity treat as string
      messageData = String(data);
    }

    this._bufferedAmount += messageData.length;

    // Send through native service
    dartCallNative('WebSocket.send', {
      socketId: this._socketId,
      data: messageData,
      isBinary: typeof data !== 'string',
    });

    this._bufferedAmount -= messageData.length;
  }

  close(code?: number, reason?: string): void {
    if (this._readyState === WebSocketReadyState.CLOSING || this._readyState === WebSocketReadyState.CLOSED) {
      console.log(`[WebSocket] close() called but already closing/closed socketId=${this._socketId}, state=${this._readyState}`);
      return;
    }

    console.log(`[WebSocket] close() socketId=${this._socketId}, code=${code ?? 1000}`);
    this._readyState = WebSocketReadyState.CLOSING;

    // Send close through native service
    dartCallNative('WebSocket.close', {
      socketId: this._socketId,
      code: code ?? 1000,
      reason: reason ?? '',
    });
  }

  // Override addEventListener to provide proper typing
  addEventListener<K extends keyof WebSocketEventMap>(type: K, listener: (event: WebSocketEventMap[K]) => void): void;
  addEventListener(type: string, listener: EventListener): void {
    super.addEventListener(type, listener as EventListener);
  }

  // Override removeEventListener to provide proper typing
  removeEventListener<K extends keyof WebSocketEventMap>(type: K, listener: (event: WebSocketEventMap[K]) => void): void;
  removeEventListener(type: string, listener: EventListener): void {
    super.removeEventListener(type, listener as EventListener);
  }
}

// Helper function to convert ArrayBuffer to base64
function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

// Helper function to convert base64 to ArrayBuffer
export function base64ToArrayBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
