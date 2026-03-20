import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

void main() {
  group('todayLogSummaryProvider invalidation', () {
    test(
        'invalidating todayLogSummaryProvider triggers a re-fetch',
        () async {
      var fetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          todayLogSummaryProvider.overrideWith((ref) async {
            fetchCount++;
            return TodayLogSummary.empty;
          }),
          userLoggedTypesProvider.overrideWith(
            (ref) async => const <String>{},
          ),
        ],
      );
      addTearDown(container.dispose);

      // First read — triggers one fetch.
      await container.read(todayLogSummaryProvider.future);
      expect(fetchCount, 1);

      // Invalidate — should trigger a re-fetch.
      container.invalidate(todayLogSummaryProvider);
      await container.read(todayLogSummaryProvider.future);
      expect(fetchCount, 2);
    });

    // snapshotProvider rebuild test removed — provider was deleted as dead code.
  });
}
