import { ClipboardService } from '../services/ClipboardService';
import { DeviceInfoService, type DeviceInfoData } from '../services/DeviceInfoService';
import { NativeEvent } from '../runtime/NativeEvent';

// ---------------------------------------------------------------------------
// Mutable device state — populated by initNavigator() at startup.
// Defaults are iPhone-like so common web libraries don't trip on detection.
// ---------------------------------------------------------------------------
const device: DeviceInfoData = {
  os: 'iOS',
  osVersion: '17.0',
  locale: 'en-US',
  screenWidth: 390,
  screenHeight: 844,
  pixelRatio: 3,
  isAndroid: false,
  isIOS: true,
  isMacOS: false,
  isWindows: false,
  isLinux: false,
  isFuchsia: false,
};

let _language = device.locale;
let _onLine = true;

NativeEvent.on('networkChange', (payload: unknown) => {
  const p = payload as { networkType?: string } | undefined;
  _onLine = p?.networkType !== 'none';
});

// ---------------------------------------------------------------------------
// Exported navigator — mirrors the Web API surface that third-party libraries
// commonly probe.  All async capabilities delegate to existing Service classes
// (no direct dartCallNativeAsync).
// ---------------------------------------------------------------------------

export const navigator = {
  /* ---- identification ---- */

  get appCodeName(): string {
    return 'Mozilla';
  },
  get appName(): string {
    return 'Netscape';
  },
  get appVersion(): string {
    return '5.0';
  },
  get product(): string {
    return 'Gecko';
  },
  get productSub(): string {
    return '20030107';
  },
  get vendor(): string {
    return '';
  },
  get vendorSub(): string {
    return '';
  },

  get userAgent(): string {
    const os = device.isAndroid ? 'Linux' : device.isIOS ? 'iPhone' : device.os;
    const webkitVer = '605.1.15';
    const osVer = device.osVersion.replace(/ /g, '_');
    return `Mozilla/5.0 (${os}; CPU ${os} OS ${osVer} like Mac OS X) AppleWebKit/${webkitVer} (KHTML, like Gecko) FuickJS/1.0`;
  },

  get platform(): string {
    if (device.isAndroid) return 'Linux armv8l';
    if (device.isIOS) return 'iPhone';
    if (device.isMacOS) return 'MacIntel';
    if (device.isWindows) return 'Win32';
    return 'Linux x86_64';
  },

  /* ---- language ---- */

  get language(): string {
    return _language;
  },
  get languages(): readonly string[] {
    return [_language];
  },

  /* ---- connectivity ---- */

  get onLine(): boolean {
    return _onLine;
  },

  /* ---- hardware hints ---- */

  get hardwareConcurrency(): number {
    return 4;
  },
  get maxTouchPoints(): number {
    return 5;
  },
  get deviceMemory(): number {
    return 4;
  },

  /* ---- feature flags ---- */

  get cookieEnabled(): boolean {
    return false;
  },
  get javaEnabled(): boolean {
    return false;
  },
  get pdfViewerEnabled(): boolean {
    return false;
  },
  get webdriver(): boolean {
    return false;
  },
  get doNotTrack(): string | null {
    return null;
  },

  /* ---- Clipboard API (ClipboardService) ---- */

  get clipboard(): {
    readText(): Promise<string>;
    writeText(text: string): Promise<void>;
    // read / write not supported
    read(): Promise<never>;
    write(): Promise<never>;
  } {
    return {
      readText: () => ClipboardService.getData(),
      writeText: (text: string) => ClipboardService.setData(text),
      read: () => Promise.reject(new Error('Clipboard.read() is not supported')),
      write: () => Promise.reject(new Error('Clipboard.write() is not supported')),
    };
  },

  /* ---- Vibrate (DeviceInfoService) ---- */

  vibrate(pattern: number | number[]): boolean {
    try {
      const ms = typeof pattern === 'number' ? pattern : (pattern[0] ?? 0);
      const type = ms > 50 ? 'heavy' : 'light';
      DeviceInfoService.vibrate(type);
      return true;
    } catch {
      return false;
    }
  },

  /* ---- permissions ---- */

  get permissions(): {
    query(_desc: unknown): Promise<{ state: PermissionState; onchange: null }>;
  } {
    return {
      query: async () => ({ state: 'prompt' as PermissionState, onchange: null }),
    };
  },

  /* ---- connection ---- */

  get connection(): {
    effectiveType: string;
    type: string;
    downlink: number;
    rtt: number;
    saveData: boolean;
    onchange: null;
  } {
    return {
      get effectiveType() {
        return '4g';
      },
      get type() {
        return 'cellular';
      },
      get downlink() {
        return 10;
      },
      get rtt() {
        return 50;
      },
      get saveData() {
        return false;
      },
      onchange: null,
    };
  },

  /* ---- service worker (not supported) ---- */

  get serviceWorker(): {
    controller: null;
    ready: Promise<never>;
    register(): Promise<never>;
    getRegistration(): Promise<undefined>;
    getRegistrations(): Promise<never[]>;
  } {
    const ns = 'ServiceWorker is not supported in FuickJS';
    return {
      controller: null,
      ready: Promise.reject(new Error(ns)),
      register: () => Promise.reject(new Error(ns)),
      getRegistration: () => Promise.resolve(undefined),
      getRegistrations: () => Promise.resolve([]),
    };
  },

  /* ---- storage ---- */

  get storage(): {
    estimate(): Promise<{ quota: number; usage: number }>;
    persist(): Promise<boolean>;
    persisted(): Promise<boolean>;
  } {
    return {
      estimate: async () => ({ quota: 0, usage: 0 }),
      persist: async () => false,
      persisted: async () => false,
    };
  },

  /* ---- unsupported stubs (return null / reject cleanly) ---- */

  get geolocation(): {
    getCurrentPosition(): Promise<never>;
    watchPosition(): number;
    clearWatch(): void;
  } {
    const e = new Error('Geolocation is not supported');
    return {
      getCurrentPosition: () => Promise.reject(e),
      watchPosition: () => -1,
      clearWatch: () => {},
    };
  },

  get mediaDevices(): object {
    const e = new Error('MediaDevices is not supported');
    return {
      getUserMedia: () => Promise.reject(e),
      enumerateDevices: () => Promise.resolve([]),
      getDisplayMedia: () => Promise.reject(e),
    };
  },

  get credentials(): object {
    return {
      get: () => Promise.resolve(null),
      store: () => Promise.resolve(null),
      create: () => Promise.resolve(null),
      preventSilentAccess: () => Promise.resolve(),
    };
  },

  get mediaCapabilities(): object {
    const no = { supported: false, smooth: false, powerEfficient: false };
    return {
      decodingInfo: async () => no,
      encodingInfo: async () => no,
    };
  },

  /* ---- internal helpers ---- */

  /**
   * Update internal device info (called by initNavigator or Flutter injection).
   */
  _updateDeviceInfo(info: Partial<DeviceInfoData>) {
    Object.assign(device, info);
    if (info.locale) _language = info.locale;
  },

  _setOnline(online: boolean) {
    _onLine = online;
  },
};

// ---- state-change listeners exposed on the prototype-like surface ----

let _onLineChangeHandler: ((ev: Event) => void) | null = null;

Object.defineProperty(navigator.connection, 'onchange', {
  get: () => _onLineChangeHandler,
  set: (fn) => {
    _onLineChangeHandler = fn;
  },
  configurable: true,
  enumerable: true,
});

// ---------------------------------------------------------------------------
// One-shot async init: pulls real device info from Flutter via
// DeviceInfoService.  Call once early, e.g. from fuickjs.bindGlobals().
// Safe to ignore — navigator works with sensible defaults without it.
// ---------------------------------------------------------------------------
export async function initNavigator(): Promise<void> {
  try {
    const info = await DeviceInfoService.getDeviceInfo();
    navigator._updateDeviceInfo(info);
  } catch {
    // Keep defaults — likely QuickJS hasn't finished initializing yet
  }
}
