import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

void main() {
  group('SupplementEntry', () {
    test('fromJson maps all fields', () {
      final entry = SupplementEntry.fromJson({
        'id': 'abc',
        'name': 'Vitamin D',
        'dose': '5000 IU',
        'timing': 'morning',
        'dose_amount': 5000.0,
        'dose_unit': 'IU',
        'form': 'softgel',
      });

      expect(entry.id, 'abc');
      expect(entry.name, 'Vitamin D');
      expect(entry.dose, '5000 IU');
      expect(entry.timing, 'morning');
      expect(entry.doseAmount, 5000.0);
      expect(entry.doseUnit, 'IU');
      expect(entry.form, 'softgel');
    });

    test('fromJson handles null optional fields', () {
      final entry = SupplementEntry.fromJson({
        'id': 'xyz',
        'name': 'Magnesium',
      });

      expect(entry.dose, isNull);
      expect(entry.timing, isNull);
      expect(entry.doseAmount, isNull);
      expect(entry.doseUnit, isNull);
      expect(entry.form, isNull);
    });

    test('toJson serializes all non-null fields', () {
      const entry = SupplementEntry(
        id: 'abc',
        name: 'Vitamin D',
        dose: '5000 IU',
        timing: 'morning',
        doseAmount: 5000.0,
        doseUnit: 'IU',
        form: 'softgel',
      );

      final json = entry.toJson();
      expect(json['id'], 'abc');
      expect(json['name'], 'Vitamin D');
      expect(json['dose'], '5000 IU');
      expect(json['timing'], 'morning');
      expect(json['dose_amount'], 5000.0);
      expect(json['dose_unit'], 'IU');
      expect(json['form'], 'softgel');
    });

    test('toJson omits null fields', () {
      const entry = SupplementEntry(id: 'x', name: 'Zinc');
      final json = entry.toJson();
      expect(json.containsKey('dose'), isFalse);
      expect(json.containsKey('timing'), isFalse);
      expect(json.containsKey('dose_amount'), isFalse);
      expect(json.containsKey('dose_unit'), isFalse);
      expect(json.containsKey('form'), isFalse);
    });

    test('copyWith updates only specified fields', () {
      const original = SupplementEntry(
        id: 'abc',
        name: 'Vitamin D',
        doseAmount: 5000.0,
        doseUnit: 'IU',
      );
      final updated = original.copyWith(form: () => 'capsule');
      expect(updated.id, 'abc');
      expect(updated.doseAmount, 5000.0);
      expect(updated.form, 'capsule');
    });

    test('equality: same fields are equal', () {
      const a = SupplementEntry(
        id: 'abc',
        name: 'Vitamin D',
        doseAmount: 5000.0,
        doseUnit: 'IU',
        form: 'softgel',
      );
      const b = SupplementEntry(
        id: 'abc',
        name: 'Vitamin D',
        doseAmount: 5000.0,
        doseUnit: 'IU',
        form: 'softgel',
      );
      const c = SupplementEntry(id: 'xyz', name: 'Zinc');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
