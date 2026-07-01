import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/widgets/fuick_theme_provider.dart';

void main() {
  group('FuickThemeData.empty', () {
    test('is a light theme with the framework default colors', () {
      expect(FuickThemeData.empty.brightness, Brightness.light);
      expect(FuickThemeData.empty.primaryColor, const Color(0xFF2196F3));
      expect(FuickThemeData.empty.scaffoldBackgroundColor,
          const Color(0xFFFFFFFF));
      expect(FuickThemeData.empty.surfaceColor, const Color(0xFFFFFFFF));
      expect(FuickThemeData.empty.textColor, const Color(0xFF000000));
      expect(FuickThemeData.empty.secondaryTextColor, const Color(0xFF757575));
      expect(FuickThemeData.empty.borderRadius, 8.0);
    });
  });

  group('FuickThemeData.fromThemeData', () {
    test('extracts brightness, primary, surface, and scaffold colors', () {
      final theme = ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFAA0000),
          surface: Color(0xFF101010),
        ),
        scaffoldBackgroundColor: const Color(0xFF202020),
      );
      final data = FuickThemeData.fromThemeData(theme);
      expect(data.brightness, Brightness.dark);
      expect(data.primaryColor, const Color(0xFFAA0000));
      expect(data.surfaceColor, const Color(0xFF101010));
      expect(data.scaffoldBackgroundColor, const Color(0xFF202020));
    });

    test('extracts textTheme.bodyLarge / bodySmall colors', () {
      final theme = ThemeData(
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF111111)),
          bodySmall: TextStyle(color: Color(0xFF999999)),
        ),
      );
      final data = FuickThemeData.fromThemeData(theme);
      expect(data.textColor, const Color(0xFF111111));
      expect(data.secondaryTextColor, const Color(0xFF999999));
    });

    test('default ThemeData always supplies non-null textTheme body colors',
        () {
      // Regression guard: the framework relies on the default ThemeData
      // populating bodyLarge/bodySmall with concrete colors. If a future
      // Flutter release ever changes that, this test surfaces the impact
      // on FuickThemeData's serialization (textColor would become null,
      // and JS-side `useTheme().textColor` would suddenly be undefined).
      final data = FuickThemeData.fromThemeData(ThemeData());
      expect(data.textColor, isNotNull);
      expect(data.secondaryTextColor, isNotNull);
    });

    test('extracts borderRadius from a RoundedRectangleBorder card shape', () {
      final theme = ThemeData(
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
      final data = FuickThemeData.fromThemeData(theme);
      expect(data.borderRadius, 12.0);
    });

    test('falls back to 8.0 when cardTheme.shape is null', () {
      final theme = ThemeData(cardTheme: const CardThemeData());
      final data = FuickThemeData.fromThemeData(theme);
      expect(data.borderRadius, 8.0);
    });

    test(
        'falls back to 8.0 when cardTheme.shape is not a RoundedRectangleBorder',
        () {
      final theme = ThemeData(
        cardTheme: const CardThemeData(
          shape: CircleBorder(),
        ),
      );
      final data = FuickThemeData.fromThemeData(theme);
      expect(data.borderRadius, 8.0);
    });
  });

  group('FuickThemeData.toMap', () {
    test('contains all expected keys', () {
      final m = FuickThemeData.empty.toMap();
      expect(
        m.keys.toSet(),
        {
          'brightness',
          'isDark',
          'primaryColor',
          'scaffoldBackgroundColor',
          'surfaceColor',
          'textColor',
          'secondaryTextColor',
          'borderRadius',
        },
      );
    });

    test('brightness serializes to "dark" / "light" string', () {
      expect(FuickThemeData.empty.toMap()['brightness'], 'light');
      final dark = FuickThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF000000),
        scaffoldBackgroundColor: const Color(0xFF000000),
        surfaceColor: const Color(0xFF000000),
      );
      expect(dark.toMap()['brightness'], 'dark');
    });

    test('isDark mirrors brightness (true ⇔ dark)', () {
      expect(FuickThemeData.empty.toMap()['isDark'], isFalse);
      final dark = FuickThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF000000),
        scaffoldBackgroundColor: const Color(0xFF000000),
        surfaceColor: const Color(0xFF000000),
      );
      expect(dark.toMap()['isDark'], isTrue);
    });

    test(
        'colors serialize to "#AARRGGBB" hex strings (8 digits, leading zero pad)',
        () {
      // primaryColor = 0xFF2196F3 → "#ff2196f3" (toARGB32 -> toRadixString(16))
      expect(
        FuickThemeData.empty.toMap()['primaryColor'],
        '#ff2196f3',
      );
    });

    test('textColor / secondaryTextColor are null when not provided', () {
      final data = FuickThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF000000),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        surfaceColor: const Color(0xFFFFFFFF),
      );
      final m = data.toMap();
      expect(m['textColor'], isNull);
      expect(m['secondaryTextColor'], isNull);
    });

    test('textColor / secondaryTextColor serialize when provided', () {
      final data = FuickThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF000000),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        surfaceColor: const Color(0xFFFFFFFF),
        textColor: const Color(0xFF112233),
        secondaryTextColor: const Color(0xFFAABBCC),
      );
      final m = data.toMap();
      expect(m['textColor'], '#ff112233');
      expect(m['secondaryTextColor'], '#ffaabbcc');
    });

    test('borderRadius passes through as a double', () {
      final data = FuickThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF000000),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        surfaceColor: const Color(0xFFFFFFFF),
        borderRadius: 16.5,
      );
      expect(data.toMap()['borderRadius'], 16.5);
    });
  });

  group('FuickThemeData round-trip', () {
    test('fromThemeData + toMap preserves all six top-level fields', () {
      final theme = ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFAA5500),
          surface: Color(0xFF202020),
        ),
        scaffoldBackgroundColor: const Color(0xFF181818),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
          bodySmall: TextStyle(color: Color(0xFF909090)),
        ),
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      );

      final data = FuickThemeData.fromThemeData(theme);
      final m = data.toMap();

      expect(m['brightness'], 'dark');
      expect(m['isDark'], isTrue);
      expect(m['primaryColor'], '#ffaa5500');
      expect(m['scaffoldBackgroundColor'], '#ff181818');
      expect(m['surfaceColor'], '#ff202020');
      expect(m['textColor'], '#ffe0e0e0');
      expect(m['secondaryTextColor'], '#ff909090');
      expect(m['borderRadius'], 20.0);
    });
  });

  group('FuickThemeData.toString', () {
    test('contains brightness, primary, scaffold, surface, radius info', () {
      final data = FuickThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFAA0000),
        scaffoldBackgroundColor: const Color(0xFF202020),
        surfaceColor: const Color(0xFF101010),
        borderRadius: 12,
      );
      final s = data.toString();
      expect(s, contains('dark'));
      expect(s, contains('radius=12'));
    });
  });
}
