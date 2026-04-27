import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/timing_suggestion.dart';

void main() {
  group('TimingSuggestion', () {
    test('fromJson parses tip correctly', () {
      final r = TimingSuggestion.fromJson({'tip': 'Take with food.'});
      expect(r.tip, equals('Take with food.'));
      expect(r.hasTip, isTrue);
    });

    test('fromJson handles null tip', () {
      final r = TimingSuggestion.fromJson({'tip': null});
      expect(r.hasTip, isFalse);
    });

    test('fromJson handles missing tip key', () {
      final r = TimingSuggestion.fromJson({});
      expect(r.hasTip, isFalse);
    });
  });
}
