library;

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/heart/data/heart_repository_interface.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

class ApiHeartRepository implements HeartRepositoryInterface {
  ApiHeartRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<HeartDaySummary> getHeartSummary() async {
    final response = await _api.get('/api/v1/heart/summary');
    return HeartDaySummary.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<HeartTrendDay>> getHeartTrend(String range) async {
    const validRanges = {'7d', '30d'};
    if (!validRanges.contains(range)) {
      throw ArgumentError.value(range, 'range', 'must be one of $validRanges');
    }
    final response = await _api.get(
      '/api/v1/heart/trend',
      queryParameters: {'range': range},
    );
    final body = response.data as Map<String, dynamic>;
    return (body['days'] as List<dynamic>)
        .map((e) => HeartTrendDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AllDataDay>> getHeartAllData(String range) async {
    const validRanges = {'7d', '30d', '3m', '6m', '1y'};
    if (!validRanges.contains(range)) {
      throw ArgumentError.value(range, 'range', 'must be one of $validRanges');
    }
    final response = await _api.get(
      '/api/v1/heart/all-data',
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
