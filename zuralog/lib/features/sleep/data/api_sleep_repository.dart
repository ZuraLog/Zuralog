library;

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/sleep/data/sleep_repository_interface.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

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

  @override
  Future<List<AllDataDay>> getSleepAllData(String range) async {
    const validRanges = {'7d', '30d', '3m', '6m', '1y'};
    if (!validRanges.contains(range)) {
      throw ArgumentError.value(range, 'range', 'must be one of $validRanges');
    }
    final response = await _api.get(
      '/api/v1/sleep/all-data',
      queryParameters: {'range': range},
    );
    final days = response.data['days'] as List<dynamic>? ?? [];
    return days.map((e) {
      final map = e as Map<String, dynamic>;
      final rawValues = map['values'] as Map<String, dynamic>? ?? {};
      return AllDataDay(
        date: map['date'] as String? ?? '',
        isToday: map['is_today'] as bool? ?? false,
        values: rawValues.map(
          (key, value) => MapEntry(key, (value as num?)?.toDouble()),
        ),
      );
    }).toList();
  }
}
