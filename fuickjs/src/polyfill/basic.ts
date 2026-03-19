// eslint-disable-next-line @typescript-eslint/no-explicit-any
const globalAny = globalThis as any;

if (!globalAny.process) {
  globalAny.process = {
    env: { NODE_ENV: 'production' },
    version: 'v16.0.0',
    nextTick: (cb: () => void) => setTimeout(cb, 0),
    browser: false,
  };
}

if (!globalAny.Buffer) {
  globalAny.Buffer = {
    isBuffer: () => false,
    from: (arr: ArrayLike<number>) => new Uint8Array(arr),
    alloc: (size: number) => new Uint8Array(size),
    concat: (arrs: ArrayLike<Uint8Array>[]) => {
      let len = 0;
      for (let i = 0; i < arrs.length; i++) len += arrs[i].length;
      const res = new Uint8Array(len);
      let offset = 0;
      for (let i = 0; i < arrs.length; i++) {
        (res as any).set(arrs[i], offset);
        offset += arrs[i].length;
      }
      return res;
    },
  };
}

if (!globalAny.crypto) {
  globalAny.crypto = {} as Crypto;
}

if (!globalAny.crypto?.getRandomValues) {
  globalAny.crypto.getRandomValues = function <T extends ArrayBufferView>(array: T): T {
    const bytes = new Uint8Array(array.byteLength);
    for (let i = 0; i < bytes.length; i++) {
      bytes[i] = Math.floor(Math.random() * 256);
    }
    if (array instanceof Uint8Array) {
      array.set(bytes);
      return array;
    }
    const view = new Uint8Array(array.buffer, array.byteOffset, array.byteLength);
    view.set(bytes);
    return array;
  };
}

if (typeof globalAny.queueMicrotask === 'undefined') {
  globalAny.queueMicrotask = function queueMicrotask(callback: () => void) {
    Promise.resolve().then(callback);
  };
}

if (typeof TextEncoder === 'undefined') {
  globalAny.TextEncoder = class TextEncoder {
    encode(str: string): Uint8Array {
      const arr: number[] = [];
      for (let i = 0; i < str.length; i++) {
        let code = str.charCodeAt(i);
        if (code < 0x80) {
          arr.push(code);
        } else if (code < 0x800) {
          arr.push(0xc0 | (code >> 6));
          arr.push(0x80 | (code & 0x3f));
        } else if (code < 0xd800 || code >= 0xe000) {
          arr.push(0xe0 | (code >> 12));
          arr.push(0x80 | ((code >> 6) & 0x3f));
          arr.push(0x80 | (code & 0x3f));
        } else {
          i++;
          code = 0x10000 + (((code & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
          arr.push(0xf0 | (code >> 18));
          arr.push(0x80 | ((code >> 12) & 0x3f));
          arr.push(0x80 | ((code >> 6) & 0x3f));
          arr.push(0x80 | (code & 0x3f));
        }
      }
      return new Uint8Array(arr);
    }
  };
}

if (typeof TextDecoder === 'undefined') {
  globalAny.TextDecoder = class TextDecoder {
    decode(arr: Uint8Array): string {
      let str = '';
      for (let i = 0; i < arr.length; i++) {
        str += String.fromCharCode(arr[i]);
      }
      try {
        return decodeURIComponent(escape(str));
      } catch {
        return str;
      }
    }
  };
}

if (typeof globalAny.queueMicrotask === 'undefined') {
  globalAny.queueMicrotask = function queueMicrotask(callback: () => void) {
    Promise.resolve().then(callback);
  };
}
