
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

export class DeviceInfoService {
  static getDeviceInfo(): Promise<DeviceInfoData> {
    return dartCallNativeAsync('DeviceInfo.getDeviceInfo', []);
  }

  static makePhoneCall(phoneNumber: string): Promise<{ success: boolean }> {
    return dartCallNativeAsync('DeviceInfo.makePhoneCall', { phoneNumber });
  }

  static vibrate(type?: 'heavy' | 'medium' | 'light'): Promise<{ success: boolean }> {
    return dartCallNativeAsync('DeviceInfo.vibrate', { type: type ?? 'medium' });
  }

  static getNetworkType(): Promise<{ networkType: string }> {
    return dartCallNativeAsync('DeviceInfo.getNetworkType', {});
  }

  static startNetworkListener(): void {
    dartCallNative('DeviceInfo.startNetworkListener', {});
  }

  static stopNetworkListener(): void {
    dartCallNative('DeviceInfo.stopNetworkListener', {});
  }
}
