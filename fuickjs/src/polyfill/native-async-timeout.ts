const globalAny = globalThis as any;

const DEFAULT_TIMEOUT_MS = 30_000;

const originalDartCallNativeAsync = globalAny.dartCallNativeAsync;

if (typeof originalDartCallNativeAsync === 'function') {
  globalAny.dartCallNativeAsync = function dartCallNativeAsyncWithTimeout<T = unknown>(
    method: string,
    args: unknown,
    timeoutMs: number = DEFAULT_TIMEOUT_MS,
  ): Promise<T> {
    const promise = originalDartCallNativeAsync.call(globalAny, method, args) as Promise<T>;
    if (!(timeoutMs > 0) || !promise || typeof (promise as any).then !== 'function') {
      return promise;
    }
    let timer: any;
    const timeoutPromise = new Promise<T>((_, reject) => {
      timer = setTimeout(() => {
        reject(new Error(`dartCallNativeAsync("${method}") timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    });
    return Promise.race([promise, timeoutPromise]).finally(() => {
      if (timer != null) clearTimeout(timer);
    }) as Promise<T>;
  };
}
