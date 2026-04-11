export class UIService {
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

  static isWidgetRegistered(type: string): boolean {
    return dartCallNative('UI.isWidgetRegistered', [type]);
  }
}
