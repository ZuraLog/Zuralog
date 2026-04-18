// zuralog/lib/features/sleep/data/sleep_repository_interface.dart
library;

import 'package:zuralog/features/sleep/domain/sleep_models.dart';

abstract interface class SleepRepositoryInterface {
  Future<SleepDaySummary> getSleepSummary();
  Future<List<SleepTrendDay>> getSleepTrend(String range);
}
