export class Headers {
  private headers: Map<string, string> = new Map();

  constructor(init?: Record<string, string> | Array<[string, string]>) {
    if (init) {
      if (Array.isArray(init)) {
        init.forEach(([key, value]) => {
          this.headers.set(key.toLowerCase(), value);
        });
      } else {
        Object.entries(init).forEach(([key, value]) => {
          this.headers.set(key.toLowerCase(), value);
        });
      }
    }
  }

  get(name: string): string | null {
    return this.headers.get(name.toLowerCase()) ?? null;
  }

  set(name: string, value: string): void {
    this.headers.set(name.toLowerCase(), value);
  }

  has(name: string): boolean {
    return this.headers.has(name.toLowerCase());
  }

  delete(name: string): boolean {
    return this.headers.delete(name.toLowerCase());
  }

  forEach(callback: (value: string, key: string) => void): void {
    this.headers.forEach((value, key) => {
      callback(value, key);
    });
  }

  entries(): IterableIterator<[string, string]> {
    return this.headers.entries();
  }

  keys(): IterableIterator<string> {
    return this.headers.keys();
  }

  values(): IterableIterator<string> {
    return this.headers.values();
  }

  [Symbol.iterator](): IterableIterator<[string, string]> {
    return this.headers.entries();
  }
}
