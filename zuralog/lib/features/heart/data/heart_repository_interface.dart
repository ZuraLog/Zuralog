library;

import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

abstract interface class HeartRepositoryInterface {
  Future<HeartDaySummary> getHeartSummary();
  Future<List<HeartTrendDay>> getHeartTrend(String range);
  Future<List<AllDataDay>> getHeartAllData(String range);
}
