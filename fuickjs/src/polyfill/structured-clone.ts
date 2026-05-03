import globalAny from './global';

function clone<T>(value: T, seen: Map<unknown, unknown>): T {
  if (value === null || typeof value !== 'object') return value;

  if (seen.has(value)) return seen.get(value) as T;

  if (value instanceof Date) {
    return new Date(value.getTime()) as unknown as T;
  }

  if (value instanceof RegExp) {
    return new RegExp(value.source, value.flags) as unknown as T;
  }

  if (value instanceof ArrayBuffer) {
    const copy = value.slice(0);
    seen.set(value, copy);
    return copy as unknown as T;
  }

  if (ArrayBuffer.isView(value)) {
    const src = value as unknown as ArrayBufferView;
    const bufCopy = (src.buffer as ArrayBuffer).slice(src.byteOffset, src.byteOffset + src.byteLength);
    const Ctor = (value as any).constructor as new (buf: ArrayBuffer) => T;
    const copy = new Ctor(bufCopy);
    seen.set(value, copy);
    return copy;
  }

  if (value instanceof Map) {
    const copy: Map<unknown, unknown> = new Map();
    seen.set(value, copy);
    for (const [k, v] of value) copy.set(clone(k, seen), clone(v, seen));
    return copy as unknown as T;
  }

  if (value instanceof Set) {
    const copy: Set<unknown> = new Set();
    seen.set(value, copy);
    for (const v of value) copy.add(clone(v, seen));
    return copy as unknown as T;
  }

  if (Array.isArray(value)) {
    const copy: unknown[] = [];
    seen.set(value, copy);
    for (let i = 0; i < value.length; i++) copy[i] = clone(value[i], seen);
    return copy as unknown as T;
  }

  // 普通对象
  const copy = Object.create(Object.getPrototypeOf(value));
  seen.set(value, copy);
  for (const key of Object.keys(value as object)) {
    copy[key] = clone((value as Record<string, unknown>)[key], seen);
  }
  return copy as T;
}

if (typeof (globalAny as any).structuredClone === 'undefined') {
  (globalAny as any).structuredClone = function structuredClone<T>(value: T): T {
    return clone(value, new Map());
  };
}
