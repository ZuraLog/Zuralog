import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/today/data/supplement_log_local_repository.dart';
import 'package:zuralog/features/today/data/supplement_log_sync_service.dart';
import 'package:zuralog/features/today/domain/supplement_taken_log.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _ingestResponse(String logId) => Response(
      data: {
        'event_id': logId,
        'daily_total': null,
        'unit': 'count',
        'date': '2026-04-27',
      },
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

void main() {
  late MockApiClient mockApi;
  late SupplementLogLocalRepository localRepo;
  late SupplementLogSyncService service;

  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    mockApi = MockApiClient();
    localRepo = SupplementLogLocalRepository(prefs);
    service = SupplementLogSyncService(
      localRepo: localRepo,
      client: mockApi,
    );
  });

  tearDown(() => service.dispose());

  group('syncLog', () {
    test('posts to ingest and marks log as synced on success', () async {
      final recordedAt = DateTime(2026, 4, 27, 8, 0);
      final log = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-abc',
        logDate: '2026-04-27',
        recordedAt: recordedAt,
      );
      await localRepo.saveLog(log);

      when(() => mockApi.post('/api/v1/ingest', data: any(named: 'data')))
          .thenAnswer((_) async => _ingestResponse('server-log-xyz'));

      await service.syncLog(log);

      final logs = localRepo.getLogsForDate('2026-04-27');
      expect(logs[0].synced, isTrue);
      expect(logs[0].logId, 'server-log-xyz');
    });

    test('silently swallows network errors and leaves log unsynced', () async {
      final log = SupplementTakenLog(
        id: 'local-1',
        supplementId: 'sup-abc',
        logDate: '2026-04-27',
        recordedAt: DateTime(2026, 4, 27, 8, 0),
      );
      await localRepo.saveLog(log);

      when(() => mockApi.post('/api/v1/ingest', data: any(named: 'data')))
          .thenThrow(Exception('network error'));

      await expectLater(service.syncLog(log), completes);

      final logs = localRepo.getLogsForDate('2026-04-27');
      expect(logs[0].synced, isFalse);
    });
  });

  group('syncPending', () {
    test('syncs all unsynced logs from today and yesterday', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      await localRepo.saveLog(SupplementTakenLog(
        id: 'local-today',
        supplementId: 'sup-1',
        logDate: todayStr,
        recordedAt: today,
      ));
      await localRepo.saveLog(SupplementTakenLog(
        id: 'local-yesterday',
        supplementId: 'sup-2',
        logDate: yesterdayStr,
        recordedAt: yesterday,
      ));

      when(() => mockApi.post('/api/v1/ingest', data: any(named: 'data')))
          .thenAnswer((_) async => _ingestResponse('server-log-any'));

      await service.syncPending();

      verify(() => mockApi.post('/api/v1/ingest', data: any(named: 'data')))
          .called(2);
    });

    test('skips already-synced logs', () async {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final log = SupplementTakenLog(
        id: 'local-synced',
        supplementId: 'sup-1',
        logDate: todayStr,
        recordedAt: today,
        synced: true,
        logId: 'server-log-already',
      );
      await localRepo.saveLog(log);

      await service.syncPending();

      verifyNever(() => mockApi.post('/api/v1/ingest', data: any(named: 'data')));
    });
  });
}
