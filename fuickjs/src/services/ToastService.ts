
export class ToastService {
  static show(message: string, duration?: number): Promise<boolean> {
    return dartCallNativeAsync('Toast.show', { message, duration });
  }

  static hide(): Promise<boolean> {
    return dartCallNativeAsync('Toast.hide', {});
  }
}
