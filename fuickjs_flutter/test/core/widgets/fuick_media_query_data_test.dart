import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/widgets/fuick_media_query_provider.dart';

void main() {
  group('FuickMediaQueryData.fromMediaQuery', () {
    test('extracts width and height from size', () {
      final mq = MediaQueryData(
        size: const Size(360, 720),
        devicePixelRatio: 2.0,
      );
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      expect(data.screenWidth, 360.0);
      expect(data.screenHeight, 720.0);
    });

    test('extracts pixelRatio from devicePixelRatio', () {
      final mq = MediaQueryData(
        size: const Size(100, 100),
        devicePixelRatio: 3.5,
      );
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      expect(data.pixelRatio, 3.5);
    });

    test('extracts platformBrightness verbatim', () {
      final mq = MediaQueryData(
        size: const Size(0, 0),
        platformBrightness: Brightness.dark,
      );
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      expect(data.platformBrightness, Brightness.dark);
      expect(data.isDark, isTrue);
    });

    test('isDark is false for light brightness', () {
      final mq = MediaQueryData(
        size: const Size(0, 0),
        platformBrightness: Brightness.light,
      );
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      expect(data.isDark, isFalse);
    });

    test('textScaleFactor uses mq.textScaler.scale(1.0) (default scaler = 1.0)',
        () {
      final mq = MediaQueryData(size: const Size(0, 0));
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      expect(data.textScaleFactor, 1.0);
    });

    test('textScaleFactor reflects a non-trivial TextScaler', () {
      final mq = MediaQueryData(
        size: const Size(0, 0),
        textScaler: const TextScaler.linear(1.5),
      );
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      expect(data.textScaleFactor, 1.5);
    });

    test('viewPadding and viewInsets are copied verbatim', () {
      final padding =
          const EdgeInsets.only(top: 24, bottom: 0, left: 0, right: 0);
      final insets =
          const EdgeInsets.only(bottom: 200, top: 0, left: 0, right: 0);
      final mq = MediaQueryData(
        size: const Size(0, 0),
        viewPadding: padding,
        viewInsets: insets,
      );
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      expect(data.viewPadding, padding);
      expect(data.viewInsets, insets);
    });
  });

  group('FuickMediaQueryData.toMap', () {
    final sample = FuickMediaQueryData(
      screenWidth: 390,
      screenHeight: 844,
      pixelRatio: 3.0,
      platformBrightness: Brightness.light,
      textScaleFactor: 1.2,
      viewPadding:
          const EdgeInsets.only(top: 47, bottom: 34, left: 0, right: 0),
      viewInsets: EdgeInsets.zero,
    );

    test('contains all top-level keys', () {
      final m = sample.toMap();
      expect(
        m.keys.toSet(),
        {
          'screenWidth',
          'screenHeight',
          'pixelRatio',
          'platformBrightness',
          'isDark',
          'textScaleFactor',
          'viewPadding',
          'viewInsets',
        },
      );
    });

    test('numeric fields are passed through unchanged', () {
      final m = sample.toMap();
      expect(m['screenWidth'], 390.0);
      expect(m['screenHeight'], 844.0);
      expect(m['pixelRatio'], 3.0);
      expect(m['textScaleFactor'], 1.2);
    });

    test('platformBrightness serializes to "dark" / "light" string', () {
      expect(
        sample.toMap()['platformBrightness'],
        'light',
      );

      final dark = FuickMediaQueryData(
        screenWidth: 1,
        screenHeight: 1,
        pixelRatio: 1,
        platformBrightness: Brightness.dark,
        textScaleFactor: 1,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      );
      expect(dark.toMap()['platformBrightness'], 'dark');
    });

    test('isDark mirrors platformBrightness (true ⇔ dark)', () {
      expect(sample.toMap()['isDark'], isFalse);
      final dark = FuickMediaQueryData(
        screenWidth: 1,
        screenHeight: 1,
        pixelRatio: 1,
        platformBrightness: Brightness.dark,
        textScaleFactor: 1,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      );
      expect(dark.toMap()['isDark'], isTrue);
    });

    test(
        'viewPadding / viewInsets become nested maps with top/bottom/left/right',
        () {
      final m = sample.toMap();
      final p = m['viewPadding'] as Map;
      expect(p.keys.toSet(), {'top', 'bottom', 'left', 'right'});
      expect(p['top'], 47.0);
      expect(p['bottom'], 34.0);
      expect(p['left'], 0.0);
      expect(p['right'], 0.0);

      final i = m['viewInsets'] as Map;
      expect(i['top'], 0.0);
      expect(i['bottom'], 0.0);
      expect(i['left'], 0.0);
      expect(i['right'], 0.0);
    });
  });

  group('FuickMediaQueryData round-trip', () {
    test('fromMediaQuery + toMap preserves every field end-to-end', () {
      final mq = MediaQueryData(
        size: const Size(414, 896),
        devicePixelRatio: 2.625,
        platformBrightness: Brightness.dark,
        textScaler: const TextScaler.linear(1.15),
        viewPadding:
            const EdgeInsets.only(top: 44, bottom: 34, left: 0, right: 0),
        viewInsets:
            const EdgeInsets.only(top: 0, bottom: 280, left: 0, right: 0),
      );
      final data = FuickMediaQueryData.fromMediaQuery(mq);
      final m = data.toMap();

      expect(m['screenWidth'], 414.0);
      expect(m['screenHeight'], 896.0);
      expect(m['pixelRatio'], 2.625);
      expect(m['platformBrightness'], 'dark');
      expect(m['isDark'], isTrue);
      expect(m['textScaleFactor'], closeTo(1.15, 1e-9));
      expect((m['viewPadding'] as Map)['top'], 44.0);
      expect((m['viewPadding'] as Map)['bottom'], 34.0);
      expect((m['viewInsets'] as Map)['bottom'], 280.0);
    });
  });

  group('FuickMediaQueryData.toString', () {
    test('contains size, ratio, brightness and text scale info', () {
      final data = FuickMediaQueryData(
        screenWidth: 200,
        screenHeight: 400,
        pixelRatio: 2.0,
        platformBrightness: Brightness.dark,
        textScaleFactor: 1.1,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      );
      final s = data.toString();
      // screenWidth/screenHeight are doubles, so the printed form is "200.0x400.0".
      expect(s, contains('200.0x400.0'));
      expect(s, contains('ratio=2.0'));
      expect(s, contains('dark'));
      expect(s, contains('1.1'));
    });
  });
}
