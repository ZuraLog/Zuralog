import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/supplement_insight.dart';

void main() {
  group('SupplementInsightsResult', () {
    test('fromJson parses correctly', () {
      final json = <String, dynamic>{
        'insights': [
          <String, dynamic>{
            'metric_type': 'sleep_duration',
            'metric_label': 'Sleep',
            'direction': 'positive',
            'correlation': 0.42,
            'insight_text': 'Your sleep is 12% better when you take your stack.',
          },
        ],
        'data_days': 30,
        'has_enough_data': true,
      };
      final result = SupplementInsightsResult.fromJson(json);
      expect(result.insights.length, equals(1));
      expect(result.insights.first.metricLabel, equals('Sleep'));
      expect(result.insights.first.direction, equals('positive'));
      expect(result.insights.first.correlation, closeTo(0.42, 0.001));
      expect(result.dataDays, equals(30));
      expect(result.hasEnoughData, isTrue);
    });

    test('SupplementInsightsResult.empty has no insights', () {
      expect(SupplementInsightsResult.empty.insights, isEmpty);
      expect(SupplementInsightsResult.empty.hasEnoughData, isFalse);
      expect(SupplementInsightsResult.empty.dataDays, equals(0));
    });

    test('fromJson handles empty insights list', () {
      final json = <String, dynamic>{
        'insights': <dynamic>[],
        'data_days': 0,
        'has_enough_data': false,
      };
      final result = SupplementInsightsResult.fromJson(json);
      expect(result.insights, isEmpty);
      expect(result.hasEnoughData, isFalse);
    });
  });
}
