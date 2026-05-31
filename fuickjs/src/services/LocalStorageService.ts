interface PendingWrite {
  key: string;
  value: string;
  resolve: (ok: boolean) => void;
  reject: (err: unknown) => void;
}

// 同一 microtask 内多次 setItem 合并为一次 native 调用，减少 SharedPreferences IO 次数。
// 每次 setItem 仍返回各自的 Promise，按批次结果统一 resolve。
let pendingWrites: PendingWrite[] | null = null;

function flushWrites() {
  const batch = pendingWrites;
  pendingWrites = null;
  if (!batch || batch.length === 0) return;

  // 同一 key 多次写入只保留最后一次发往 Native，但所有 Promise 都按最终结果 resolve。
  const seenKeys = new Map<string, PendingWrite>();
  for (const item of batch) {
    seenKeys.set(item.key, item);
  }
  const entries = Array.from(seenKeys.values()).map((w) => [w.key, w.value]);

  dartCallNativeAsync('LocalStorage.setBatch', [entries])
    .then((ok) => {
      const result = ok === true || ok === undefined; // setBatch 在旧 Native 上不存在时回退由调用方处理
      for (const item of batch) item.resolve(result);
    })
    .catch((err) => {
      for (const item of batch) item.reject(err);
    });
}

export class LocalStorageService {
  static getItem(key: string): Promise<string | null> {
    return dartCallNativeAsync('LocalStorage.getItem', [key]);
  }

  static setItem(key: string, value: string): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      if (pendingWrites === null) {
        pendingWrites = [];
        // microtask 调度：当前同步代码段结束后立即 flush。
        Promise.resolve().then(flushWrites);
      }
      pendingWrites.push({ key, value, resolve, reject });
    });
  }

  static removeItem(key: string): Promise<boolean> {
    return dartCallNativeAsync('LocalStorage.removeItem', [key]);
  }

  static clear(): Promise<boolean> {
    return dartCallNativeAsync('LocalStorage.clear', []);
  }
}
