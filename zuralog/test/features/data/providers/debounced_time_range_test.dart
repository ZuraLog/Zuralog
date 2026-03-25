/// Tests that [debouncedTimeRangeProvider] debounces rapid changes to
/// [dashboardTimeRangeProvider], preventing request cascades when the user
/// taps multiple time-range chips quickly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/data/domain/time_range.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';

void main() {
  group('debouncedTimeRangeProvider', () {
    test(
        'resolves to the last value set after 300ms debounce window',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Rapidly set three different values in sequence.
      container.read(dashboardTimeRangeProvider.notifier).state =
          TimeRange.sevenDays;
      container.read(dashboardTimeRangeProvider.notifier).state =
          TimeRange.thirtyDays;
      container.read(dashboardTimeRangeProvider.notifier).state =
          TimeRange.ninetyDays;

      // Wait past the 300ms debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final result =
          await container.read(debouncedTimeRangeProvider.future);

      // The debounced provider must resolve to the last value set.
      expect(result, TimeRange.ninetyDays);
    });

    test(
        'resolves to sevenDays (initial default) when no rapid changes occur',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // No changes — the default is sevenDays.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final result =
          await container.read(debouncedTimeRangeProvider.future);

      expect(result, TimeRange.sevenDays);
    });
  });
}
