export class DialogService {
  /**
   * Dismisses the current dialog.
   * @param result Optional result to return from the dialog.
   */
  static dismiss(result?: any) {
    dartCallNative('Dialog.dismiss', result);
  }

  /** 显示系统风格的确认框 */
  static async showModal(options: {
    title?: string;
    content?: string;
    showCancel?: boolean;
    cancelText?: string;
    confirmText?: string;
  }): Promise<boolean> {
    return dartCallNativeAsync('Dialog.showModal', options) as Promise<boolean>;
  }

  /** 显示底部动作菜单，返回选中项索引，取消返回 -1 */
  static async showActionSheet(options: { items: string[] }): Promise<number> {
    return dartCallNativeAsync('Dialog.showActionSheet', options) as Promise<number>;
  }
}
