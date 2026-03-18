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
