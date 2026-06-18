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
    if (typeof dartCallNative === 'function') {
      dartCallNative('Network.cancel', { requestId });
    }
  }

  static async uploadFile(
    url: string,
    filePath: string,
    name: string,
    header?: Record<string, string>,
    formData?: Record<string, string>,
  ): Promise<{ statusCode: number; data: string }> {
    return (await dartCallNativeAsync('Network.uploadFile', {
      url,
      filePath,
      name,
      header,
      formData,
    })) as { statusCode: number; data: string };
  }

  static async downloadFile(
    url: string,
    filePath: string,
    header?: Record<string, string>,
  ): Promise<{ statusCode: number; tempFilePath: string }> {
    return (await dartCallNativeAsync('Network.downloadFile', {
      url,
      filePath,
      header,
    })) as { statusCode: number; tempFilePath: string };
  }
}
