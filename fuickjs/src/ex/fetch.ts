import { NetworkService } from '../services/NetworkService';

export interface FetchOptions {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
}

export interface FetchResponse {
  status: number;
  ok: boolean;
  headers: Record<string, string>;
  text(): Promise<string>;
  json(): Promise<unknown>;
}

export async function fetch(url: string, options: FetchOptions = {}): Promise<FetchResponse> {
  const result = await NetworkService.fetch(url, options.method || 'GET', options.headers || {}, options.body);

  return {
    status: result.status,
    ok: result.status >= 200 && result.status < 300,
    headers: result.headers,
    text: async () => result.body,
    json: async () => JSON.parse(result.body),
  };
}

if (typeof globalThis !== 'undefined') {
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  globalThis.fetch = fetch;
}
