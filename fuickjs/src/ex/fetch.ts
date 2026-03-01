import { NetworkService } from '../services/NetworkService';
import { AbortSignal } from './abort';

export interface FetchOptions {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  signal?: AbortSignal;
}

export interface FetchResponse {
  status: number;
  ok: boolean;
  headers: Record<string, string>;
  text(): Promise<string>;
  json(): Promise<unknown>;
}

export async function fetch(url: string, options: FetchOptions = {}): Promise<FetchResponse> {
  const { signal } = options;

  if (signal?.aborted) {
    throw signal.reason || new Error('AbortError');
  }

  const requestId = Math.random().toString(36).substring(2);
  const fetchPromise = NetworkService.fetch(url, options.method || 'GET', options.headers || {}, options.body, requestId);

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
  return {
    status: result.status,
    ok: result.status >= 200 && result.status < 300,
    headers: result.headers,
    text: async () => result.body,
    json: async () => JSON.parse(result.body),
  };
}
