declare module 'stream-browserify' {
  import { EventEmitter } from 'events';

  class Stream extends EventEmitter {
    pipe<T extends NodeJS.WritableStream>(destination: T, options?: { end?: boolean }): T;
  }

  class Readable extends Stream {
    readable: boolean;
    read(size?: number): string | Buffer;
    setEncoding(encoding: BufferEncoding): this;
    pause(): this;
    resume(): this;
    isPaused(): boolean;
    pipe<T extends NodeJS.WritableStream>(destination: T, options?: { end?: boolean }): T;
    unpipe(destination?: NodeJS.WritableStream): this;
    unshift(chunk: string | Buffer, encoding?: BufferEncoding): void;
    wrap(oldStream: NodeJS.ReadableStream): this;
    [Symbol.asyncIterator](): AsyncIterableIterator<string | Buffer>;
  }

  class Writable extends Stream {
    writable: boolean;
    write(chunk: string | Buffer, encoding?: BufferEncoding, cb?: (error: Error | null) => void): boolean;
    write(chunk: string | Buffer, cb?: (error: Error | null) => void): boolean;
    end(cb?: () => void): void;
    end(chunk: string | Buffer, cb?: () => void): void;
    end(chunk: string | Buffer, encoding?: BufferEncoding, cb?: () => void): void;
  }

  class Duplex extends Readable {
    writable: boolean;
    write(chunk: string | Buffer, encoding?: BufferEncoding, cb?: (error: Error | null) => void): boolean;
    write(chunk: string | Buffer, cb?: (error: Error | null) => void): boolean;
    end(cb?: () => void): void;
    end(chunk: string | Buffer, cb?: () => void): void;
    end(chunk: string | Buffer, encoding?: BufferEncoding, cb?: () => void): void;
  }

  class Transform extends Duplex {
    _transform(chunk: string | Buffer, encoding: BufferEncoding, callback: (error?: Error | null) => void): void;
    _flush(callback: (error?: Error | null) => void): void;
  }

  export { Stream, Readable, Writable, Duplex, Transform };
}
