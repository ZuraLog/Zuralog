// test/features/integrations/domain/compatible_app_test.dart

// Tests for the [CompatibleApp] data model.
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/integrations/domain/compatible_app.dart';

void main() {
  group('CompatibleApp', () {
    test('constructs with required fields', () {
      const app = CompatibleApp(
        id: 'myfitnesspal',
        name: 'MyFitnessPal',
        supportsHealthKit: true,
        supportsHealthConnect: true,
        brandColor: 0xFF0070D1,
        description: 'Track nutrition and calories.',
        dataFlowExplanation:
            'MyFitnessPal syncs nutrition data to Apple Health and Google Health Connect.',
      );

      expect(app.id, 'myfitnesspal');
      expect(app.name, 'MyFitnessPal');
      expect(app.supportsHealthKit, isTrue);
      expect(app.supportsHealthConnect, isTrue);
      expect(app.simpleIconSlug, isNull);
      expect(app.deepLinkUrl, isNull);
      expect(app.storeUrl, isNull);
    });

    test('supportsBothPlatforms returns true when both flags set', () {
      const app = CompatibleApp(
        id: 'oura',
        name: 'Oura Ring',
        supportsHealthKit: true,
        supportsHealthConnect: true,
        brandColor: 0xFF514689,
        description: 'Sleep and recovery tracking.',
        dataFlowExplanation: 'Oura syncs to both platforms.',
      );
      expect(app.supportsBothPlatforms, isTrue);
    });

    test('supportsBothPlatforms returns false for iOS-only app', () {
      const app = CompatibleApp(
        id: 'eight_sleep',
        name: 'Eight Sleep',
        supportsHealthKit: true,
        supportsHealthConnect: false,
        brandColor: 0xFF2D2D2D,
        description: 'Smart mattress sleep data.',
        dataFlowExplanation: 'Eight Sleep syncs via HealthKit only.',
      );
      expect(app.supportsBothPlatforms, isFalse);
    });

    test('equality works correctly', () {
      const a = CompatibleApp(
        id: 'noom',
        name: 'Noom',
        supportsHealthKit: true,
        supportsHealthConnect: true,
        brandColor: 0xFFFF6F00,
        description: 'Weight loss program.',
        dataFlowExplanation: 'Noom reads from Health stores.',
      );
      const b = CompatibleApp(
        id: 'noom',
        name: 'Noom',
        supportsHealthKit: true,
        supportsHealthConnect: true,
        brandColor: 0xFFFF6F00,
        description: 'Weight loss program.',
        dataFlowExplanation: 'Noom reads from Health stores.',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
