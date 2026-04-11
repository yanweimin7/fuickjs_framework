import CryptoJS from 'crypto-js';
import globalAny from './global';

type AlgorithmIdentifier = string | { name: string };
type KeyFormat = 'raw' | 'pkcs8' | 'spki' | 'jwk';
type KeyType = 'public' | 'private' | 'secret';
type KeyUsage = 'encrypt' | 'decrypt' | 'sign' | 'verify' | 'deriveKey' | 'deriveBits' | 'wrapKey' | 'unwrapKey';

interface CryptoKey {
  type: KeyType;
  extractable: boolean;
  algorithm: object;
  usages: KeyUsage[];
  _keyData?: Uint8Array;
  _algorithm?: string;
}

const CJ: any = CryptoJS;

function createCryptoKey(
  type: KeyType,
  algorithm: object,
  extractable: boolean,
  usages: KeyUsage[],
  keyData?: Uint8Array,
  algoName?: string,
): CryptoKey {
  return {
    type,
    extractable,
    algorithm,
    usages,
    _keyData: keyData,
    _algorithm: algoName,
  };
}

function notImplemented(methodName: string): never {
  throw new Error(`crypto.subtle.${methodName} is not implemented in polyfill`);
}

function hexToBytes(hexStr: string): Uint8Array {
  const bytes = new Uint8Array(hexStr.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hexStr.substring(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

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

if (!(globalAny as any).crypto?.subtle) {
  (globalAny as any).crypto.subtle = {
    async digest(algorithm: AlgorithmIdentifier, data: ArrayBuffer): Promise<ArrayBuffer> {
      const algoName = typeof algorithm === 'string' ? algorithm : algorithm.name;
      const wordArray = CJ.lib.WordArray.create(new Uint8Array(data));
      let result;
      if (algoName === 'SHA-256') {
        result = CJ.SHA256(wordArray);
      } else if (algoName === 'SHA-512') {
        result = CJ.SHA512(wordArray);
      } else if (algoName === 'SHA-1') {
        result = CJ.SHA1(wordArray);
      } else if (algoName === 'SHA-384') {
        result = CJ.SHA384(wordArray);
      } else {
        result = CJ.SHA256(wordArray);
      }
      return hexToBytes(result.toString(CJ.enc.Hex)).buffer as ArrayBuffer;
    },

    async importKey(
      format: KeyFormat,
      keyData: ArrayBuffer | JsonWebKey,
      algorithm: AlgorithmIdentifier,
      extractable: boolean,
      keyUsages: KeyUsage[],
    ): Promise<CryptoKey> {
      const algoName = typeof algorithm === 'string' ? algorithm : (algorithm as { name: string }).name;

      if (format === 'raw' && keyData instanceof ArrayBuffer) {
        const keyBytes = new Uint8Array(keyData);
        if (algoName === 'PBKDF2') {
          return createCryptoKey('secret', { name: 'PBKDF2' }, extractable, keyUsages, keyBytes, algoName);
        }
        if (algoName === 'HKDF') {
          return createCryptoKey('secret', { name: 'HKDF' }, extractable, keyUsages, keyBytes, algoName);
        }
        if (algoName === 'AES-CBC' || algoName === 'AES-GCM' || algoName === 'AES-CTR') {
          return createCryptoKey('secret', { name: algoName }, extractable, keyUsages, keyBytes, algoName);
        }
      }

      notImplemented('importKey');
    },

    async deriveBits(
      algorithm: AlgorithmIdentifier & { salt?: ArrayBuffer; iterations?: number; hash?: AlgorithmIdentifier },
      baseKey: CryptoKey,
      length: number,
    ): Promise<ArrayBuffer> {
      const algoName = typeof algorithm === 'string' ? algorithm : algorithm.name;

      if (algoName === 'PBKDF2' && baseKey._keyData && algorithm.salt && algorithm.iterations && algorithm.hash) {
        const hashName = typeof algorithm.hash === 'string' ? algorithm.hash : algorithm.hash.name;
        const saltBytes = new Uint8Array(algorithm.salt);
        const saltWord = CJ.lib.WordArray.create(saltBytes);
        const keyWord = CJ.lib.WordArray.create(baseKey._keyData);

        let hasher = CJ.SHA256;
        if (hashName === 'SHA-512') hasher = CJ.SHA512;
        else if (hashName === 'SHA-1') hasher = CJ.SHA1;
        else if (hashName === 'SHA-384') hasher = CJ.SHA384;

        const derived = CJ.PBKDF2(keyWord, saltWord, {
          keySize: length / 32,
          iterations: algorithm.iterations,
          hasher,
        });

        return hexToBytes(derived.toString(CJ.enc.Hex)).buffer.slice(0, length / 8) as ArrayBuffer;
      }

      notImplemented('deriveBits');
    },

    async deriveKey(
      algorithm: AlgorithmIdentifier,
      baseKey: CryptoKey,
      derivedKeyType: AlgorithmIdentifier,
      extractable: boolean,
      keyUsages: KeyUsage[],
    ): Promise<CryptoKey> {
      const bits = await (globalAny as any).crypto.subtle.deriveBits(
        algorithm,
        baseKey,
        (derivedKeyType as { length?: number }).length || 256,
      );
      const derivedAlgoName = typeof derivedKeyType === 'string' ? derivedKeyType : derivedKeyType.name;
      return createCryptoKey('secret', { name: derivedAlgoName }, extractable, keyUsages, new Uint8Array(bits));
    },

    async encrypt(algorithm: AlgorithmIdentifier, key: CryptoKey, data: ArrayBuffer): Promise<ArrayBuffer> {
      const algoName = typeof algorithm === 'string' ? algorithm : algorithm.name;

      if ((algoName === 'AES-CBC' || algoName === 'AES-GCM' || algoName === 'AES-CTR') && key._keyData) {
        const iv = (algorithm as { iv?: ArrayBuffer }).iv;
        const dataBytes = new Uint8Array(data);
        const keyWord = CJ.lib.WordArray.create(key._keyData);
        const dataWord = CJ.lib.WordArray.create(dataBytes);

        let encrypted;
        if (algoName === 'AES-CBC' && iv) {
          const ivWord = CJ.lib.WordArray.create(new Uint8Array(iv));
          encrypted = CJ.AES.encrypt(dataWord, keyWord, { iv: ivWord, mode: CJ.mode.CBC, padding: CJ.pad.Pkcs7 });
        } else if (algoName === 'AES-CTR' && iv) {
          const ivWord = CJ.lib.WordArray.create(new Uint8Array(iv));
          encrypted = CJ.AES.encrypt(dataWord, keyWord, { iv: ivWord, mode: CJ.mode.CTR, padding: CJ.pad.NoPadding });
        } else if (algoName === 'AES-GCM' && iv) {
          const ivWord = CJ.lib.WordArray.create(new Uint8Array(iv));
          encrypted = CJ.AES.encrypt(dataWord, keyWord, { iv: ivWord, mode: CJ.mode.GCM, padding: CJ.pad.NoPadding });
        } else {
          encrypted = CJ.AES.encrypt(dataWord, keyWord);
        }

        return hexToBytes(encrypted.ciphertext.toString(CJ.enc.Hex)).buffer as ArrayBuffer;
      }

      notImplemented('encrypt');
    },

    async decrypt(algorithm: AlgorithmIdentifier, key: CryptoKey, data: ArrayBuffer): Promise<ArrayBuffer> {
      const algoName = typeof algorithm === 'string' ? algorithm : algorithm.name;

      if ((algoName === 'AES-CBC' || algoName === 'AES-GCM' || algoName === 'AES-CTR') && key._keyData) {
        const iv = (algorithm as { iv?: ArrayBuffer }).iv;
        const dataBytes = new Uint8Array(data);
        const keyWord = CJ.lib.WordArray.create(key._keyData);
        const dataWord = CJ.lib.WordArray.create(dataBytes);

        let decrypted;
        if (algoName === 'AES-CBC' && iv) {
          const ivWord = CJ.lib.WordArray.create(new Uint8Array(iv));
          decrypted = CJ.AES.decrypt({ ciphertext: dataWord }, keyWord, {
            iv: ivWord,
            mode: CJ.mode.CBC,
            padding: CJ.pad.Pkcs7,
          });
        } else if (algoName === 'AES-CTR' && iv) {
          const ivWord = CJ.lib.WordArray.create(new Uint8Array(iv));
          decrypted = CJ.AES.decrypt({ ciphertext: dataWord }, keyWord, {
            iv: ivWord,
            mode: CJ.mode.CTR,
            padding: CJ.pad.NoPadding,
          });
        } else if (algoName === 'AES-GCM' && iv) {
          const ivWord = CJ.lib.WordArray.create(new Uint8Array(iv));
          decrypted = CJ.AES.decrypt({ ciphertext: dataWord }, keyWord, {
            iv: ivWord,
            mode: CJ.mode.GCM,
            padding: CJ.pad.NoPadding,
          });
        } else {
          decrypted = CJ.AES.decrypt({ ciphertext: dataWord }, keyWord);
        }

        return hexToBytes(decrypted.toString(CJ.enc.Hex)).buffer as ArrayBuffer;
      }

      notImplemented('decrypt');
    },

    async generateKey(
      _algorithm: AlgorithmIdentifier,
      _extractable: boolean,
      _keyUsages: KeyUsage[],
    ): Promise<CryptoKey | { publicKey: CryptoKey; privateKey: CryptoKey }> {
      notImplemented('generateKey');
    },

    async sign(_algorithm: AlgorithmIdentifier, _key: CryptoKey, _data: ArrayBuffer): Promise<ArrayBuffer> {
      notImplemented('sign');
    },

    async verify(
      _algorithm: AlgorithmIdentifier,
      _key: CryptoKey,
      _signature: ArrayBuffer,
      _data: ArrayBuffer,
    ): Promise<boolean> {
      notImplemented('verify');
    },

    async exportKey(format: KeyFormat, key: CryptoKey): Promise<ArrayBuffer | JsonWebKey> {
      if (format === 'raw' && key._keyData) {
        return key._keyData.buffer as ArrayBuffer;
      }
      notImplemented('exportKey');
    },

    async wrapKey(
      _format: KeyFormat,
      _key: CryptoKey,
      _wrappingKey: CryptoKey,
      _wrapAlgorithm: AlgorithmIdentifier,
    ): Promise<ArrayBuffer> {
      notImplemented('wrapKey');
    },

    async unwrapKey(
      _format: KeyFormat,
      _wrappedKey: ArrayBuffer,
      _unwrappingKey: CryptoKey,
      _unwrapAlgorithm: AlgorithmIdentifier,
      _unwrappedKeyAlgorithm: AlgorithmIdentifier,
      _extractable: boolean,
      _keyUsages: KeyUsage[],
    ): Promise<CryptoKey> {
      notImplemented('unwrapKey');
    },
  };
}
