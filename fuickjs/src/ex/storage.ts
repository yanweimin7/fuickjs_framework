import { LocalStorageService } from '../services/LocalStorageService';

export class Storage {
  private data: Map<string, string> = new Map();
  private type: 'local' | 'session';

  constructor(type: 'local' | 'session') {
    this.type = type;
    if (type === 'local') {
      // Try to preload some data if needed, but standard localStorage is sync
      // For now, we'll just use the memory map and persist changes
    }
  }

  getItem(key: string): string | null {
    return this.data.get(String(key)) || null;
  }

  setItem(key: string, value: string): void {
    const sKey = String(key);
    const sValue = String(value);
    this.data.set(sKey, sValue);
    if (this.type === 'local') {
      LocalStorageService.setItem(sKey, sValue);
    }
  }

  removeItem(key: string): void {
    const sKey = String(key);
    this.data.delete(sKey);
    if (this.type === 'local') {
      LocalStorageService.removeItem(sKey);
    }
  }

  clear(): void {
    this.data.clear();
    if (this.type === 'local') {
      LocalStorageService.clear();
    }
  }

  get length(): number {
    return this.data.size;
  }

  key(index: number): string | null {
    const keys = Array.from(this.data.keys());
    return keys[index] || null;
  }
}

export const localStorage = new Storage('local');
export const sessionStorage = new Storage('session');
