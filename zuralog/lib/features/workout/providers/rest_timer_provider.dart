/// Zuralog — Rest Timer Provider.
///
/// Global state for the rest-between-sets countdown timer.
/// State lives here (not in widget state) so it survives navigation
/// and can be driven from a set-row deep in a ListView.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class RestTimerState {
  const RestTimerState({
    this.remainingSeconds,
    this.totalSeconds = 0,
    this.isMinimized = false,
  });

  /// Null = no active timer. 0 = expired (auto-dismiss pending).
  final int? remainingSeconds;
  final int totalSeconds;
  final bool isMinimized;

  bool get isActive => remainingSeconds != null && remainingSeconds! > 0;
  bool get hasExpired => remainingSeconds != null && remainingSeconds! <= 0;
  bool get isVisible => remainingSeconds != null;

  RestTimerState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    bool? isMinimized,
    bool clearRemaining = false,
  }) {
    return RestTimerState(
      remainingSeconds: clearRemaining ? null : (remainingSeconds ?? this.remainingSeconds),
      totalSeconds: totalSeconds ?? this.totalSeconds,
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  RestTimerNotifier() : super(const RestTimerState());

  Timer? _ticker;
  Timer? _autoDismiss;

  /// Starts a new countdown from [seconds]. Cancels any existing timer first.
  void start(int seconds) {
    _cancelAll();
    state = RestTimerState(
      remainingSeconds: seconds,
      totalSeconds: seconds,
      isMinimized: false,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = (state.remainingSeconds ?? 0) - 1;
      state = state.copyWith(remainingSeconds: next);
      if (next <= 0) {
        _ticker?.cancel();
        _ticker = null;
        // Auto-dismiss 3 seconds after expiry.
        _autoDismiss = Timer(const Duration(seconds: 3), () {
          if (mounted) skip();
        });
      }
    });
  }

  /// Dismiss the timer immediately (skip rest or manual close).
  void skip() {
    _cancelAll();
    state = const RestTimerState();
  }

  /// Collapse the full sheet to the mini banner.
  void minimize() {
    state = state.copyWith(isMinimized: true);
  }

  /// Expand the mini banner back to the full sheet.
  void expand() {
    state = state.copyWith(isMinimized: false);
  }

  /// Add [seconds] to the remaining time. Restarts the ticker if expired.
  void addTime(int seconds) {
    _autoDismiss?.cancel();
    _autoDismiss = null;
    final current = state.remainingSeconds ?? 0;
    final next = current + seconds;
    state = state.copyWith(remainingSeconds: next);
    if (_ticker == null || !_ticker!.isActive) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final n = (state.remainingSeconds ?? 0) - 1;
        state = state.copyWith(remainingSeconds: n);
        if (n <= 0) {
          _ticker?.cancel();
          _ticker = null;
          _autoDismiss = Timer(const Duration(seconds: 3), () {
            if (mounted) skip();
          });
        }
      });
    }
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

/// Global rest timer state. NOT autoDispose — must outlive navigation.
final restTimerProvider =
    StateNotifierProvider<RestTimerNotifier, RestTimerState>(
  (ref) => RestTimerNotifier(),
);
