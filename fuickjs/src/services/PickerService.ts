export interface PickerResult {
  value: number;
  label: string;
}

export interface MultiPickerResult {
  value: number[];
  labels: string[];
}

export interface ShowPickerOptions {
  range: string[];
  value?: number;
  title?: string;
  cancelText?: string;
  confirmText?: string;
}

export interface ShowMultiPickerOptions {
  range: string[][];
  value?: number[];
  title?: string;
  cancelText?: string;
  confirmText?: string;
}

export interface ShowDatePickerOptions {
  value?: string; // 'YYYY-MM-DD'
  start?: string;
  end?: string;
}

export interface ShowTimePickerOptions {
  value?: string; // 'HH:mm'
}

export class PickerService {
  /** 单列选择器 */
  static async show(options: ShowPickerOptions): Promise<PickerResult | null> {
    return await dartCallNativeAsync('Dialog.showPicker', {
      mode: 'selector',
      ...options,
    });
  }

  /** 多列选择器 */
  static async showMulti(options: ShowMultiPickerOptions): Promise<MultiPickerResult | null> {
    return await dartCallNativeAsync('Dialog.showPicker', {
      mode: 'multiSelector',
      ...options,
    });
  }

  /** 日期选择器，返回 'YYYY-MM-DD' 或 null */
  static async showDate(options: ShowDatePickerOptions = {}): Promise<string | null> {
    return await dartCallNativeAsync('Dialog.showDatePicker', options);
  }

  /** 时间选择器，返回 'HH:mm' 或 null */
  static async showTime(options: ShowTimePickerOptions = {}): Promise<string | null> {
    return await dartCallNativeAsync('Dialog.showTimePicker', options);
  }
}
