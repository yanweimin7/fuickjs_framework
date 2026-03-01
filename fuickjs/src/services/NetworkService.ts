declare let dartCallNativeAsync: (method: string, args: unknown) => Promise<unknown>;

export interface NetworkResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
}

export class NetworkService {
  static async fetch(
    url: string,
    method: string,
    headers: Record<string, string>,
    body?: string,
    requestId?: string,
  ): Promise<NetworkResponse> {
    if (typeof dartCallNativeAsync !== 'function') {
      throw new Error('dartCallNativeAsync is not available.');
    }
    return (await dartCallNativeAsync('Network.fetch', {
      url,
      method,
      headers,
      body,
      requestId,
    })) as NetworkResponse;
  }

  static cancel(requestId: string): void {
    dartCallNative('Network.cancel', { requestId });
  }
}
