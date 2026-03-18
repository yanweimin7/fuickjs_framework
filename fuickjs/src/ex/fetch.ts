import { NetworkService } from '../services/NetworkService';
import { AbortSignal } from './abort';
import { Headers } from './headers';

export interface FetchOptions {
  method?: string;
  headers?: Record<string, string> | Headers;
  body?: string | ArrayBuffer;
  signal?: AbortSignal;
}

export interface FetchResponse {
  status: number;
  ok: boolean;
  headers: Headers;
  text(): Promise<string>;
  json(): Promise<unknown>;
  arrayBuffer(): Promise<ArrayBuffer>;
}

function headersToObject(headers: any): Record<string, string> {
  if (!headers) return {};
  if (headers instanceof Headers) {
    const obj: Record<string, string> = {};
    headers.forEach((value, key) => {
      obj[key] = value;
    });
    return obj;
  }
  if (typeof headers === 'object') {
    return headers as Record<string, string>;
  }
  return {};
}

function bodyToString(body: any): string {
  if (!body) return '';
  if (typeof body === 'string') return body;
  if (body instanceof ArrayBuffer) {
    const bytes = new Uint8Array(body);
    let result = '';
    for (let i = 0; i < bytes.length; i++) {
      result += String.fromCharCode(bytes[i]);
    }
    return result;
  }
  if (ArrayBuffer.isView(body)) {
    const bytes = new Uint8Array(body.buffer, body.byteOffset, body.byteLength);
    let result = '';
    for (let i = 0; i < bytes.length; i++) {
      result += String.fromCharCode(bytes[i]);
    }
    return result;
  }
  return String(body);
}

export async function fetch(url: string, options: FetchOptions = {}): Promise<FetchResponse> {
  const { signal } = options;

  if (signal?.aborted) {
    throw signal.reason || new Error('AbortError');
  }

  const requestId = Math.random().toString(36).substring(2);
  const headers = headersToObject(options.headers);
  const body = bodyToString(options.body);

  const fetchPromise = NetworkService.fetch(url, options.method ?? 'GET', headers, body, requestId);

  if (!signal) {
    const result = await fetchPromise;
    return createResponse(result);
  }

  return new Promise((resolve, reject) => {
    const abortHandler = () => {
      NetworkService.cancel(requestId);
      reject(signal.reason || new Error('AbortError'));
    };

    signal.addEventListener('abort', abortHandler);

    fetchPromise
      .then((result) => {
        signal.removeEventListener('abort', abortHandler);
        resolve(createResponse(result));
      })
      .catch((err) => {
        signal.removeEventListener('abort', abortHandler);
        reject(err);
      });
  });
}

function createResponse(result: any): FetchResponse {
  const textEncoder = new TextEncoder();
  let bodyText: string;
  if (typeof result.body === 'string') {
    bodyText = result.body;
  } else if (result.body instanceof ArrayBuffer) {
    const decoder = new TextDecoder();
    bodyText = decoder.decode(result.body);
  } else if (result.body) {
    bodyText = JSON.stringify(result.body);
  } else {
    bodyText = '';
  }
  const encoded = textEncoder.encode(bodyText);

  const headersObj = result.headers || {};
  const headersInstance = new Headers();
  Object.entries(headersObj).forEach(([key, value]) => {
    headersInstance.set(key, value as string);
  });

  return {
    status: result.status,
    ok: result.status >= 200 && result.status < 300,
    headers: headersInstance,
    text: async () => bodyText,
    json: async () => {
      try {
        return JSON.parse(bodyText);
      } catch (e) {
        console.error('[fetch] JSON parse error:', e, 'bodyText:', bodyText);
        throw e;
      }
    },
    arrayBuffer: async () => encoded.buffer,
  };
}
