import { ConsoleService } from '../services/ConsoleService';

function formatArg(arg: unknown): string {
  if (arg instanceof Error) {
    const stack = arg.stack || '';
    const msg = arg.message || String(arg);
    const name = arg.name || 'Error';

    // 如果 stack 已经包含消息（某些 JS 引擎行为），直接返回
    if (stack.indexOf(msg) !== -1) {
      return stack;
    }

    // 否则拼接：Name: Message \n Stack
    return `${name}: ${msg}\n${stack}`;
  }
  if (arg !== null && typeof arg === 'object') {
    try {
      return JSON.stringify(arg);
    } catch {
      return String(arg);
    }
  }
  return String(arg);
}

export function log(...args: unknown[]) {
  const message = args.map(formatArg).join(' ');
  try {
    ConsoleService.log(message);
  } catch {
    const globalObj = globalThis as unknown as { print?: (msg: string) => void };
    if (typeof globalObj.print === 'function') {
      globalObj.print(message);
    }
  }
}

export function warn(...args: unknown[]) {
  const message = args.map(formatArg).join(' ');
  try {
    ConsoleService.warn(message);
  } catch {
    const globalObj = globalThis as unknown as { print?: (msg: string) => void };
    if (typeof globalObj.print === 'function') {
      globalObj.print('[WARN] ' + message);
    }
  }
}

export function error(...args: unknown[]) {
  const message = args.map(formatArg).join(' ');
  try {
    ConsoleService.error(message);
  } catch {
    const globalObj = globalThis as unknown as { print?: (msg: string) => void };
    if (typeof globalObj.print === 'function') {
      globalObj.print('[ERROR] ' + message);
    }
  }
}

export function info(...args: unknown[]) {
  log(...args);
}

export function debug(...args: unknown[]) {
  log(...args);
}

export function trace() {
  const err = new Error();
  log('Console Trace:', err.stack);
}

export function clear() {
  // Not implemented in native yet, but provide the method
  log('[Console] clear called');
}

const _timers: Map<string, number> = new Map();

export function time(label = 'default') {
  _timers.set(String(label), Date.now());
}

export function timeLog(label = 'default', ...args: unknown[]) {
  const start = _timers.get(String(label));
  if (start === undefined) {
    warn(`Timer '${label}' does not exist`);
    return;
  }
  log(`${label}: ${Date.now() - start}ms`, ...args);
}

export function timeEnd(label = 'default') {
  const start = _timers.get(String(label));
  if (start === undefined) {
    warn(`Timer '${label}' does not exist`);
    return;
  }
  _timers.delete(String(label));
  log(`${label}: ${Date.now() - start}ms`);
}

let _groupIndent = 0;

export function group(...args: unknown[]) {
  if (args.length > 0) log(...args);
  _groupIndent++;
}

export function groupCollapsed(...args: unknown[]) {
  group(...args);
}

export function groupEnd() {
  if (_groupIndent > 0) _groupIndent--;
}

export function table(data: unknown, columns?: string[]) {
  if (data == null || typeof data !== 'object') {
    log(data);
    return;
  }

  const isArray = Array.isArray(data);
  const rows = isArray
    ? (data as unknown[]).map((v, i) => [String(i), v] as const)
    : Object.entries(data as Record<string, unknown>);

  if (rows.length === 0) {
    log(isArray ? '[]' : '{}');
    return;
  }

  // 收集列名
  let cols: string[];
  if (columns && columns.length > 0) {
    cols = columns.slice();
  } else {
    const keySet = new Set<string>();
    let hasScalar = false;
    for (const [, value] of rows) {
      if (value !== null && typeof value === 'object') {
        for (const k of Object.keys(value as Record<string, unknown>)) keySet.add(k);
      } else {
        hasScalar = true;
      }
    }
    cols = Array.from(keySet);
    if (hasScalar || cols.length === 0) cols.unshift('Values');
  }

  const indexHeader = isArray ? '(index)' : '(key)';
  const headers = [indexHeader, ...cols];

  const formatCell = (v: unknown): string => {
    if (v === undefined) return '';
    if (v === null) return 'null';
    if (typeof v === 'object') {
      try {
        return JSON.stringify(v);
      } catch {
        return String(v);
      }
    }
    return String(v);
  };

  const tableRows: string[][] = rows.map(([key, value]) => {
    const row: string[] = [String(key)];
    for (const col of cols) {
      if (col === 'Values') {
        row.push(value !== null && typeof value === 'object' ? '' : formatCell(value));
      } else if (value !== null && typeof value === 'object') {
        row.push(formatCell((value as Record<string, unknown>)[col]));
      } else {
        row.push('');
      }
    }
    return row;
  });

  const widths = headers.map((h, i) => Math.max(h.length, ...tableRows.map((r) => r[i].length)));
  const pad = (s: string, w: number) => s + ' '.repeat(Math.max(0, w - s.length));
  const sep = '+' + widths.map((w) => '-'.repeat(w + 2)).join('+') + '+';
  const fmtRow = (r: string[]) => '| ' + r.map((c, i) => pad(c, widths[i])).join(' | ') + ' |';

  const lines = [sep, fmtRow(headers), sep, ...tableRows.map(fmtRow), sep];
  log(lines.join('\n'));
}
