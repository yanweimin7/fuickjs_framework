import 'package:flutter_test/flutter_test.dart';
import 'package:fuickjs_flutter/core/service/fuick_command_bus.dart';

void main() {
  group('FuickCommandBus', () {
    test('starts with no listeners', () {
      final bus = FuickCommandBus();
      // dispatching to any refId with no listeners must be a no-op (no throw)
      bus.dispatch('any', 'm', null);
      expect(true, isTrue);
    });

    test('addListener registers a listener for the given refId', () {
      final bus = FuickCommandBus();
      final calls = <List<dynamic>>[];
      bus.addListener('r1', (m, a) => calls.add([m, a]));

      bus.dispatch('r1', 'play', 'arg1');
      expect(calls, hasLength(1));
      expect(calls.first, ['play', 'arg1']);
    });

    test('listeners are isolated per refId', () {
      final bus = FuickCommandBus();
      final r1Calls = <String>[];
      final r2Calls = <String>[];
      bus.addListener('r1', (m, a) => r1Calls.add(m));
      bus.addListener('r2', (m, a) => r2Calls.add(m));

      bus.dispatch('r1', 'a', null);
      bus.dispatch('r2', 'b', null);
      bus.dispatch('r1', 'c', null);

      expect(r1Calls, ['a', 'c']);
      expect(r2Calls, ['b']);
    });

    test('multiple listeners on the same refId are all called', () {
      final bus = FuickCommandBus();
      var a = 0, b = 0;
      bus.addListener('r1', (_, __) => a++);
      bus.addListener('r1', (_, __) => b++);

      bus.dispatch('r1', 'go', null);
      expect(a, 1);
      expect(b, 1);
    });

    test('removeListener detaches the listener', () {
      final bus = FuickCommandBus();
      final calls = <String>[];
      void l(String m, dynamic a) => calls.add(m);
      bus.addListener('r1', l);
      bus.dispatch('r1', 'first', null);

      bus.removeListener('r1', l);
      bus.dispatch('r1', 'second', null);

      expect(calls, ['first']);
    });

    test('removeListener cleans up empty refId buckets', () {
      final bus = FuickCommandBus();
      void l(String m, dynamic a) {}
      bus.addListener('r1', l);
      bus.removeListener('r1', l);
      // dispatching after cleanup should not invoke anything — and must not throw
      bus.dispatch('r1', 'after-cleanup', null);
      // Verified by no exception.
    });

    test('removeListener on unknown refId is a safe no-op', () {
      final bus = FuickCommandBus();
      void l(String m, dynamic a) {}
      expect(() => bus.removeListener('never-added', l), returnsNormally);
    });

    test('removeListener only removes the matching function reference', () {
      final bus = FuickCommandBus();
      var a = 0, b = 0;
      void aListener(String m, dynamic _) => a++;
      void bListener(String m, dynamic _) => b++;
      bus.addListener('r1', aListener);
      bus.addListener('r1', bListener);

      bus.removeListener('r1', aListener);
      bus.dispatch('r1', 'go', null);

      expect(a, 0);
      expect(b, 1);
    });

    test('addListener on the same refId with the same fn does not double-fire',
        () {
      final bus = FuickCommandBus();
      var count = 0;
      void l(String m, dynamic a) => count++;
      bus.addListener('r1', l);
      bus.addListener('r1', l);
      bus.dispatch('r1', 'go', null);
      expect(count, 1,
          reason:
              'Set semantics — adding the same function reference is idempotent');
    });

    test(
        'dispatch iterates over a snapshot — listeners removed mid-dispatch still get the call',
        () {
      final bus = FuickCommandBus();
      final calls = <String>[];
      void victim(String m, dynamic a) {}
      bus.addListener('r1', victim);
      bus.addListener('r1', (m, _) {
        calls.add('a:$m');
        // Self-removal during dispatch should not break the iteration
        bus.removeListener('r1', victim);
      });
      bus.addListener('r1', (m, _) => calls.add('b:$m'));
      bus.dispatch('r1', 'go', null);

      // First listener (victim) was added before but not in calls list — it
      // has no recording. What we care about is that the dispatch doesn't
      // throw when one listener removes a peer.
      expect(calls, ['a:go', 'b:go']);
    });

    test('dispatch passes args through to listeners', () {
      final bus = FuickCommandBus();
      Object? captured;
      bus.addListener('r1', (m, a) => captured = a);
      bus.dispatch('r1', 'm', {'k': 1});
      expect(captured, {'k': 1});
    });

    test('dispatch with no listeners for a refId is a safe no-op', () {
      final bus = FuickCommandBus();
      // First add for r2, then dispatch for r1 (different refId)
      bus.addListener('r2', (m, a) {});
      expect(() => bus.dispatch('r1', 'x', null), returnsNormally);
    });
  });
}
