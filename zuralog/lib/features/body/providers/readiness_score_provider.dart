/// Pure computation + Riverpod provider for the composite readiness score.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/body/domain/readiness_score.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart'
    show hrvBaselineNormalizedProvider, rhrBaselineNormalizedProvider;
import 'package:zuralog/features/sleep/providers/sleep_providers.dart'
    show sleepQualityNormalizedProvider, readinessSevenDayAverageProvider;

const double _hrvWeight = 0.5;
const double _rhrWeight = 0.3;
const double _sleepWeight = 0.2;

ReadinessScore computeReadiness({
  required double? hrvNormalized,
  required double? rhrNormalized,
  required double? sleepNormalized,
  required double? sevenDayAverage,
}) {
  final signals = <_Signal>[
    if (hrvNormalized != null) _Signal(hrvNormalized, _hrvWeight),
    if (rhrNormalized != null) _Signal(rhrNormalized, _rhrWeight),
    if (sleepNormalized != null) _Signal(sleepNormalized, _sleepWeight),
  ];
  if (signals.isEmpty) return ReadinessScore.empty;

  final weightSum = signals.fold<double>(0, (a, s) => a + s.weight);
  final weighted = signals.fold<double>(0, (a, s) => a + s.value * s.weight);
  final composite = weighted / weightSum;
  final value = ReadinessScore.clamp(composite);

  int? delta;
  if (sevenDayAverage != null) {
    delta = value - ReadinessScore.clamp(sevenDayAverage);
  }

  return ReadinessScore(
    value: value,
    delta: delta,
    hrvNormalized: hrvNormalized,
    rhrNormalized: rhrNormalized,
    sleepNormalized: sleepNormalized,
  );
}

class _Signal {
  const _Signal(this.value, this.weight);
  final double value;
  final double weight;
}

final readinessScoreProvider = FutureProvider<ReadinessScore>((ref) async {
  final hrv = await ref.watch(hrvBaselineNormalizedProvider.future);
  final rhr = await ref.watch(rhrBaselineNormalizedProvider.future);
  final sleep = await ref.watch(sleepQualityNormalizedProvider.future);
  final avg = await ref.watch(readinessSevenDayAverageProvider.future);
  return computeReadiness(
    hrvNormalized: hrv,
    rhrNormalized: rhr,
    sleepNormalized: sleep,
    sevenDayAverage: avg,
  );
});
