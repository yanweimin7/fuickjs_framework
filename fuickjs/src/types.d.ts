import * as Widgets from './widgets';

declare module 'react-reconciler';
declare module 'crypto-js';

declare global {
  // Bridge function to call Flutter
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

export { };
