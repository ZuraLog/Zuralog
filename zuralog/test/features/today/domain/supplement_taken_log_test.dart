import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/supplement_taken_log.dart';

void main() {
  group('SupplementTakenLog', () {
    final recordedAt = DateTime(2026, 4, 27, 8, 0);

    test('round-trips through toJson / fromJson', () {
      final log = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-abc',
        logDate: '2026-04-27',
        recordedAt: recordedAt,
        logId: 'server-log-xyz',
        synced: true,
      );

      final restored = SupplementTakenLog.fromJson(log.toJson());
      expect(restored.id, log.id);
      expect(restored.supplementId, log.supplementId);
      expect(restored.logDate, log.logDate);
      expect(restored.recordedAt, log.recordedAt);
      expect(restored.logId, log.logId);
      expect(restored.synced, log.synced);
    });

    test('defaults synced to false and logId to null', () {
      final log = SupplementTakenLog(
        id: 'local-2',
        supplementId: 'sup-def',
        logDate: '2026-04-27',
        recordedAt: recordedAt,
      );
      expect(log.synced, isFalse);
      expect(log.logId, isNull);
    });

    test('toJson omits null logId', () {
      final log = SupplementTakenLog(
        id: 'local-3',
        supplementId: 'sup-ghi',
        logDate: '2026-04-27',
        recordedAt: recordedAt,
      );
      expect(log.toJson().containsKey('logId'), isFalse);
    });

    test('copyWith updates synced and logId', () {
      final log = SupplementTakenLog(
        id: 'local-4',
        supplementId: 'sup-jkl',
        logDate: '2026-04-27',
        recordedAt: recordedAt,
      );
      final synced = log.copyWith(synced: true, logId: () => 'server-log-999');
      expect(synced.synced, isTrue);
      expect(synced.logId, 'server-log-999');
      expect(synced.supplementId, log.supplementId);
    });
  });
}
