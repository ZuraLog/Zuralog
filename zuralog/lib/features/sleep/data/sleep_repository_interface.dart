// zuralog/lib/features/sleep/data/sleep_repository_interface.dart
library;

import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

abstract interface class SleepRepositoryInterface {
  Future<SleepDaySummary> getSleepSummary();
  Future<List<SleepTrendDay>> getSleepTrend(String range);

  /// Returns per-day rows for every sleep metric. Valid range values:
  /// '7d', '30d', '3m', '6m', '1y'. Throws [ArgumentError] for unknown ranges.
  Future<List<AllDataDay>> getSleepAllData(String range);
}
