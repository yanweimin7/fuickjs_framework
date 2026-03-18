import { ReactNode } from 'react';
import { elementToDsl } from '../page_render';

export class Dialog {
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
}
