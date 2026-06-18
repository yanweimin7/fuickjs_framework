const globalAny = globalThis as any;

// 默认不设超时：部分操作（如 Navigator.push 等页面关闭才返回）耗时不可预期。
// 调用方可显式传第三个参数 timeoutMs 设自定义超时。
const DEFAULT_TIMEOUT_MS = 0;

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
