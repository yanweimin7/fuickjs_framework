import { ConsoleService } from '../services/ConsoleService';

export function log(...args: unknown[]) {
  const message = args.map((a) => String(a)).join(' ');
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
  const message = args.map((a) => String(a)).join(' ');
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
  const message = args.map((a) => String(a)).join(' ');
  try {
    ConsoleService.error(message);
  } catch {
    const globalObj = globalThis as unknown as { print?: (msg: string) => void };
    if (typeof globalObj.print === 'function') {
      globalObj.print('[ERROR] ' + message);
    }
  }
}
