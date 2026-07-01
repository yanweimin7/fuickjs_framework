import 'package:flutter_test/flutter_test.dart';
import 'package:fjs_engine/core/jscontext_interface.dart';
import 'package:logger/logger.dart' as lg;
import 'package:fuickjs_flutter/core/service/console_service.dart';

class _NoopContext implements IQuickJsContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LogCapture {
  final List<lg.LogEvent> events = [];
  late final void Function(lg.LogEvent) _cb;

  _LogCapture() {
    _cb = (e) => events.add(e);
    lg.Logger.addLogListener(_cb);
  }

  void dispose() {
    lg.Logger.removeLogListener(_cb);
  }
}

void main() {
  // The global `logger` uses a default filter that gates by `Logger.level`.
  // To make sure messages at every level reach the listener, lower the
  // threshold to trace for the duration of these tests.
  final originalLevel = lg.Logger.level;
  setUpAll(() {
    lg.Logger.level = lg.Level.trace;
  });
  tearDownAll(() {
    lg.Logger.level = originalLevel;
  });

  group('ConsoleService basics', () {
    test('name is "Console"', () {
      expect(ConsoleService().name, 'Console');
    });

    test('registers a sync "console" method on construction', () {
      final svc = ConsoleService();
      expect(svc.syncMethods.keys, contains('console'));
    });

    test('does not register any async methods (pure sync hot path)', () {
      final svc = ConsoleService();
      expect(svc.asyncMethods, isEmpty,
          reason: 'ConsoleService must stay on the sync bridge');
    });

    test('handler returns null (so JS receives undefined / void)', () {
      final svc = ConsoleService();
      svc.init(_NoopContext(), null);
      final result = svc.syncMethods['console']!(<String, dynamic>{
        'level': 'log',
        'message': 'hello',
      });
      expect(result, isNull);
    });

    test('handler tolerates non-Map args (treats as empty level+message)', () {
      final svc = ConsoleService();
      svc.init(_NoopContext(), null);
      // args == null — handler must not throw.
      expect(() => svc.syncMethods['console']!(null), returnsNormally);
      expect(
          () => svc.syncMethods['console']!('just a string'), returnsNormally);
    });
  });

  group('ConsoleService level mapping', () {
    late ConsoleService svc;
    late _LogCapture cap;

    setUp(() {
      svc = ConsoleService();
      svc.init(_NoopContext(), null);
      cap = _LogCapture();
    });

    tearDown(() {
      cap.dispose();
      svc.dispose();
    });

    lg.Level? firstLevelFor(String messageSubstr) {
      for (final e in cap.events) {
        final m = e.message?.toString() ?? '';
        if (m.contains(messageSubstr)) return e.level;
      }
      return null;
    }

    test('"error" maps to logger.e (Level.error)', () {
      svc.syncMethods['console']!(
          <String, dynamic>{'level': 'error', 'message': 'err-marker-1'});
      expect(firstLevelFor('err-marker-1'), lg.Level.error);
    });

    test('"warn" maps to logger.w (Level.warning)', () {
      svc.syncMethods['console']!(
          <String, dynamic>{'level': 'warn', 'message': 'warn-marker-1'});
      expect(firstLevelFor('warn-marker-1'), lg.Level.warning);
    });

    test('"info" maps to logger.i (Level.info)', () {
      svc.syncMethods['console']!(
          <String, dynamic>{'level': 'info', 'message': 'info-marker-1'});
      expect(firstLevelFor('info-marker-1'), lg.Level.info);
    });

    test('"debug" maps to logger.d (Level.debug)', () {
      svc.syncMethods['console']!(
          <String, dynamic>{'level': 'debug', 'message': 'debug-marker-1'});
      expect(firstLevelFor('debug-marker-1'), lg.Level.debug);
    });

    test(
        'unknown level (e.g. "trace") falls back to info with the level in the prefix',
        () {
      svc.syncMethods['console']!(
          <String, dynamic>{'level': 'trace', 'message': 'trace-marker-1'});
      final ev = cap.events.firstWhere(
        (e) => (e.message?.toString() ?? '').contains('trace-marker-1'),
      );
      expect(ev.level, lg.Level.info,
          reason: 'unknown level must use Level.info as the default bucket');
      expect(ev.message.toString(), contains('[JS trace]'),
          reason: 'the level name should appear in the message prefix');
    });

    test(
        'default level (when missing) goes through the unknown branch with "log"',
        () {
      svc.syncMethods['console']!(<String, dynamic>{'message': 'no-level'});
      final ev = cap.events.firstWhere(
        (e) => (e.message?.toString() ?? '').contains('no-level'),
      );
      expect(ev.level, lg.Level.info);
      expect(ev.message.toString(), contains('[JS log]'));
    });

    test('message is wrapped in the "[JS]" prefix and preserves the body', () {
      svc.syncMethods['console']!(<String, dynamic>{
        'level': 'info',
        'message': 'hello-world-42',
      });
      final ev = cap.events.firstWhere(
        (e) => (e.message?.toString() ?? '').contains('hello-world-42'),
      );
      expect(ev.message.toString(), startsWith('[JS]'));
      expect(ev.message.toString(), contains('hello-world-42'));
    });

    test('unknown level gets bracketed in the prefix as well', () {
      svc.syncMethods['console']!(<String, dynamic>{
        'level': 'log',
        'message': 'plain-log-1',
      });
      final ev = cap.events.firstWhere(
        (e) => (e.message?.toString() ?? '').contains('plain-log-1'),
      );
      // Default branch formats as '[JS log] ...' — still wrapped in [JS …].
      expect(ev.message.toString(), startsWith('[JS'));
      expect(ev.message.toString(), contains('plain-log-1'));
    });

    test('non-string message values are coerced via toString()', () {
      svc.syncMethods['console']!(<String, dynamic>{
        'level': 'log',
        'message': 123,
      });
      final ev = cap.events.firstWhere(
        (e) => (e.message?.toString() ?? '').contains('123'),
      );
      expect(ev.message.toString(), contains('123'));
    });

    test('null message becomes empty string and still produces a log line', () {
      svc.syncMethods['console']!(<String, dynamic>{'level': 'log'});
      // At least one event is recorded; verifying it is non-null avoids
      // coupling to the exact empty-string format used by the printer.
      expect(cap.events, isNotEmpty);
    });
  });

  group('ConsoleService uses the project logger singleton', () {
    test(
        'calling the handler routes through the same `logger` imported by the framework',
        () {
      // The service binds the project `logger` at compile time, so verifying
      // it sees the listener installed on the global Logger is a structural
      // smoke test that catches any future refactor pointing at a different
      // logger instance.
      final svc = ConsoleService();
      svc.init(_NoopContext(), null);
      final cap = _LogCapture();
      try {
        svc.syncMethods['console']!(<String, dynamic>{
          'level': 'log',
          'message': 'singleton-marker',
        });
        expect(
          cap.events.any(
            (e) => (e.message?.toString() ?? '').contains('singleton-marker'),
          ),
          isTrue,
        );
      } finally {
        cap.dispose();
      }
    });
  });

  group('ConsoleService dispose behavior', () {
    test('after dispose, calling the handler is a no-op (no log emitted)', () {
      final svc = ConsoleService();
      svc.init(_NoopContext(), null);
      // Capture the wrapper installed by registerMethod before dispose
      // (dispose itself clears the map).
      final wrapper = svc.syncMethods['console']!;
      svc.dispose();

      final cap = _LogCapture();
      try {
        // The disposed service short-circuits — should not throw and not log.
        final result = wrapper(<String, dynamic>{
          'level': 'error',
          'message': 'after-dispose',
        });
        expect(result, isNull);
        // The wrapper's disposed-service guard prevents the handler from
        // running, so the logger should not have seen our message.
        expect(
          cap.events.any(
            (e) => (e.message?.toString() ?? '').contains('after-dispose'),
          ),
          isFalse,
        );
      } finally {
        cap.dispose();
      }
    });
  });
}
