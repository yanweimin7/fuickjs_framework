/**
 * crypto.getRandomValues / randomUUID polyfill
 * 必须在 crypto-js IIFE 初始化之前执行，否则 CryptoJS 内部的
 * cryptoSecureRandomInt 会因找不到 crypto 对象而抛出异常。
 *
 * 此文件不依赖 crypto-js，确保在模块图中排在 CryptoJS 之前。
 */
import globalAny from './global';

if (!(globalAny as any).crypto) {
  (globalAny as any).crypto = {} as Crypto;
}

if (!(globalAny as any).crypto?.getRandomValues) {
  (globalAny as any).crypto.getRandomValues = function <T extends ArrayBufferView>(array: T): T {
    const bytes = new Uint8Array(array.byteLength);
    for (let i = 0; i < bytes.length; i++) {
      bytes[i] = Math.floor(Math.random() * 256);
    }
    if (array instanceof Uint8Array) {
      array.set(bytes);
      return array;
    }
    const view = new Uint8Array(array.buffer, array.byteOffset, array.byteLength);
    view.set(bytes);
    return array;
  };
}

if (!(globalAny as any).crypto?.randomUUID) {
  (globalAny as any).crypto.randomUUID = function randomUUID(): string {
    // RFC 4122 v4: 基于 getRandomValues 的 16 字节随机数
    const bytes = new Uint8Array(16);
    (globalAny as any).crypto.getRandomValues(bytes);
    // 设置版本号（v4）和 variant（10xx）
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex: string[] = [];
    for (let i = 0; i < 16; i++) hex.push(bytes[i].toString(16).padStart(2, '0'));
    return (
      hex.slice(0, 4).join('') +
      '-' +
      hex.slice(4, 6).join('') +
      '-' +
      hex.slice(6, 8).join('') +
      '-' +
      hex.slice(8, 10).join('') +
      '-' +
      hex.slice(10, 16).join('')
    );
  };
}
