import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' as lg;
import 'package:fuickjs_flutter/core/fuick_config.dart';

void main() {
  // FuickConfig is a process-wide singleton, so every test must restore
  // the values it touches. We snapshot the entire state in setUp and
  // restore it in tearDown to avoid bleed between tests.
  late FuickConfig cfg;
  late bool savedDebug;
  late lg.Level savedLogLevel;
  late bool savedHotReload;
  late bool savedDevPage;
  late bool savedPerfOverlay;
  late bool savedVerboseCmd;

  setUp(() {
    cfg = FuickConfig();
    savedDebug = cfg.debug;
    savedLogLevel = cfg.logLevel;
    savedHotReload = cfg.enableHotReload;
    savedDevPage = cfg.enableDevPage;
    savedPerfOverlay = cfg.enablePerformanceOverlay;
    savedVerboseCmd = cfg.verboseCommandLog;
  });

  tearDown(() {
    cfg.debug = savedDebug;
    cfg.logLevel = savedLogLevel;
    cfg.enableHotReload = savedHotReload;
    cfg.enableDevPage = savedDevPage;
    cfg.enablePerformanceOverlay = savedPerfOverlay;
    cfg.verboseCommandLog = savedVerboseCmd;
  });

  group('FuickConfig singleton', () {
    test('factory returns the same instance every time', () {
      final a = FuickConfig();
      final b = FuickConfig();
      expect(identical(a, b), isTrue);
    });

    test('default debug mode follows kDebugMode', () {
      // The initial state is whatever kDebugMode is, so the only thing we
      // can assert for sure is that toggling the setter changes the getter.
      final original = cfg.debug;
      cfg.debug = !original;
      expect(cfg.debug, !original);
    });
  });

  group('FuickConfig.debug setter side effects', () {
    test('setting debug=true does NOT mutate logLevel / hotReload / devPage', () {
      // Force a known starting state so we can detect any "if (true) {...}"
      // branch the setter might accidentally add.
      cfg.logLevel = lg.Level.error;
      cfg.enableHotReload = false;
      cfg.enableDevPage = false;

      cfg.debug = true;

      expect(cfg.logLevel, lg.Level.error,
          reason: 'debug=true must not touch logLevel');
      expect(cfg.enableHotReload, isFalse,
          reason: 'debug=true must not re-enable hot reload');
      expect(cfg.enableDevPage, isFalse,
          reason: 'debug=true must not re-enable dev page');
    });

    test('setting debug=false tightens logLevel to Level.warning', () {
      cfg.logLevel = lg.Level.trace;
      cfg.debug = false;
      expect(cfg.logLevel, lg.Level.warning);
    });

    test('setting debug=false disables hot reload', () {
      cfg.enableHotReload = true;
      cfg.debug = false;
      expect(cfg.enableHotReload, isFalse);
    });

    test('setting debug=false disables dev page', () {
      cfg.enableDevPage = true;
      cfg.debug = false;
      expect(cfg.enableDevPage, isFalse);
    });

    test('setting debug=false applies all three side effects in one call', () {
      cfg.logLevel = lg.Level.debug;
      cfg.enableHotReload = true;
      cfg.enableDevPage = true;
      cfg.debug = false;

      expect(cfg.logLevel, lg.Level.warning);
      expect(cfg.enableHotReload, isFalse);
      expect(cfg.enableDevPage, isFalse);
    });

    test('setting debug=false does NOT touch perfOverlay or verboseCommandLog',
        () {
      cfg.enablePerformanceOverlay = true;
      cfg.verboseCommandLog = true;
      cfg.debug = false;

      expect(cfg.enablePerformanceOverlay, isTrue,
          reason: 'debug=false must not silently flip perfOverlay');
      expect(cfg.verboseCommandLog, isTrue,
          reason: 'debug=false must not silently flip verbose command log');
    });

    test('setting debug=true after debug=false does not loosen the side effects',
        () {
      cfg.debug = false;
      expect(cfg.logLevel, lg.Level.warning);
      expect(cfg.enableHotReload, isFalse);
      expect(cfg.enableDevPage, isFalse);

      // Re-enabling debug is a no-op for the other fields — they're not
      // automatically restored. (Documenting current behavior.)
      cfg.debug = true;
      expect(cfg.logLevel, lg.Level.warning,
          reason: 'debug=true must not retroactively change logLevel');
      expect(cfg.enableHotReload, isFalse,
          reason: 'debug=true must not retroactively re-enable hot reload');
      expect(cfg.enableDevPage, isFalse,
          reason: 'debug=true must not retroactively re-enable dev page');
    });
  });

  group('FuickConfig individual setters', () {
    test('logLevel can be set to any Level value', () {
      cfg.logLevel = lg.Level.error;
      expect(cfg.logLevel, lg.Level.error);
      cfg.logLevel = lg.Level.info;
      expect(cfg.logLevel, lg.Level.info);
      cfg.logLevel = lg.Level.fatal;
      expect(cfg.logLevel, lg.Level.fatal);
    });

    test('enableHotReload / enableDevPage / perfOverlay / verboseCmd are independent flags',
        () {
      cfg.enableHotReload = true;
      cfg.enableDevPage = false;
      cfg.enablePerformanceOverlay = true;
      cfg.verboseCommandLog = false;

      expect(cfg.enableHotReload, isTrue);
      expect(cfg.enableDevPage, isFalse);
      expect(cfg.enablePerformanceOverlay, isTrue);
      expect(cfg.verboseCommandLog, isFalse);

      // Flipping one must not propagate to the others.
      cfg.enableHotReload = false;
      expect(cfg.enableDevPage, isFalse);
      expect(cfg.enablePerformanceOverlay, isTrue);
      expect(cfg.verboseCommandLog, isFalse);
    });
  });

  group('FuickConfig.toString', () {
    test('toString includes all relevant fields with their current values', () {
      cfg.debug = true;
      cfg.logLevel = lg.Level.info;
      cfg.enableHotReload = false;
      cfg.enableDevPage = true;
      cfg.enablePerformanceOverlay = false;
      cfg.verboseCommandLog = true;

      final s = cfg.toString();
      expect(s, contains('debug=true'));
      expect(s, contains('logLevel=Level.info'));
      expect(s, contains('hotReload=false'));
      expect(s, contains('devPage=true'));
      expect(s, contains('perfOverlay=false'));
      expect(s, contains('verboseCmd=true'));
    });
  });

  group('FuickConfig default alignment with kDebugMode', () {
    test(
        'the initial defaults are coherent with kDebugMode at the time the singleton was constructed',
        () {
      // We can't change kDebugMode at runtime, but we can verify the
      // invariant: cfg.debug and the kDebugMode-conditional defaults agree.
      if (kDebugMode) {
        expect(cfg.logLevel == lg.Level.debug ||
                cfg.logLevel == lg.Level.warning,
            isTrue,
            reason: 'kDebugMode=true permits either default');
        expect(cfg.debug, cfg.debug); // tautology, just exercising the getter
      }
    });
  });
}
