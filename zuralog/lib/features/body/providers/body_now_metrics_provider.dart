/// Bundles the four hero rail metrics into a single subscription target.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/body/domain/readiness_score.dart';
import 'package:zuralog/features/body/providers/readiness_score_provider.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart'
    show hrvTodayProvider, rhrTodayProvider;
import 'package:zuralog/features/sleep/providers/sleep_providers.dart'
    show sleepLastNightProvider;

class BodyNowMetrics {
  const BodyNowMetrics({
    required this.readiness,
    required this.hrvMs,
    required this.hrvDeltaPct,
    required this.rhrBpm,
    required this.rhrDeltaBpm,
    required this.sleepMinutes,
    required this.sleepQuality,
  });

  final ReadinessScore readiness;
  final int? hrvMs;
  final int? hrvDeltaPct;
  final int? rhrBpm;
  final int? rhrDeltaBpm;
  final int? sleepMinutes;
  final int? sleepQuality;

  static const BodyNowMetrics empty = BodyNowMetrics(
    readiness: ReadinessScore.empty,
    hrvMs: null,
    hrvDeltaPct: null,
    rhrBpm: null,
    rhrDeltaBpm: null,
    sleepMinutes: null,
    sleepQuality: null,
  );
}

final bodyNowMetricsProvider = FutureProvider<BodyNowMetrics>((ref) async {
  final readiness = await ref.watch(readinessScoreProvider.future);

  final hrv = await _safe(ref, hrvTodayProvider);
  final rhr = await _safe(ref, rhrTodayProvider);
  final sleep = await _safe(ref, sleepLastNightProvider);

  return BodyNowMetrics(
    readiness: readiness,
    hrvMs: hrv?.valueMs,
    hrvDeltaPct: hrv?.deltaPct,
    rhrBpm: rhr?.valueBpm,
    rhrDeltaBpm: rhr?.deltaBpm,
    sleepMinutes: sleep?.durationMinutes,
    sleepQuality: sleep?.quality,
  );
});

Future<T?> _safe<T>(Ref ref, FutureProvider<T> p) async {
  try {
    return await ref.watch(p.future);
  } catch (_) {
    return null;
  }
}
