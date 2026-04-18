// zuralog/lib/features/sleep/providers/sleep_providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/sleep/data/mock_sleep_repository.dart';
import 'package:zuralog/features/sleep/data/sleep_repository_interface.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';

final sleepRepositoryProvider = Provider<SleepRepositoryInterface>(
  (_) => MockSleepRepository(),
);

final sleepDaySummaryProvider = FutureProvider<SleepDaySummary>((ref) async {
  try {
    return await ref.read(sleepRepositoryProvider).getSleepSummary();
  } catch (_) {
    return SleepDaySummary.empty;
  }
});

final sleepTrendProvider =
    FutureProvider.family<List<SleepTrendDay>, String>((ref, range) async {
  try {
    return await ref.read(sleepRepositoryProvider).getSleepTrend(range);
  } catch (_) {
    return const [];
  }
});
