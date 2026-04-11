import { ReactNode } from 'react';
import { elementToDsl } from '../core/page_render';

export class DialogService {
  /**
   * Shows a dialog with custom DSL content.
   * @param content The ReactNode to show in the dialog.
   * @param options Dialog options.
   */
  static async show(
    content: ReactNode,
    options: {
      pageId?: number;
      barrierDismissible?: boolean;
      barrierColor?: string;
    } = {},
  ): Promise<any> {
    const targetPageId = options.pageId ?? -1;
    const dsl = elementToDsl(targetPageId, content);

    return await dartCallNativeAsync('Dialog.show', {
      dsl,
      pageId: targetPageId,
      barrierDismissible: options.barrierDismissible ?? true,
      barrierColor: options.barrierColor,
    });
  }

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
