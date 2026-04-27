// zuralog/test/features/today/data/today_repository_supplements_test.dart
//
// Tests for:
//   - getSupplementsList (uses SupplementEntry.fromJson, maps new structured fields)
//   - updateSupplementsList (uses s.toJson()..remove('id'), sends new fields)
//   - getSupplementsTodayLog (new method — fetches today-log entries)
//   - deleteSupplementLogEntry (new method — DELETE by log entry id)

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/supplement_today_entry.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockApiClient extends Mock implements ApiClient {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Response<dynamic> _response(Map<String, dynamic> data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

Response<dynamic> _emptyResponse() => Response(
      data: null,
      statusCode: 204,
      requestOptions: RequestOptions(path: ''),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockApiClient mockApi;
  late TodayRepository repo;

  setUp(() {
    mockApi = MockApiClient();
    repo = TodayRepository(apiClient: mockApi);
  });

  // ── getSupplementsList ──────────────────────────────────────────────────────

  group('getSupplementsList', () {
    test('maps all fields including new structured fields', () async {
      when(() => mockApi.get('/api/v1/supplements')).thenAnswer((_) async =>
          _response({
            'supplements': [
              {
                'id': 'sup-1',
                'name': 'Vitamin D',
                'dose': '5000 IU',
                'timing': 'morning',
                'dose_amount': 5000.0,
                'dose_unit': 'IU',
                'form': 'softgel',
              }
            ]
          }));

      final list = await repo.getSupplementsList();
      expect(list.length, 1);
      expect(list[0].id, 'sup-1');
      expect(list[0].name, 'Vitamin D');
      expect(list[0].doseAmount, 5000.0);
      expect(list[0].doseUnit, 'IU');
      expect(list[0].form, 'softgel');
    });

    test('returns empty list when supplements key is absent', () async {
      when(() => mockApi.get('/api/v1/supplements'))
          .thenAnswer((_) async => _response({}));

      final list = await repo.getSupplementsList();
      expect(list, isEmpty);
    });
  });

  // ── updateSupplementsList ───────────────────────────────────────────────────

  group('updateSupplementsList', () {
    test('sends new structured fields in payload and excludes id', () async {
      const entry = SupplementEntry(
        id: 'sup-1',
        name: 'Vitamin D',
        doseAmount: 5000.0,
        doseUnit: 'IU',
        form: 'softgel',
        timing: 'morning',
      );

      when(() => mockApi.post(
            '/api/v1/supplements',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _response({
            'supplements': [
              {
                'id': 'sup-1',
                'name': 'Vitamin D',
                'dose_amount': 5000.0,
                'dose_unit': 'IU',
                'form': 'softgel',
                'timing': 'morning',
              }
            ]
          }));

      final result = await repo.updateSupplementsList([entry]);
      expect(result.length, 1);
      expect(result[0].doseAmount, 5000.0);

      final captured = verify(() => mockApi.post(
            '/api/v1/supplements',
            data: captureAny(named: 'data'),
          )).captured;

      final payload = captured.first as Map<String, dynamic>;
      final items = payload['supplements'] as List<dynamic>;
      expect(items[0].containsKey('id'), isFalse,
          reason: 'id must be stripped from the POST payload');
      expect(items[0]['dose_amount'], 5000.0);
      expect(items[0]['dose_unit'], 'IU');
      expect(items[0]['form'], 'softgel');
    });
  });

  // ── getSupplementsTodayLog ──────────────────────────────────────────────────

  group('getSupplementsTodayLog', () {
    test('parses entries from today-log endpoint', () async {
      when(() => mockApi.get('/api/v1/supplements/today-log'))
          .thenAnswer((_) async => _response({
                'entries': [
                  {'supplement_id': 'sup-1', 'log_id': 'log-a'},
                ]
              }));

      final entries = await repo.getSupplementsTodayLog();
      expect(entries.length, 1);
      expect(entries[0].supplementId, 'sup-1');
      expect(entries[0].logId, 'log-a');
    });

    test('returns empty list on empty response', () async {
      when(() => mockApi.get('/api/v1/supplements/today-log'))
          .thenAnswer((_) async => _response({'entries': []}));

      final entries = await repo.getSupplementsTodayLog();
      expect(entries, isEmpty);
    });

    test('returns empty list when entries key is absent', () async {
      when(() => mockApi.get('/api/v1/supplements/today-log'))
          .thenAnswer((_) async => _response({}));

      final entries = await repo.getSupplementsTodayLog();
      expect(entries, isEmpty);
    });
  });

  // ── deleteSupplementLogEntry ────────────────────────────────────────────────

  group('deleteSupplementLogEntry', () {
    test('calls DELETE with correct log entry id', () async {
      when(() => mockApi.delete('/api/v1/supplements/log/log-abc'))
          .thenAnswer((_) async => _emptyResponse());

      await repo.deleteSupplementLogEntry('log-abc');
      verify(() => mockApi.delete('/api/v1/supplements/log/log-abc')).called(1);
    });

    test('builds the path correctly for a different id', () async {
      when(() => mockApi.delete('/api/v1/supplements/log/xyz-999'))
          .thenAnswer((_) async => _emptyResponse());

      await repo.deleteSupplementLogEntry('xyz-999');
      verify(() => mockApi.delete('/api/v1/supplements/log/xyz-999')).called(1);
    });
  });
}
