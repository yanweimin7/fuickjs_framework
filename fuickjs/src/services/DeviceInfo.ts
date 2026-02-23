
export interface DeviceInfoData {
  os: string;
  osVersion: string;
  locale: string;
  screenWidth: number;
  screenHeight: number;
  pixelRatio: number;
  isAndroid: boolean;
  isIOS: boolean;
  isMacOS: boolean;
  isWindows: boolean;
  isLinux: boolean;
  isFuchsia: boolean;
}

export class DeviceInfo {
  static getDeviceInfo(): Promise<DeviceInfoData> {
    return dartCallNativeAsync('DeviceInfo.getDeviceInfo', []);
  }
}
