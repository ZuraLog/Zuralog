import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/today/data/supplement_log_local_repository.dart';
import 'package:zuralog/features/today/domain/supplement_taken_log.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
        ],
      );

  group('supplementsSyncStatusProvider', () {
    test('returns none when no logs exist for today', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final status =
          await container.read(supplementsSyncStatusProvider.future);
      expect(status, SupplementSyncStatus.none);
    });

    test('returns synced when all logs are synced', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final repo = container.read(supplementLogLocalRepositoryProvider);
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await repo.saveLog(SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-1',
        logDate: todayStr,
        recordedAt: today,
        synced: true,
        logId: 'server-log-abc',
      ));

      final status =
          await container.read(supplementsSyncStatusProvider.future);
      expect(status, SupplementSyncStatus.synced);
    });

    test('returns pending when any log is unsynced', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final repo = container.read(supplementLogLocalRepositoryProvider);
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await repo.saveLog(SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-1',
        logDate: todayStr,
        recordedAt: today,
        synced: false,
      ));

      final status =
          await container.read(supplementsSyncStatusProvider.future);
      expect(status, SupplementSyncStatus.pending);
    });
  });
}
