// test/features/integrations/domain/compatible_apps_registry_test.dart

// Tests for [CompatibleAppsRegistry].
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/integrations/domain/compatible_apps_registry.dart';

void main() {
  group('CompatibleAppsRegistry', () {
    test('contains at least 40 apps', () {
      expect(CompatibleAppsRegistry.apps.length, greaterThanOrEqualTo(40));
    });

    test('all IDs are unique', () {
      final ids = CompatibleAppsRegistry.apps.map((a) => a.id).toSet();
      expect(ids.length, equals(CompatibleAppsRegistry.apps.length));
    });

    test('all apps have non-empty name and description', () {
      for (final app in CompatibleAppsRegistry.apps) {
        expect(app.name.isNotEmpty, isTrue, reason: '${app.id} has empty name');
        expect(app.description.isNotEmpty, isTrue,
            reason: '${app.id} has empty description');
        expect(app.dataFlowExplanation.isNotEmpty, isTrue,
            reason: '${app.id} has empty dataFlowExplanation');
      }
    });

    test('all apps support at least one platform', () {
      for (final app in CompatibleAppsRegistry.apps) {
        expect(
          app.supportsHealthKit || app.supportsHealthConnect,
          isTrue,
          reason: '${app.id} supports neither platform',
        );
      }
    });

    test('healthKitApps returns only HealthKit-supporting apps', () {
      final hkApps = CompatibleAppsRegistry.healthKitApps;
      for (final app in hkApps) {
        expect(app.supportsHealthKit, isTrue);
      }
      expect(hkApps.length, greaterThan(30));
    });

    test('healthConnectApps returns only Health Connect-supporting apps', () {
      final hcApps = CompatibleAppsRegistry.healthConnectApps;
      for (final app in hcApps) {
        expect(app.supportsHealthConnect, isTrue);
      }
      expect(hcApps.length, greaterThan(25));
    });

    test('searchApps filters by name case-insensitively', () {
      final results = CompatibleAppsRegistry.searchApps('nike');
      expect(results.any((a) => a.id == 'nike_run_club'), isTrue);
    });

    test('searchApps returns all apps for empty query', () {
      final results = CompatibleAppsRegistry.searchApps('');
      expect(results.length, equals(CompatibleAppsRegistry.apps.length));
    });
  });
}
