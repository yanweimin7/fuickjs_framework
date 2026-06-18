export class URLSearchParams {
  private params: Map<string, string[]> = new Map();

  constructor(init?: string | Record<string, string> | string[][] | URLSearchParams) {
    if (!init) return;

    if (typeof init === 'string') {
      if (init.startsWith('?')) init = init.slice(1);
      const pairs = init.split('&');
      for (const pair of pairs) {
        const [key, value] = pair.split('=').map(decodeURIComponent);
        this.append(key, value || '');
      }
    } else if (init instanceof URLSearchParams) {
      init.forEach((value, key) => this.append(key, value));
    } else if (Array.isArray(init)) {
      for (const [key, value] of init) {
        this.append(key, value);
      }
    } else {
      for (const key in init) {
        this.append(key, init[key]);
      }
    }
  }

  append(name: string, value: string): void {
    const values = this.params.get(name) || [];
    values.push(String(value));
    this.params.set(name, values);
  }

  delete(name: string): void {
    this.params.delete(name);
  }

  get(name: string): string | null {
    const values = this.params.get(name);
    return values ? values[0] : null;
  }

  getAll(name: string): string[] {
    return this.params.get(name) || [];
  }

  has(name: string): boolean {
    return this.params.has(name);
  }

  set(name: string, value: string): void {
    this.params.set(name, [String(value)]);
  }

  sort(): void {
    const keys = Array.from(this.params.keys()).sort();
    const newParams = new Map();
    for (const key of keys) {
      newParams.set(key, this.params.get(key));
    }
    this.params = newParams;
  }

  forEach(callback: (value: string, name: string, searchParams: URLSearchParams) => void): void {
    this.params.forEach((values, name) => {
      values.forEach((value) => callback(value, name, this));
    });
  }

  toString(): string {
    const pairs: string[] = [];
    this.params.forEach((values, name) => {
      values.forEach((value) => {
        pairs.push(`${encodeURIComponent(name)}=${encodeURIComponent(value)}`);
      });
    });
    return pairs.join('&');
  }

  [Symbol.iterator]() {
    const entries: [string, string][] = [];
    this.forEach((value, name) => entries.push([name, value]));
    return entries[Symbol.iterator]();
  }
}

export class URL {
  protocol: string = '';
  hostname: string = '';
  port: string = '';
  pathname: string = '/';
  search: string = '';
  hash: string = '';
  username: string = '';
  password: string = '';
  searchParams: URLSearchParams;

  constructor(url: string, base?: string | URL) {
    let absoluteUrl = url;
    if (base) {
      const baseUrl = base instanceof URL ? base.href : new URL(base).href;
      if (!url.includes('://')) {
        if (url.startsWith('/')) {
          const origin = baseUrl.split('/').slice(0, 3).join('/');
          absoluteUrl = origin + url;
        } else {
          const baseParts = baseUrl.split('/');
          baseParts.pop();
          absoluteUrl = baseParts.join('/') + '/' + url;
        }
      }
    }

    const regex =
      /^(?:([a-z0-9+.-]+):)?(?:\/\/)?(?:([^@:/]+)(?::([^@/]+))?@)?([^:/]+)?(?::([0-9]+))?([^?#]*)(\?[^#]*)?(#.*)?$/i;
    const match = absoluteUrl.match(regex);

    if (match) {
      this.protocol = match[1] ? match[1] + ':' : '';
      this.username = match[2] || '';
      this.password = match[3] || '';
      this.hostname = match[4] || '';
      this.port = match[5] || '';
      this.pathname = match[6] || '/';
      this.search = match[7] || '';
      this.hash = match[8] || '';
    }

    this.searchParams = new URLSearchParams(this.search);
  }

  get href(): string {
    let res = this.protocol + '//';
    if (this.username) {
      res += this.username;
      if (this.password) res += ':' + this.password;
      res += '@';
    }
    res += this.hostname;
    if (this.port) res += ':' + this.port;
    res += this.pathname;
    const searchStr = this.searchParams.toString();
    if (searchStr) res += '?' + searchStr;
    res += this.hash;
    return res;
  }

  set href(value: string) {
    const newUrl = new URL(value);
    Object.assign(this, newUrl);
  }

  get origin(): string {
    return `${this.protocol}//${this.hostname}${this.port ? ':' + this.port : ''}`;
  }

  get host(): string {
    return this.hostname + (this.port ? ':' + this.port : '');
  }

  set host(value: string) {
    const [hostname, port] = value.split(':');
    this.hostname = hostname;
    this.port = port || '';
  }

  toString(): string {
    return this.href;
  }

  toJSON(): string {
    return this.href;
  }
}
