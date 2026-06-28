export class UIService {
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

  /**
   * 拉取全部已注册的 widget 类型列表。
   * worker isolate 中 UIService 未注册,必须走 async 路径。
   */
  static async getRegisteredWidgets(): Promise<string[]> {
    return await dartCallNativeAsync<string[]>('UI.getRegisteredWidgets', []);
  }

  /**
   * 判断某个 widget 类型是否已注册（由 Dart 侧 WidgetFactory 提供）。
   * worker isolate 中 UIService 未注册,必须走 async 路径。
   * 旧版曾在 JS 端缓存 Set,但同步缓存的 getRegisteredWidgets 在 worker 中是 Promise,
   * Set 被错误填充为 [Promise],has() 永远 false,这里改为每次直查 Dart。
   */
  static async isWidgetRegistered(type: string): Promise<boolean> {
    return await dartCallNativeAsync<boolean>('UI.isWidgetRegistered', [type]);
  }

  /**
   * 同步获取当前页面的主题快照（来自宿主 ThemeData）。
   * 主题切换时由 Flutter 端推送 'themeChange' 事件，配合 useTheme hook 触发重渲染。
   *
   * 注意：worker isolate 中 UIService 未注册,sync 路径会 fallback 到主 isolate 并返回 Promise,
   * 把 Promise 当对象用会得到 undefined。必须走 async 路径。
   */
  static getTheme(pageId: number): Promise<Record<string, unknown>> {
    return dartCallNativeAsync<Record<string, unknown>>('UI.getTheme', { pageId });
  }

  /**
   * 同步获取当前页面的 MediaQuery 快照（屏幕尺寸、暗黑模式、键盘弹起等）。
   * 屏幕旋转 / 键盘 / 暗黑切换时由 Flutter 端推送 'mediaQueryChange' 事件。
   *
   * 注意：worker isolate 中 UIService 未注册,sync 路径会 fallback 到主 isolate 并返回 Promise,
   * 把 Promise 当 Map 用会得到 undefined。这里必须走 async 路径,等真实数据回来后再读。
   */
  static getMediaQuery(pageId: number): Promise<Record<string, unknown>> {
    return dartCallNativeAsync<Record<string, unknown>>('UI.getMediaQuery', { pageId });
  }
}
