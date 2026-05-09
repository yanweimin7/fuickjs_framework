export class UIService {
  private static _registeredWidgets: Set<string> | null = null;

  static renderUI(pageId: number, renderData: unknown) {
    dartCallNative('UI.renderUI', { pageId, renderData });
  }

  static patchUI(pageId: number, patches: unknown[]) {
    dartCallNative('UI.patchUI', { pageId, patches });
  }

  static patchOps(pageId: number, ops: unknown[]) {
    dartCallNative('UI.patchOps', { pageId, ops });
  }

  static componentCommand(pageId: number, refId: string, method: string, args: unknown, nodeType: string) {
    dartCallNative('UI.componentCommand', {
      pageId,
      refId,
      method,
      args,
      nodeType,
    });
  }

  static getRegisteredWidgets(): string[] {
    return dartCallNative<string[]>('UI.getRegisteredWidgets', []);
  }

  static isWidgetRegistered(type: string): boolean {
    if (UIService._registeredWidgets === null) {
      const list = UIService.getRegisteredWidgets();
      UIService._registeredWidgets = new Set(list);
    }
    return UIService._registeredWidgets.has(type);
  }
}
