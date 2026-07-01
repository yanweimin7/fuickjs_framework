import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/service/js_error_bus.dart';

void main() {
  group('JsErrorInfo', () {
    test('fromMap parses all fields when present', () {
      final m = <String, dynamic>{
        'message': 'ReferenceError: foo is not defined',
        'stack': 'at line 1\nat line 2',
        'source': 'main.js',
        'detail': {'col': 5},
        'timestamp': 1700000000000,
      };
      final info = JsErrorInfo.fromMap(m);
      expect(info.message, 'ReferenceError: foo is not defined');
      expect(info.stack, 'at line 1\nat line 2');
      expect(info.source, 'main.js');
      expect(info.detail, {'col': 5});
      expect(info.timestamp, 1700000000000);
    });

    test('fromMap tolerates missing optional fields', () {
      final m = <String, dynamic>{
        'message': 'Oops',
        'source': 'app.js',
        'timestamp': 1234,
      };
      final info = JsErrorInfo.fromMap(m);
      expect(info.message, 'Oops');
      expect(info.stack, isNull);
      expect(info.source, 'app.js');
      expect(info.detail, isNull);
      expect(info.timestamp, 1234);
    });

    test('fromMap defaults source to "unknown" when missing', () {
      final info = JsErrorInfo.fromMap(<String, dynamic>{
        'message': 'oops',
        'timestamp': 1,
      });
      expect(info.source, 'unknown');
    });

    test('fromMap defaults message to "" when missing', () {
      final info = JsErrorInfo.fromMap(<String, dynamic>{
        'source': 'a.js',
        'timestamp': 1,
      });
      expect(info.message, '');
    });

    test('fromMap coerces non-string values to strings via toString()', () {
      final info = JsErrorInfo.fromMap(<String, dynamic>{
        'message': 42,
        'stack': true,
        'source': ['a', 'b'],
        'timestamp': 5,
      });
      expect(info.message, '42');
      expect(info.stack, 'true');
      expect(info.source, '[a, b]');
    });

    test('fromMap fills missing timestamp with current millis', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final info = JsErrorInfo.fromMap(<String, dynamic>{
        'message': 'oops',
        'source': 'a.js',
      });
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(info.timestamp, greaterThanOrEqualTo(before));
      expect(info.timestamp, lessThanOrEqualTo(after));
    });

    test('fromMap accepts double timestamp and converts to int', () {
      final info = JsErrorInfo.fromMap(<String, dynamic>{
        'message': 'oops',
        'source': 'a.js',
        'timestamp': 12345.67,
      });
      expect(info.timestamp, 12345);
    });

    test('toMap round-trips via fromMap', () {
      final original = JsErrorInfo(
        message: 'TypeError: x.y is not a function',
        stack: 'at callX (a.js:10:5)',
        source: 'worker.js',
        detail: <String, dynamic>{'foo': 'bar'},
        timestamp: 1710000000000,
      );
      final m = original.toMap();
      final restored = JsErrorInfo.fromMap(m);
      expect(restored.message, original.message);
      expect(restored.stack, original.stack);
      expect(restored.source, original.source);
      expect(restored.detail, original.detail);
      expect(restored.timestamp, original.timestamp);
    });

    test('toMap contains all five keys even when optional fields are null', () {
      final info = JsErrorInfo(
        message: 'm',
        source: 's',
        timestamp: 1,
      );
      final m = info.toMap();
      expect(m.keys.toSet(), {'message', 'stack', 'source', 'detail', 'timestamp'});
      expect(m['message'], 'm');
      expect(m['stack'], isNull);
      expect(m['source'], 's');
      expect(m['detail'], isNull);
      expect(m['timestamp'], 1);
    });

    test('detail can hold arbitrary types (Map, List, primitives)', () {
      JsErrorInfo mk(dynamic d) => JsErrorInfo(
            message: 'm',
            source: 's',
            timestamp: 1,
            detail: d,
          );
      expect(mk({'a': 1}).detail, {'a': 1});
      expect(mk([1, 2, 3]).detail, [1, 2, 3]);
      expect(mk('string-detail').detail, 'string-detail');
      expect(mk(42).detail, 42);
      expect(mk(null).detail, isNull);
    });
  });

  group('JsErrorBus', () {
    test('instance is a singleton', () {
      expect(identical(JsErrorBus.instance, JsErrorBus.instance), isTrue);
    });

    test('stream is broadcast — multiple subscribers all receive events', () async {
      final bus = JsErrorBus.instance;
      final a = <JsErrorInfo>[];
      final b = <JsErrorInfo>[];
      final subA = bus.stream.listen(a.add);
      final subB = bus.stream.listen(b.add);

      bus.report(JsErrorInfo(message: 'm1', source: 's', timestamp: 1));
      // Let the broadcast controller flush.
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(1));
      expect(b, hasLength(1));
      expect(a.first.message, 'm1');
      expect(b.first.message, 'm1');

      await subA.cancel();
      await subB.cancel();
    });

    test('report preserves the order of events for a single subscriber',
        () async {
      final bus = JsErrorBus.instance;
      final received = <String>[];
      final sub = bus.stream.listen((e) => received.add(e.message));

      bus.report(JsErrorInfo(message: 'a', source: 's', timestamp: 1));
      bus.report(JsErrorInfo(message: 'b', source: 's', timestamp: 2));
      bus.report(JsErrorInfo(message: 'c', source: 's', timestamp: 3));
      await Future<void>.delayed(Duration.zero);

      expect(received, ['a', 'b', 'c']);

      await sub.cancel();
    });

    test('report is a no-op when no one is listening (no throw)', () {
      final bus = JsErrorBus.instance;
      // No subscribers attached.
      expect(
        () => bus.report(JsErrorInfo(message: 'm', source: 's', timestamp: 1)),
        returnsNormally,
      );
    });

    test('late subscriber does not receive past events (broadcast semantics)',
        () async {
      final bus = JsErrorBus.instance;
      bus.report(JsErrorInfo(message: 'old', source: 's', timestamp: 1));
      // Yield once so the broadcast controller drops the buffer before we subscribe.
      await Future<void>.delayed(Duration.zero);

      final received = <String>[];
      final sub = bus.stream.listen((e) => received.add(e.message));
      bus.report(JsErrorInfo(message: 'new', source: 's', timestamp: 2));
      await Future<void>.delayed(Duration.zero);

      expect(received, ['new']);
      await sub.cancel();
    });

    test('cancelling a subscription stops further delivery to that listener',
        () async {
      final bus = JsErrorBus.instance;
      final received = <String>[];
      final sub = bus.stream.listen((e) => received.add(e.message));

      bus.report(JsErrorInfo(message: 'first', source: 's', timestamp: 1));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      bus.report(JsErrorInfo(message: 'second', source: 's', timestamp: 2));
      await Future<void>.delayed(Duration.zero);

      expect(received, ['first']);
    });

    test('handle concurrent report() calls from multiple microtasks', () async {
      final bus = JsErrorBus.instance;
      final count = 50;
      final received = <int>[];
      final sub = bus.stream.listen((e) => received.add(e.timestamp));

      await Future.wait(List.generate(count, (i) {
        return Future(() {
          bus.report(JsErrorInfo(message: 'm$i', source: 's', timestamp: i));
        });
      }));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(count));
      // Order is not guaranteed, but the set must match exactly.
      expect(received.toSet(), {for (var i = 0; i < count; i++) i});
      await sub.cancel();
    });
  });
}
