library;

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/sleep/data/sleep_repository_interface.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';

class ApiSleepRepository implements SleepRepositoryInterface {
  ApiSleepRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<SleepDaySummary> getSleepSummary() async {
    final response = await _api.get('/api/v1/sleep/summary');
    return SleepDaySummary.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<SleepTrendDay>> getSleepTrend(String range) async {
    final response = await _api.get(
      '/api/v1/sleep/trend',
      queryParameters: {'range': range},
    );
    final body = response.data as Map<String, dynamic>;
    return (body['days'] as List<dynamic>)
        .map((e) => SleepTrendDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
