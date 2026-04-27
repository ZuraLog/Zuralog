import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/supplement_conflict.dart';

void main() {
  group('SupplementConflict', () {
    test('fromJson parses all fields correctly', () {
      final json = <String, dynamic>{
        'has_conflict': true,
        'conflict_type': 'duplicate',
        'conflicting_name': 'Vitamin D',
        'message': 'You already have "Vitamin D" in your stack.',
      };
      final conflict = SupplementConflict.fromJson(json);
      expect(conflict.hasConflict, isTrue);
      expect(conflict.conflictType, 'duplicate');
      expect(conflict.conflictingName, 'Vitamin D');
      expect(conflict.message, 'You already have "Vitamin D" in your stack.');
    });

    test('fromJson handles null optional fields', () {
      final json = <String, dynamic>{
        'has_conflict': false,
        'conflict_type': null,
        'conflicting_name': null,
        'message': null,
      };
      final conflict = SupplementConflict.fromJson(json);
      expect(conflict.hasConflict, isFalse);
      expect(conflict.conflictType, isNull);
      expect(conflict.conflictingName, isNull);
      expect(conflict.message, isNull);
    });

    test('none constant has hasConflict == false', () {
      expect(SupplementConflict.none.hasConflict, isFalse);
      expect(SupplementConflict.none.conflictType, isNull);
      expect(SupplementConflict.none.conflictingName, isNull);
      expect(SupplementConflict.none.message, isNull);
    });
  });
}
