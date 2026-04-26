library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/workout/domain/steps_summary.dart';

// ── History provider ──────────────────────────────────────────────────────────

/// Fetches the last 7 days of daily step data and computes [StepsSummary].
///
/// Uses [DataRepository.getMetricDetail] which calls
/// GET /api/v1/analytics/metric?metric_id=steps&time_range=7D.
final stepsHistoryProvider =
    FutureProvider.autoDispose<StepsSummary>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);

  try {
    final detail = await repo.getMetricDetail(
      metricId: 'steps',
      timeRange: '7D',
    );
    final points = detail.series.dataPoints;

    final todayCount =
        points.isNotEmpty ? points.last.value.round() : 0;

    final nonZero = points.where((p) => p.value > 0).toList();
    final weekAverage = nonZero.isEmpty
        ? 0.0
        : nonZero.map((p) => p.value).reduce((a, b) => a + b) /
            nonZero.length;

    final bestThisWeek = points.isEmpty
        ? 0
        : points.map((p) => p.value.round()).reduce(math.max);

    var consecutive = 0;
    for (final p in points.reversed) {
      if (p.value > 0) {
        consecutive++;
      } else {
        break;
      }
    }

    final smartTarget = weekAverage > 0
        ? ((weekAverage * 1.05) / 100).round() * 100
        : 0;

    return StepsSummary(
      dataPoints: points,
      todayCount: todayCount,
      weekAverage: weekAverage,
      bestThisWeek: bestThisWeek,
      consecutiveDays: consecutive,
      smartTarget: smartTarget,
    );
  } catch (_) {
    return StepsSummary.empty;
  }
});

// ── Local toggle providers ────────────────────────────────────────────────────

const _kSmartTargetKey = 'steps_smart_target_enabled';
const _kRecoveryAwareKey = 'steps_recovery_aware_enabled';

class _BoolToggleNotifier extends StateNotifier<bool> {
  _BoolToggleNotifier(this._key, bool initial) : super(initial) {
    _load();
  }

  final String _key;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? state;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// Whether the adaptive "sweet spot" target is shown. Default: true.
final smartTargetEnabledProvider =
    StateNotifierProvider<_BoolToggleNotifier, bool>(
        (ref) => _BoolToggleNotifier(_kSmartTargetKey, true));

/// Whether the sweet spot adjusts based on recovery data. Default: false (opt-in).
final recoveryAwareEnabledProvider =
    StateNotifierProvider<_BoolToggleNotifier, bool>(
        (ref) => _BoolToggleNotifier(_kRecoveryAwareKey, false));
