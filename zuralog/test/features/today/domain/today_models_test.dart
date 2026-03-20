// zuralog/test/features/today/domain/today_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

void main() {
  group('InsightCard.fromJson', () {
    test('reads body field not summary', () {
      final card = InsightCard.fromJson({
        'id': 'abc',
        'title': 'Test',
        'body': 'The real body text',
        'type': 'trend',
        'created_at': null,
        'read_at': null,
      });
      expect(card.summary, equals('The real body text'));
    });

    test('isRead is true when read_at is non-null', () {
      final card = InsightCard.fromJson({
        'id': 'abc',
        'title': 'Test',
        'body': 'Body',
        'type': 'trend',
        'read_at': '2026-03-18T06:00:00Z',
      });
      expect(card.isRead, isTrue);
    });

    test('isRead is false when read_at is null', () {
      final card = InsightCard.fromJson({
        'id': 'abc',
        'title': 'Test',
        'body': 'Body',
        'type': 'trend',
        'read_at': null,
      });
      expect(card.isRead, isFalse);
    });
  });

  group('HealthScoreData.fromJson', () {
    test('parses weekChange from week_change field', () {
      final data = HealthScoreData.fromJson({
        'score': 82,
        'data_days': 14,
        'week_change': 6,
      });
      expect(data.weekChange, equals(6));
      expect(data.dataDays, equals(14));
    });

    test('weekChange is null when field absent', () {
      final data = HealthScoreData.fromJson({
        'score': 75,
        'data_days': 10,
      });
      expect(data.weekChange, isNull);
    });

    test('parses negative weekChange', () {
      final data = HealthScoreData.fromJson({
        'score': 60,
        'data_days': 21,
        'week_change': -3,
      });
      expect(data.weekChange, equals(-3));
    });

    test('parses history array into trend', () {
      final data = HealthScoreData.fromJson({
        'score': 80,
        'data_days': 7,
        'history': [
          {'date': '2026-03-14', 'score': 72},
          {'date': '2026-03-15', 'score': 78},
        ],
      });
      expect(data.trend, equals([72.0, 78.0]));
    });

    test('falls back to legacy trend array when no history', () {
      final data = HealthScoreData.fromJson({
        'score': 80,
        'data_days': 7,
        'trend': [70.0, 75.0, 80.0],
      });
      expect(data.trend, equals([70.0, 75.0, 80.0]));
    });
  });

  group('InsightDetail.fromJson', () {
    test('reads body field not summary', () {
      final detail = InsightDetail.fromJson({
        'id': 'xyz',
        'title': 'Detail',
        'body': 'Detailed body text',
        'reasoning': 'Because reasons',
        'type': 'anomaly',
        'data_points': [],
        'sources': [],
      });
      expect(detail.summary, equals('Detailed body text'));
    });
  });
}
