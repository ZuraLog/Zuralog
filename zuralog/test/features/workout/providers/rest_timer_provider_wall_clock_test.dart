/// Zuralog — Rest Timer Wall-Clock Tests.
///
/// Verifies the wall-clock semantics of [RestTimerNotifier]: remaining time
/// is derived from `DateTime.now() - restStartedAt` on every read, so missed
/// or delayed ticks never cause drift.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/workout/data/rest_timer_storage.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

/// In-memory fake that satisfies [RestTimerStorage]'s public surface without
/// touching SharedPreferences. `extends` via composition is awkward since
/// [RestTimerStorage] holds a real [SharedPreferences]; the tests below don't
/// need persistence across notifier recreation, so a no-op stand-in suffices.
class _FakeRestTimerStorage implements RestTimerStorage {
  RestTimerState? _stored;

  @override
  Future<void> save(RestTimerState s) async {
    _stored = s.restStartedAt == null ? null : s;
  }

  @override
  Future<RestTimerState?> load() async => _stored;

  @override
  Future<void> clear() async {
    _stored = null;
  }

  // Unused by tests — required to satisfy the interface.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RestTimerNotifier — wall-clock semantics', () {
    test('remaining is computed from wall clock', () {
      fakeAsync((async) {
        final notifier = RestTimerNotifier(_FakeRestTimerStorage());
        // Let the async load complete (fires even though storage is empty).
        async.flushMicrotasks();

        notifier.start(60);
        async.elapse(const Duration(seconds: 10));

        expect(notifier.state.remainingSecondsInt, 50);
        notifier.dispose();
      });
    });

    test('addTime extends without resetting the start stamp', () {
      fakeAsync((async) {
        final notifier = RestTimerNotifier(_FakeRestTimerStorage());
        async.flushMicrotasks();

        notifier.start(30);
        async.elapse(const Duration(seconds: 10));
        notifier.addTime(30);

        // 30 (planned) + 30 (added) - 10 (elapsed) = 50.
        expect(notifier.state.remainingSecondsInt, 50);
        notifier.dispose();
      });
    });

    test('missing a tick still gives correct remaining', () {
      fakeAsync((async) {
        final notifier = RestTimerNotifier(_FakeRestTimerStorage());
        async.flushMicrotasks();

        notifier.start(60);
        // Jump forward 30s in one go — the 1 Hz ticker will have fired many
        // times, but remaining must still be derived from wall clock.
        async.elapse(const Duration(seconds: 30));

        expect(notifier.state.remainingSecondsInt, 30);
        notifier.dispose();
      });
    });

    test('hasExpired flips after total duration', () {
      fakeAsync((async) {
        final notifier = RestTimerNotifier(_FakeRestTimerStorage());
        async.flushMicrotasks();

        notifier.start(5);
        async.elapse(const Duration(seconds: 6));

        expect(notifier.state.hasExpired, isTrue);
        notifier.dispose();
      });
    });

    test('auto-dismiss clears state 3s after expiry', () {
      fakeAsync((async) {
        final notifier = RestTimerNotifier(_FakeRestTimerStorage());
        async.flushMicrotasks();

        notifier.start(5);
        // 5s rest + 3s auto-dismiss window + 1s slack = 9s total.
        async.elapse(const Duration(seconds: 9));

        expect(notifier.state.restStartedAt, isNull);
        notifier.dispose();
      });
    });
  });
}
