import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/supplement_scan_result.dart';

void main() {
  test('fromJson parses all fields correctly', () {
    final json = {
      'name': 'Vitamin D3',
      'dose_amount': 5000.0,
      'dose_unit': 'IU',
      'form': 'softgel',
      'confidence': 0.92,
    };
    final result = SupplementScanResult.fromJson(json);
    expect(result.name, equals('Vitamin D3'));
    expect(result.doseAmount, equals(5000.0));
    expect(result.doseUnit, equals('IU'));
    expect(result.form, equals('softgel'));
    expect(result.confidence, equals(0.92));
  });

  test('fromJson handles null fields', () {
    final json = <String, dynamic>{};
    final result = SupplementScanResult.fromJson(json);
    expect(result.name, isNull);
    expect(result.doseAmount, isNull);
    expect(result.doseUnit, isNull);
    expect(result.form, isNull);
  });

  test('toJson round-trips correctly', () {
    const original = SupplementScanResult(
      name: 'Magnesium',
      doseAmount: 400.0,
      doseUnit: 'mg',
      form: 'capsule',
      confidence: 0.85,
    );
    final json = original.toJson();
    final restored = SupplementScanResult.fromJson(json);
    expect(restored, equals(original));
  });
}
