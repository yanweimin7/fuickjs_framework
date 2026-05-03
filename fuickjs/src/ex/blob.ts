export type BlobPart = string | ArrayBuffer | ArrayBufferView | Blob;

export interface BlobPropertyBag {
  type?: string;
  endings?: 'transparent' | 'native';
}

export class Blob {
  private _buffer: Uint8Array;
  readonly type: string;

  constructor(parts: BlobPart[] = [], options: BlobPropertyBag = {}) {
    this.type = (options.type ?? '').toLowerCase();
    this._buffer = Blob._concat(parts);
  }

  get size(): number {
    return this._buffer.byteLength;
  }

  slice(start?: number, end?: number, contentType?: string): Blob {
    const len = this._buffer.byteLength;
    let s = start ?? 0;
    let e = end ?? len;
    if (s < 0) s = Math.max(len + s, 0);
    if (e < 0) e = Math.max(len + e, 0);
    s = Math.min(s, len);
    e = Math.min(e, len);
    const sliced = this._buffer.slice(s, e);
    const b = new Blob([], { type: contentType ?? this.type });
    (b as any)._buffer = sliced;
    return b;
  }

  async arrayBuffer(): Promise<ArrayBuffer> {
    return this._buffer.buffer.slice(
      this._buffer.byteOffset,
      this._buffer.byteOffset + this._buffer.byteLength,
    ) as ArrayBuffer;
  }

  async text(): Promise<string> {
    const bytes = this._buffer;
    let str = '';
    for (let i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
    try {
      return decodeURIComponent(escape(str));
    } catch {
      return str;
    }
  }

  stream(): ReadableStream {
    throw new Error('Blob.stream() is not supported in this environment');
  }

  toString(): string {
    return '[object Blob]';
  }

  // 供内部和 File 子类访问原始字节
  _bytes(): Uint8Array {
    return this._buffer;
  }

  private static _concat(parts: BlobPart[]): Uint8Array {
    const buffers: Uint8Array[] = parts.map((part) => {
      if (typeof part === 'string') {
        return Blob._encodeUtf8(part);
      }
      if (part instanceof Blob) {
        return part._buffer;
      }
      if (part instanceof ArrayBuffer) {
        return new Uint8Array(part);
      }
      if (ArrayBuffer.isView(part)) {
        return new Uint8Array(part.buffer, part.byteOffset, part.byteLength);
      }
      return new Uint8Array(0);
    });

    const totalLen = buffers.reduce((n, b) => n + b.byteLength, 0);
    const result = new Uint8Array(totalLen);
    let offset = 0;
    for (const buf of buffers) {
      result.set(buf, offset);
      offset += buf.byteLength;
    }
    return result;
  }

  private static _encodeUtf8(str: string): Uint8Array {
    const arr: number[] = [];
    for (let i = 0; i < str.length; i++) {
      let code = str.charCodeAt(i);
      if (code < 0x80) {
        arr.push(code);
      } else if (code < 0x800) {
        arr.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      } else if (code < 0xd800 || code >= 0xe000) {
        arr.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      } else {
        i++;
        code = 0x10000 + (((code & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
        arr.push(
          0xf0 | (code >> 18),
          0x80 | ((code >> 12) & 0x3f),
          0x80 | ((code >> 6) & 0x3f),
          0x80 | (code & 0x3f),
        );
      }
    }
    return new Uint8Array(arr);
  }
}
