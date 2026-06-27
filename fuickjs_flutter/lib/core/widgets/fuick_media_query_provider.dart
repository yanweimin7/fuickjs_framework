import 'package:flutter/material.dart';

/// JS 侧可读取的轻量化 MediaQuery 快照（plain data，便于序列化跨 JS↔Native 边界）。
class FuickMediaQueryData {
  final double screenWidth;
  final double screenHeight;
  final double pixelRatio;
  final Brightness platformBrightness;
  final double textScaleFactor;
  final EdgeInsets viewPadding;
  final EdgeInsets viewInsets;

  const FuickMediaQueryData({
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
    required this.platformBrightness,
    required this.textScaleFactor,
    required this.viewPadding,
    required this.viewInsets,
  });

  factory FuickMediaQueryData.fromMediaQuery(MediaQueryData mq) {
    return FuickMediaQueryData(
      screenWidth: mq.size.width,
      screenHeight: mq.size.height,
      pixelRatio: mq.devicePixelRatio,
      platformBrightness: mq.platformBrightness,
      textScaleFactor: mq.textScaler.scale(1.0),
      viewPadding: mq.viewPadding,
      viewInsets: mq.viewInsets,
    );
  }

  bool get isDark => platformBrightness == Brightness.dark;

  /// 序列化为 Map（供 JS 端 useMediaQuery 拿到的同一对象结构）。
  Map<String, dynamic> toMap() => {
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
        'pixelRatio': pixelRatio,
        'platformBrightness':
            platformBrightness == Brightness.dark ? 'dark' : 'light',
        'isDark': isDark,
        'textScaleFactor': textScaleFactor,
        'viewPadding': {
          'top': viewPadding.top,
          'bottom': viewPadding.bottom,
          'left': viewPadding.left,
          'right': viewPadding.right,
        },
        'viewInsets': {
          'top': viewInsets.top,
          'bottom': viewInsets.bottom,
          'left': viewInsets.left,
          'right': viewInsets.right,
        },
      };

  @override
  String toString() =>
      'FuickMediaQueryData(${screenWidth}x$screenHeight, ratio=$pixelRatio, '
      'brightness=$platformBrightness, textScale=$textScaleFactor)';
}

/// InheritedWidget，由 [FuickAppView] 顶层注入。
///
/// JS 端 `useMediaQuery()` 通过 Native 服务读取此快照，
/// Flutter 端 Widget parser 可通过 [FuickMediaQueryProvider.of] 直接拿 [FuickMediaQueryData]。
class FuickMediaQueryProvider extends InheritedWidget {
  final FuickMediaQueryData data;

  const FuickMediaQueryProvider({
    super.key,
    required this.data,
    required super.child,
  });

  static FuickMediaQueryData? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FuickMediaQueryProvider>()
        ?.data;
  }

  @override
  bool updateShouldNotify(FuickMediaQueryProvider oldWidget) =>
      data != oldWidget.data;
}
