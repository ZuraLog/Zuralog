/// Zuralog — Rest Timer Wall-Clock Tests.
///
/// Verifies the wall-clock semantics of [RestTimerNotifier]: remaining time
/// is derived from `DateTime.now() - restStartedAt` on every read, so missed
/// or delayed ticks never cause drift.
///
/// Also covers the Phase 8 countdown-feedback behaviour: selection ticks at
/// T-3/T-2/T-1 and a single "success" heavy pulse + chime at T-0, each
/// edge-triggered on whole-second transitions.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/haptics/haptic_service.dart';
import 'package:zuralog/features/workout/audio/rest_sound_service.dart';
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

/// Records every haptic invocation so tests can assert call counts/types.
///
/// [selectionTick] → `'tick'`, [success] → `'success'`. Other methods are
/// unused by the notifier but recorded for completeness.
class _SpyHapticService extends HapticService {
  _SpyHapticService() : super(enabled: true);

  final List<String> calls = [];

  @override
  Future<void> light() async => calls.add('light');

  @override
  Future<void> medium() async => calls.add('medium');

  @override
  Future<void> success() async => calls.add('success');

  @override
  Future<void> warning() async => calls.add('warning');

  @override
  Future<void> selectionTick() async => calls.add('tick');
}

/// Records every [playRestComplete] invocation.
class _SpyRestSoundService implements RestSoundService {
  int plays = 0;

  @override
  Future<void> playRestComplete() async {
    plays++;
  }
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

  group('RestTimerNotifier — countdown feedback', () {
    test('fires selection ticks at T-3, T-2, T-1 and success at T-0', () {
      fakeAsync((async) {
        final haptics = _SpyHapticService();
        final sound = _SpyRestSoundService();
        final notifier = RestTimerNotifier(
          _FakeRestTimerStorage(),
          haptics: haptics,
          sound: sound,
        );
        async.flushMicrotasks();

        notifier.start(5);
        // Run just past expiry so the T-0 edge is crossed once.
        async.elapse(const Duration(seconds: 6));

        // Expect exactly three selection ticks (T-3, T-2, T-1) and one
        // success pulse (T-0). Auto-dismiss will also fire `skip()` shortly
        // after, but the feedback counts should not grow beyond this.
        expect(
          haptics.calls.where((c) => c == 'tick').length,
          3,
          reason: 'one tick per second at T-3, T-2, T-1',
        );
        expect(
          haptics.calls.where((c) => c == 'success').length,
          1,
          reason: 'single success pulse at T-0',
        );
        expect(sound.plays, 1, reason: 'one chime at T-0');

        notifier.dispose();
      });
    });

    test('skips the chime when rest-sound preference is disabled', () {
      fakeAsync((async) {
        final haptics = _SpyHapticService();
        final sound = _SpyRestSoundService();
        final notifier = RestTimerNotifier(
          _FakeRestTimerStorage(),
          haptics: haptics,
          sound: sound,
          isRestSoundEnabled: () => false,
        );
        async.flushMicrotasks();

        notifier.start(3);
        async.elapse(const Duration(seconds: 4));

        // Haptics still fire (they follow the device's haptic toggle), but
        // the chime stays silent.
        expect(haptics.calls.where((c) => c == 'success').length, 1);
        expect(sound.plays, 0);

        notifier.dispose();
      });
    });

    test('does not fire feedback when no haptic service is wired', () {
      fakeAsync((async) {
        final sound = _SpyRestSoundService();
        final notifier = RestTimerNotifier(
          _FakeRestTimerStorage(),
          sound: sound,
        );
        async.flushMicrotasks();

        notifier.start(3);
        async.elapse(const Duration(seconds: 4));

        // Sound still plays (it's independent of haptics). Just ensure no
        // crash on the null haptic path.
        expect(sound.plays, 1);

        notifier.dispose();
      });
    });

    test('addTime past zero re-arms feedback for a second T-3 window', () {
      fakeAsync((async) {
        final haptics = _SpyHapticService();
        final sound = _SpyRestSoundService();
        final notifier = RestTimerNotifier(
          _FakeRestTimerStorage(),
          haptics: haptics,
          sound: sound,
        );
        async.flushMicrotasks();

        notifier.start(3);
        // Elapse 1s — only T-2 window coming next on the ticker.
        async.elapse(const Duration(seconds: 1));
        // Add 10s before expiry. Remaining is now ~12s, so a fresh
        // T-3/T-2/T-1/T-0 sequence should eventually fire once more.
        notifier.addTime(10);
        // Run well past the new expiry (12s more + auto-dismiss slack).
        async.elapse(const Duration(seconds: 14));

        // First window fired one tick (T-2) before addTime reset the edge
        // sentinel; second window fires three more (T-3/T-2/T-1) and one
        // success pulse. Total ticks across both windows: 1 + 3 = 4.
        expect(haptics.calls.where((c) => c == 'tick').length, 4);
        expect(haptics.calls.where((c) => c == 'success').length, 1);
        expect(sound.plays, 1);

        notifier.dispose();
      });
    });
  });
}
