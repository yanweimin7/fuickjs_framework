import * as Widgets from './widgets';

declare module 'react-reconciler';
declare module 'crypto-js';

declare global {
  /**
   * @internal
   *
   * Dart ↔ JS 同步桥。仅供 fuickjs 内部 service wrapper 使用，**外部业务代码不要直接调用**。
   *
   * 严格规则（engine 在 worker isolate 中强制执行，命中会抛 `StateError`）：
   *   - ✅ 仅 `Timer.*` / `Console.*` / `FileSystem.*Sync` 这 3 类方法
   *     在 worker isolate 是真正同步的（Dart 端白名单 service）。
   *   - ❌ 任何 `registerAsyncMethod` 注册的方法 → 必须用 `dartCallNativeAsync`。
   *   - ❌ 任何 `UIService` / `Navigator` / `Network` / `Storage` / 等 →
   *     在 worker isolate 静默返回 Promise，访问字段会拿到 undefined
   *     (viewInsets 那个 bug 就是这样)。
   *
   * 业务侧请使用具体 service 的 wrapper（`UIService.getMediaQuery(...)` 等），
   * 内部已经走 `dartCallNativeAsync`。
   */
  function dartCallNative<T = unknown>(method: string, args: unknown): T;
  function dartCallNativeAsync<T = unknown>(method: string, args: unknown): Promise<T>;

  // Global polyfills and managers
  interface FuickJS {
    render: (pageId: number, path: string, params: unknown) => void;
    destroy: (pageId: number) => void;
    getItemDSL: (pageId: number, refId: string, index: number) => unknown;
    notifyLifecycle: (pageId: number, type: string) => void;
    dispatchEvent: (eventObj: unknown, payload: unknown) => void;
    handleTimer: (id: number) => void;
  }

  var fuickjs: FuickJS;
  var queueMicrotask: (fn: () => void) => void;

  // Extend globalThis
  interface Object {
    fuickjs: FuickJS;
    /**
     * @internal — 同步桥, 仅 Timer/Console/FileSystem 同步服务安全.
     *            其他一律走 dartCallNativeAsync.
     */
    dartCallNative: <T = unknown>(method: string, args: unknown) => T;
    dartCallNativeAsync: <T = unknown>(method: string, args: unknown) => Promise<T>;
  }

  namespace JSX {
    interface IntrinsicElements {
      Text: Widgets.TextProps;
      Column: Widgets.ColumnProps;
      Row: Widgets.RowProps;
      Container: Widgets.ContainerProps;
      Button: Widgets.ButtonProps;
      TextField: Widgets.TextFieldProps;
      Switch: Widgets.SwitchProps;
      SizedBox: Widgets.SizedBoxProps;
      Image: Widgets.ImageProps;
      ListView: Widgets.ListViewProps;
      Padding: Widgets.PaddingProps;
      Stack: Widgets.StackProps;
      Positioned: Widgets.PositionedProps;
      Icon: Widgets.IconProps;
      Opacity: Widgets.OpacityProps;
      Center: Widgets.CenterProps;
      Expanded: Widgets.ExpandedProps;
      Flexible: Widgets.FlexibleProps;
      GestureDetector: Widgets.GestureDetectorProps;
      InkWell: Widgets.InkWellProps;
      Divider: Widgets.DividerProps;
      SingleChildScrollView: Widgets.SingleChildScrollViewProps;
      CircularProgressIndicator: Widgets.CircularProgressIndicatorProps;
      SafeArea: Widgets.SafeAreaProps;
      Scaffold: Widgets.ScaffoldProps;
      AppBar: Widgets.AppBarProps;
      ListTile: Widgets.ListTileProps;
      BottomNavigationBar: Widgets.BottomNavigationBarProps;
      BottomNavigationBarItem: Widgets.BottomNavigationBarItemProps;
      FlutterProps: Widgets.FlutterPropsProps;
      AnimatedPadding: Widgets.AnimatedPaddingProps;
      AnimatedScale: Widgets.AnimatedScaleProps;
      AnimatedRotation: Widgets.AnimatedRotationProps;
      AnimatedSlide: Widgets.AnimatedSlideProps;
      RotationTransition: Widgets.RotationTransitionProps;
      ScaleTransition: Widgets.ScaleTransitionProps;
      SlideTransition: Widgets.SlideTransitionProps;
      ConstrainedBox: Widgets.ConstrainedBoxProps;
      FittedBox: Widgets.FittedBoxProps;
      Visibility: Widgets.VisibilityProps;
      AlertDialog: Widgets.AlertDialogProps;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      [elemName: string]: any;
    }
  }
}

export {};
