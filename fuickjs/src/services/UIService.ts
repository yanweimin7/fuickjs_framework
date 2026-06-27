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

  /**
   * 同步获取当前页面的主题快照（来自宿主 ThemeData）。
   * 主题切换时由 Flutter 端推送 'themeChange' 事件，配合 useTheme hook 触发重渲染。
   */
  static getTheme(pageId: number): unknown {
    return dartCallNative('UI.getTheme', { pageId });
  }

  /**
   * 同步获取当前页面的 MediaQuery 快照（屏幕尺寸、暗黑模式、键盘弹起等）。
   * 屏幕旋转 / 键盘 / 暗黑切换时由 Flutter 端推送 'mediaQueryChange' 事件。
   */
  static getMediaQuery(pageId: number): unknown {
    return dartCallNative('UI.getMediaQuery', { pageId });
  }

  static isWidgetRegistered(type: string): boolean {
    if (UIService._registeredWidgets === null) {
      const list = UIService.getRegisteredWidgets();
      UIService._registeredWidgets = new Set(list);
    }
    return UIService._registeredWidgets.has(type);
  }
}
