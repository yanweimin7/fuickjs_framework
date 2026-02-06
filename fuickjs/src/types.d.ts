declare module 'react-reconciler';

declare global {
  // Bridge function to call Flutter
  function dartCallNative<T = unknown>(method: string, args: unknown): T;
  function dartCallNativeAsync<T = unknown>(method: string, args: unknown): Promise<T>;

  // Global polyfills and managers
  interface FuickAppController {
    render: (pageId: number, path: string, params: unknown) => void;
    destroy: (pageId: number) => void;
    getItemDSL: (pageId: number, refId: string, index: number) => unknown;
    notifyLifecycle: (pageId: number, type: string) => void;
    dispatchEvent: (eventObj: unknown, payload: unknown) => void;
    __dispatchEvent: (id: string, payload: unknown) => void;
  }

  var FuickAppController: FuickAppController;
  var queueMicrotask: (fn: () => void) => void;
  var __handleTimer: (id: number) => void;

  // Extend globalThis
  interface Object {
    FuickAppController: FuickAppController;
    dartCallNative: <T = unknown>(method: string, args: unknown) => T;
    dartCallNativeAsync: <T = unknown>(method: string, args: unknown) => Promise<T>;
  }

  namespace JSX {
    interface IntrinsicElements {
      Text: import('./widgets/Text').TextProps;
      Column: import('./widgets/Column').ColumnProps;
      Row: import('./widgets/Row').RowProps;
      Container: import('./widgets/Container').ContainerProps;
      Button: import('./widgets/Button').ButtonProps;
      TextField: import('./widgets/TextField').TextFieldProps;
      Switch: import('./widgets/Switch').SwitchProps;
      SizedBox: import('./widgets/SizedBox').SizedBoxProps;
      Image: import('./widgets/Image').ImageProps;
      ListView: import('./widgets/ListView').ListViewProps;
      Padding: import('./widgets/Padding').PaddingProps;
      Stack: import('./widgets/Stack').StackProps;
      Positioned: import('./widgets/Positioned').PositionedProps;
      Icon: import('./widgets/Icon').IconProps;
      Opacity: import('./widgets/Opacity').OpacityProps;
      Center: import('./widgets/Center').CenterProps;
      Expanded: import('./widgets/Expanded').ExpandedProps;
      Flexible: import('./widgets/Flexible').FlexibleProps;
      GestureDetector: import('./widgets/GestureDetector').GestureDetectorProps;
      InkWell: import('./widgets/InkWell').InkWellProps;
      Divider: import('./widgets/Divider').DividerProps;
      SingleChildScrollView: import('./widgets/SingleChildScrollView').SingleChildScrollViewProps;
      CircularProgressIndicator: import('./widgets/CircularProgressIndicator').CircularProgressIndicatorProps;
      SafeArea: import('./widgets/SafeArea').SafeAreaProps;
      Scaffold: import('./widgets/Scaffold').ScaffoldProps;
      AppBar: import('./widgets/AppBar').AppBarProps;
      ListTile: import('./widgets/ListTile').ListTileProps;
      BottomNavigationBar: import('./widgets/BottomNavigationBar').BottomNavigationBarProps;
      BottomNavigationBarItem: import('./widgets/BottomNavigationBar').BottomNavigationBarItemProps;
      FlutterProps: { propsKey: string; children?: import('react').ReactNode };
      AnimatedPadding: import('./widgets/AnimatedPadding').AnimatedPaddingProps;
      AnimatedScale: import('./widgets/AnimatedScale').AnimatedScaleProps;
      AnimatedRotation: import('./widgets/AnimatedRotation').AnimatedRotationProps;
      AnimatedSlide: import('./widgets/AnimatedSlide').AnimatedSlideProps;
      RotationTransition: import('./widgets/RotationTransition').RotationTransitionProps;
      ScaleTransition: import('./widgets/ScaleTransition').ScaleTransitionProps;
      SlideTransition: import('./widgets/SlideTransition').SlideTransitionProps;
      ConstrainedBox: import('./widgets/ConstrainedBox').ConstrainedBoxProps;
      FittedBox: import('./widgets/FittedBox').FittedBoxProps;
      Visibility: import('./widgets/Visibility').VisibilityProps;
      AlertDialog: import('./widgets/AlertDialog').AlertDialogProps;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      [elemName: string]: any;
    }
  }
}

export {};
