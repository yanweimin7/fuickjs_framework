if (typeof TextEncoder === "undefined") {
  class TextEncoderPolyfill {
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
          // Surrogate pair
          i++;
          code =
            0x10000 + (((code & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
          arr.push(0xf0 | (code >> 18));
          arr.push(0x80 | ((code >> 12) & 0x3f));
          arr.push(0x80 | ((code >> 6) & 0x3f));
          arr.push(0x80 | (code & 0x3f));
        }
      }
      return new Uint8Array(arr);
    }
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (globalThis as any).TextEncoder = TextEncoderPolyfill;
}

if (typeof TextDecoder === "undefined") {
  class TextDecoderPolyfill {
    decode(arr: Uint8Array): string {
      let str = '';
      for (let i = 0; i < arr.length; i++) {
        str += String.fromCharCode(arr[i]);
      }
      try {
        return decodeURIComponent(escape(str));
      } catch (e) {
        return str;
      }
    }
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (globalThis as any).TextDecoder = TextDecoderPolyfill;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
if (typeof (globalThis as any).process === "undefined") {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (globalThis as any).process = {
    env: { NODE_ENV: 'production' },
    version: 'v16.0.0',
    nextTick: (cb: any) => setTimeout(cb, 0)
  };
}
