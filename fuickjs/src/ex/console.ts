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
