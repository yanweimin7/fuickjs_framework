export class UIService {
  private static _registeredWidgets: Set<string> | null = null;

  // 异步 fire-and-forget：JS 不阻塞等 Dart 主线程消费完成。
  // Worker isolate 单线程串行处理 onCallNativeAsync，保证调用到达 Dart 的顺序与 JS 发起顺序一致，
  // 因此 renderUI → patchUI/patchOps → componentCommand 之间无需额外同步。
  static renderUI(pageId: number, renderData: unknown) {
    void dartCallNativeAsync('UI.renderUI', { pageId, renderData });
  }

  static patchUI(pageId: number, patches: unknown[]) {
    void dartCallNativeAsync('UI.patchUI', { pageId, patches });
  }

  static patchOps(pageId: number, ops: unknown[]) {
    void dartCallNativeAsync('UI.patchOps', { pageId, ops });
  }

  static componentCommand(pageId: number, refId: string, method: string, args: unknown, nodeType: string) {
    void dartCallNativeAsync('UI.componentCommand', {
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
