/// Bundles the four hero rail metrics into a single subscription target.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
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

  final real = BodyNowMetrics(
    readiness: readiness,
    hrvMs: hrv?.valueMs,
    hrvDeltaPct: hrv?.deltaPct,
    rhrBpm: rhr?.valueBpm,
    rhrDeltaBpm: rhr?.deltaBpm,
    sleepMinutes: sleep?.durationMinutes,
    sleepQuality: sleep?.quality,
  );

  // Debug builds: if nothing wired real data yet, show demo values so the
  // hero rail looks alive during design iteration. Release builds always
  // return the real bundle (empty until HealthKit/Health Connect plumbing
  // lands).
  final anyReal = readiness.hasSignal ||
      real.hrvMs != null ||
      real.rhrBpm != null ||
      real.sleepMinutes != null;
  if (kDebugMode && !anyReal) return _demoMetrics;
  return real;
});

const BodyNowMetrics _demoMetrics = BodyNowMetrics(
  readiness: ReadinessScore(value: 86, delta: 4),
  hrvMs: 58,
  hrvDeltaPct: 12,
  rhrBpm: 52,
  rhrDeltaBpm: -3,
  sleepMinutes: 462, // 7h 42m
  sleepQuality: 82,
);

Future<T?> _safe<T>(Ref ref, FutureProvider<T> p) async {
  try {
    return await ref.watch(p.future);
  } catch (_) {
    return null;
  }
}
