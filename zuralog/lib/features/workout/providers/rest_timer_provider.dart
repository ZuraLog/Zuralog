/// Zuralog — Rest Timer Provider.
///
/// Global state for the rest-between-sets countdown timer.
/// State lives here (not in widget state) so it survives navigation
/// and can be driven from a set-row deep in a ListView.
///
/// Wall-clock design: the timer stores a [DateTime] start stamp and computes
/// remaining time from `DateTime.now() - restStartedAt` on every read. The
/// 1 Hz ticker only triggers rebuilds — it never mutates remaining seconds.
/// This means the timer stays correct even if ticks are delayed, dropped,
/// or paused (OS throttling, app backgrounded), and it survives notifier
/// recreation via [RestTimerStorage] persistence.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/workout/data/rest_timer_storage.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class RestTimerState {
  const RestTimerState({
    this.restStartedAt,
    this.plannedDurationSeconds = 0,
    this.addedSeconds = 0,
    this.isMinimized = false,
    this.tick = 0,
  });

  /// When rest started. Null = no active timer.
  final DateTime? restStartedAt;

  /// Initial rest duration requested by the caller (not including [addedSeconds]).
  final int plannedDurationSeconds;

  /// Extra seconds tacked on via `+30s` taps. Added to planned on every read.
  final int addedSeconds;

  /// Collapsed to mini pill vs expanded full sheet.
  final bool isMinimized;

  /// Incremented on every 1 Hz tick. Used only to force rebuilds — never for math.
  final int tick;

  bool get isVisible => restStartedAt != null;

  Duration get totalDuration =>
      Duration(seconds: plannedDurationSeconds + addedSeconds);

  /// Remaining, floored at zero. Use this for UI display.
  ///
  /// Reads time through [clock] (not `DateTime.now()`) so tests can swap in
  /// a fake clock via `withClock` / `fake_async`. In production this is a
  /// zero-cost indirection that delegates to `DateTime.now()`.
  Duration get remaining {
    if (restStartedAt == null) return Duration.zero;
    final r = totalDuration - clock.now().difference(restStartedAt!);
    return r.isNegative ? Duration.zero : r;
  }

  /// Remaining including negative values past expiry. Use for expiry checks.
  Duration get remainingSigned {
    if (restStartedAt == null) return Duration.zero;
    return totalDuration - clock.now().difference(restStartedAt!);
  }

  bool get hasExpired =>
      restStartedAt != null && remainingSigned <= Duration.zero;

  bool get isActive => restStartedAt != null && !hasExpired;

  int get remainingSecondsInt => remaining.inSeconds;

  int get totalSeconds => plannedDurationSeconds + addedSeconds;

  RestTimerState copyWith({
    DateTime? restStartedAt,
    int? plannedDurationSeconds,
    int? addedSeconds,
    bool? isMinimized,
    int? tick,
    bool clearRestStartedAt = false,
  }) {
    return RestTimerState(
      restStartedAt:
          clearRestStartedAt ? null : (restStartedAt ?? this.restStartedAt),
      plannedDurationSeconds:
          plannedDurationSeconds ?? this.plannedDurationSeconds,
      addedSeconds: addedSeconds ?? this.addedSeconds,
      isMinimized: isMinimized ?? this.isMinimized,
      tick: tick ?? this.tick,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  RestTimerNotifier(this._storage) : super(const RestTimerState()) {
    _restoreFromStorage();
  }

  final RestTimerStorage _storage;
  Timer? _ticker;
  Timer? _autoDismiss;

  /// On startup, rehydrate any persisted timer state. If the rest completed
  /// more than 5 seconds ago, discard it (stale) — otherwise restore minimized
  /// and resume ticking / schedule auto-dismiss as appropriate.
  Future<void> _restoreFromStorage() async {
    final stored = await _storage.load();
    if (stored == null) return;
    if (!mounted) return;
    // If rest completed more than 5 seconds ago, discard.
    if (stored.remainingSigned < const Duration(seconds: -5)) {
      await _storage.clear();
      return;
    }
    state = stored.copyWith(isMinimized: true);
    _startTicker();
    if (stored.hasExpired) _scheduleAutoDismiss();
  }

  /// Starts a new countdown from [seconds]. Cancels any existing timer first.
  void start(int seconds) {
    _cancelAll();
    state = RestTimerState(
      restStartedAt: clock.now(),
      plannedDurationSeconds: seconds,
      addedSeconds: 0,
      isMinimized: false,
      tick: 0,
    );
    _storage.save(state);
    _startTicker();
  }

  /// Dismiss the timer immediately (skip rest or manual close).
  void skip() {
    _cancelAll();
    _storage.clear();
    state = const RestTimerState();
  }

  /// Collapse the full sheet to the mini banner.
  void minimize() {
    if (state.restStartedAt == null) return;
    state = state.copyWith(isMinimized: true);
  }

  /// Expand the mini banner back to the full sheet.
  void expand() {
    if (state.restStartedAt == null) return;
    state = state.copyWith(isMinimized: false);
  }

  /// Add [seconds] to the remaining time without resetting the start stamp.
  void addTime(int seconds) {
    if (state.restStartedAt == null) return;
    _autoDismiss?.cancel();
    _autoDismiss = null;
    state = state.copyWith(addedSeconds: state.addedSeconds + seconds);
    _storage.save(state);
    if (_ticker == null || !_ticker!.isActive) _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      state = state.copyWith(tick: state.tick + 1);
      if (state.hasExpired && _autoDismiss == null) {
        _ticker?.cancel();
        _ticker = null;
        _scheduleAutoDismiss();
      }
    });
  }

  void _scheduleAutoDismiss() {
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 3), () {
      if (mounted) skip();
    });
  }

  void _cancelAll() {
    _ticker?.cancel();
    _ticker = null;
    _autoDismiss?.cancel();
    _autoDismiss = null;
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Typed SharedPreferences wrapper for the rest timer.
final restTimerStorageProvider = Provider<RestTimerStorage>((ref) {
  return RestTimerStorage(ref.watch(prefsProvider));
});

/// Global rest timer state. NOT autoDispose — must outlive navigation.
final restTimerProvider =
    StateNotifierProvider<RestTimerNotifier, RestTimerState>(
  (ref) => RestTimerNotifier(ref.watch(restTimerStorageProvider)),
);
