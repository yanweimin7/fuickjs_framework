import 'package:flutter/material.dart';

/// JS 侧可读取的轻量化主题数据快照（plain data，便于序列化跨 JS↔Native 边界）。
class FuickThemeData {
  /// 当前 Brightness（light / dark）。
  final Brightness brightness;

  /// primary 色（来自 ThemeData.colorScheme.primary）。
  final Color primaryColor;

  /// 背景色（来自 ThemeData.scaffoldBackgroundColor）。
  final Color scaffoldBackgroundColor;

  /// surface 色（来自 ThemeData.colorScheme.surface）。
  final Color surfaceColor;

  /// 文字主色（来自 ThemeData.textTheme.bodyLarge.color）。
  final Color? textColor;

  /// 次要文字色（来自 ThemeData.textTheme.bodySmall.color）。
  final Color? secondaryTextColor;

  /// 主圆角（来自 ThemeData.cardTheme.shape 圆角提取）。
  final double borderRadius;

  const FuickThemeData({
    required this.brightness,
    required this.primaryColor,
    required this.scaffoldBackgroundColor,
    required this.surfaceColor,
    this.textColor,
    this.secondaryTextColor,
    this.borderRadius = 8.0,
  });

  /// 从 Flutter [ThemeData] 提取关键字段。
  factory FuickThemeData.fromThemeData(ThemeData theme) {
    double extractBorderRadius(ShapeBorder? shape) {
      if (shape is RoundedRectangleBorder) {
        final r = shape.borderRadius;
        if (r is BorderRadius) return r.topLeft.x;
      }
      return 8.0;
    }

    return FuickThemeData(
      brightness: theme.brightness,
      primaryColor: theme.colorScheme.primary,
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      surfaceColor: theme.colorScheme.surface,
      textColor: theme.textTheme.bodyLarge?.color,
      secondaryTextColor: theme.textTheme.bodySmall?.color,
      borderRadius: extractBorderRadius(theme.cardTheme.shape),
    );
  }

  /// 默认空主题（light）。
  static const FuickThemeData empty = FuickThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF2196F3),
    scaffoldBackgroundColor: Color(0xFFFFFFFF),
    surfaceColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF000000),
    secondaryTextColor: Color(0xFF757575),
  );

  /// 序列化为 Map（供 JS 端通过 useTheme 拿到的同一对象结构）。
  Map<String, dynamic> toMap() => {
        'brightness': brightness == Brightness.dark ? 'dark' : 'light',
        'isDark': brightness == Brightness.dark,
        'primaryColor': '#${primaryColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'scaffoldBackgroundColor':
            '#${scaffoldBackgroundColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'surfaceColor':
            '#${surfaceColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'textColor': textColor != null
            ? '#${textColor!.toARGB32().toRadixString(16).padLeft(8, '0')}'
            : null,
        'secondaryTextColor': secondaryTextColor != null
            ? '#${secondaryTextColor!.toARGB32().toRadixString(16).padLeft(8, '0')}'
            : null,
        'borderRadius': borderRadius,
      };

  @override
  String toString() =>
      'FuickThemeData(brightness=$brightness, primary=$primaryColor, '
      'scaffold=$scaffoldBackgroundColor, surface=$surfaceColor, '
      'radius=$borderRadius)';
}

/// InheritedWidget，由 [FuickAppView] 顶层注入。
///
/// JS 端 `useTheme()` hook 通过 Native 服务读取此快照，
/// Flutter 端 Widget parser 可通过 [FuickThemeProvider.of] 直接拿 [FuickThemeData]。
class FuickThemeProvider extends InheritedWidget {
  final FuickThemeData data;

  const FuickThemeProvider({
    super.key,
    required this.data,
    required super.child,
  });

  static FuickThemeData? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FuickThemeProvider>()
        ?.data;
  }

  static FuickThemeData ofOrDefault(BuildContext context) {
    return of(context) ?? FuickThemeData.empty;
  }

  @override
  bool updateShouldNotify(FuickThemeProvider oldWidget) =>
      data != oldWidget.data;
}

/// extension on Color 用于 toARGB32，兼容老 SDK。
extension on Color {
  int toARGB32() {
    // ignore: deprecated_member_use
    return value;
  }
}
