export class LocalStorage {
  static getItem(key: string): Promise<string | null> {
    return dartCallNativeAsync('LocalStorage.getItem', [key]);
  }

  static setItem(key: string, value: string): Promise<boolean> {
    return dartCallNativeAsync('LocalStorage.setItem', [key, value]);
  }

  static removeItem(key: string): Promise<boolean> {
    return dartCallNativeAsync('LocalStorage.removeItem', [key]);
  }

  static clear(): Promise<boolean> {
    return dartCallNativeAsync('LocalStorage.clear', []);
  }
}
