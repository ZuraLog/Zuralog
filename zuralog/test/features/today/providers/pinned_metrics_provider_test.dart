// zuralog/test/features/today/providers/pinned_metrics_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

void main() {
  group('PinnedMetricsNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns empty list when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final result = await container.read(pinnedMetricsProvider.future);
      expect(result, isEmpty);
    });

    test('addMetric appends to the list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(pinnedMetricsProvider.future); // init
      await container.read(pinnedMetricsProvider.notifier).addMetric('water');
      final result = await container.read(pinnedMetricsProvider.future);
      expect(result, contains('water'));
    });

    test('removeMetric removes from the list', () async {
      SharedPreferences.setMockInitialValues(
        {PinnedMetricsNotifier.kPinnedMetricsKeyForTest: '["water","steps"]'},
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(pinnedMetricsProvider.notifier).removeMetric('water');
      final result = await container.read(pinnedMetricsProvider.future);
      expect(result, isNot(contains('water')));
      expect(result, contains('steps'));
    });

    test('addMetric does not add duplicates', () async {
      SharedPreferences.setMockInitialValues(
        {PinnedMetricsNotifier.kPinnedMetricsKeyForTest: '["water"]'},
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(pinnedMetricsProvider.notifier).addMetric('water');
      final result = await container.read(pinnedMetricsProvider.future);
      expect(result.where((m) => m == 'water').length, 1);
    });
  });
}
