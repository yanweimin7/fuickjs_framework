
export class Toast {
  static show(message: string, duration?: number): Promise<boolean> {
    return dartCallNativeAsync('Toast.show', [message, duration]);
  }
}
