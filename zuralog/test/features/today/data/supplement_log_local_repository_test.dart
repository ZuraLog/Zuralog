import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/today/data/supplement_log_local_repository.dart';
import 'package:zuralog/features/today/domain/supplement_taken_log.dart';

void main() {
  late SupplementLogLocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = SupplementLogLocalRepository(prefs);
  });

  group('SupplementLogLocalRepository', () {
    test('returns empty list for date with no entries', () {
      expect(repo.getLogsForDate('2026-04-27'), isEmpty);
    });

    test('saves and retrieves a log entry', () async {
      final log = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-abc',
        logDate: '2026-04-27',
        recordedAt: DateTime(2026, 4, 27, 8, 0),
      );

      await repo.saveLog(log);
      final logs = repo.getLogsForDate('2026-04-27');
      expect(logs.length, 1);
      expect(logs[0].supplementId, 'sup-abc');
      expect(logs[0].synced, isFalse);
    });

    test('saves multiple logs for the same date', () async {
      final log1 = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-a',
        logDate: '2026-04-27',
        recordedAt: DateTime(2026, 4, 27, 8, 0),
      );
      final log2 = SupplementTakenLog(
        id: 'local-2',
        supplementId: 'sup-b',
        logDate: '2026-04-27',
        recordedAt: DateTime(2026, 4, 27, 9, 0),
      );

      await repo.saveLog(log1);
      await repo.saveLog(log2);
      final logs = repo.getLogsForDate('2026-04-27');
      expect(logs.length, 2);
    });

    test('markSynced updates only the matching entry', () async {
      final log = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-abc',
        logDate: '2026-04-27',
        recordedAt: DateTime(2026, 4, 27, 8, 0),
      );
      await repo.saveLog(log);
      await repo.markSynced('local-1', '2026-04-27',
          serverLogId: 'server-log-xyz');

      final logs = repo.getLogsForDate('2026-04-27');
      expect(logs[0].synced, isTrue);
      expect(logs[0].logId, 'server-log-xyz');
    });

    test('markSynced is no-op for unknown id', () async {
      final log = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-abc',
        logDate: '2026-04-27',
        recordedAt: DateTime(2026, 4, 27, 8, 0),
      );
      await repo.saveLog(log);
      await repo.markSynced('does-not-exist', '2026-04-27',
          serverLogId: 'irrelevant');

      final logs = repo.getLogsForDate('2026-04-27');
      expect(logs[0].synced, isFalse);
    });

    test('removeLog removes entry by local id', () async {
      final log = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-abc',
        logDate: '2026-04-27',
        recordedAt: DateTime(2026, 4, 27, 8, 0),
      );
      await repo.saveLog(log);
      await repo.removeLog('local-1', '2026-04-27');

      expect(repo.getLogsForDate('2026-04-27'), isEmpty);
    });
  });
}
