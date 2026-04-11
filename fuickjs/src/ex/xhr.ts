import { EventTarget, Event } from './events';
import { NetworkService } from '../services/NetworkService';

export class XMLHttpRequest extends EventTarget {
  static readonly UNSENT = 0;
  static readonly OPENED = 1;
  static readonly HEADERS_RECEIVED = 2;
  static readonly LOADING = 3;
  static readonly DONE = 4;

  readyState: number = XMLHttpRequest.UNSENT;
  status: number = 0;
  statusText: string = '';
  responseText: string = '';
  response: any = null;
  responseType: XMLHttpRequestResponseType = '';
  timeout: number = 0;
  withCredentials: boolean = false;

  private _method: string = '';
  private _url: string = '';
  private _async: boolean = true;
  private _requestHeaders: Record<string, string> = {};
  private _requestId: string | null = null;
  private _aborted: boolean = false;

  // Events
  onreadystatechange: (() => void) | null = null;
  onload: (() => void) | null = null;
  onerror: (() => void) | null = null;
  onabort: (() => void) | null = null;
  ontimeout: (() => void) | null = null;
  onloadstart: (() => void) | null = null;
  onloadend: (() => void) | null = null;
  onprogress: (() => void) | null = null;

  constructor() {
    super();
  }

  open(method: string, url: string, async: boolean = true): void {
    this._method = method.toUpperCase();
    this._url = url;
    this._async = async;
    this._requestHeaders = {};
    this._aborted = false;
    this._changeReadyState(XMLHttpRequest.OPENED);
  }

  setRequestHeader(header: string, value: string): void {
    if (this.readyState !== XMLHttpRequest.OPENED) {
      throw new Error('DOMException: Failed to execute "setRequestHeader" on "XMLHttpRequest": The object\'s state must be OPENED.');
    }
    this._requestHeaders[header] = value;
  }

  send(body?: any): void {
    if (this.readyState !== XMLHttpRequest.OPENED) {
      throw new Error('DOMException: Failed to execute "send" on "XMLHttpRequest": The object\'s state must be OPENED.');
    }

    this._requestId = Math.random().toString(36).substring(2);
    this._aborted = false;

    this._dispatchEvent('loadstart');

    const doRequest = async () => {
      try {
        const result = await NetworkService.fetch(
          this._url,
          this._method,
          this._requestHeaders,
          typeof body === 'string' ? body : JSON.stringify(body),
          this._requestId!
        );

        if (this._aborted) return;

        this.status = result.status;
        this.statusText = result.status >= 200 && result.status < 300 ? 'OK' : 'Error';
        
        // Handle headers
        this._changeReadyState(XMLHttpRequest.HEADERS_RECEIVED);
        
        // Handle loading (simplified since we get the whole body at once)
        this._changeReadyState(XMLHttpRequest.LOADING);
        
        this.responseText = result.body;
        this._parseResponse();

        this._changeReadyState(XMLHttpRequest.DONE);
        this._dispatchEvent('load');
        this._dispatchEvent('loadend');
      } catch (e) {
        if (this._aborted) return;
        this._dispatchEvent('error');
        this._dispatchEvent('loadend');
      }
    };

    if (this._async) {
      doRequest();
    } else {
      // FuickJS bridge is async by nature, so sync XHR is not truly possible 
      // without blocking the JS thread which we don't want to do.
      console.warn('[XMLHttpRequest] Synchronous request is not supported in this environment, falling back to async.');
      doRequest();
    }
  }

  abort(): void {
    if (this._requestId && !this._aborted) {
      this._aborted = true;
      NetworkService.cancel(this._requestId);
      this._changeReadyState(XMLHttpRequest.DONE);
      this._dispatchEvent('abort');
      this._dispatchEvent('loadend');
    }
  }

  getAllResponseHeaders(): string {
    // Simplified: we don't store raw headers in current NetworkResponse
    return '';
  }

  getResponseHeader(header: string): string | null {
    // Simplified
    return null;
  }

  private _changeReadyState(state: number): void {
    this.readyState = state;
    if (this.onreadystatechange) {
      this.onreadystatechange();
    }
    this.dispatchEvent(new Event('readystatechange'));
  }

  private _dispatchEvent(type: string): void {
    const handler = (this as any)[`on${type}`];
    if (typeof handler === 'function') {
      handler();
    }
    this.dispatchEvent(new Event(type));
  }

  private _parseResponse(): void {
    if (this.responseType === 'json') {
      try {
        this.response = JSON.parse(this.responseText);
      } catch {
        this.response = null;
      }
    } else if (this.responseType === 'text' || this.responseType === '') {
      this.response = this.responseText;
    } else {
      // Other types like 'blob', 'arraybuffer' are not yet supported
      this.response = this.responseText;
    }
  }
}
