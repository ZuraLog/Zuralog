// zuralog/test/features/today/data/today_repository_severity_test.dart
//
// Tests that _severityToValue maps each severity level to the correct
// numeric value. Tested indirectly via logSymptom → submitIngest → ApiClient.post.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/today/data/today_repository.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockApiClient extends Mock implements ApiClient {}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Builds a fake 200 Response that satisfies IngestResult.fromJson.
Response<dynamic> _fakeIngestResponse() {
  return Response(
    requestOptions: RequestOptions(path: '/api/v1/ingest'),
    statusCode: 200,
    data: <String, dynamic>{
      'event_id': 'fake-id',
      'unit': 'severity',
      'date': '2026-01-01',
      'daily_total': null,
    },
  );
}

/// Calls [logSymptom] and returns the `value` field captured in the
/// POST body sent to `/api/v1/ingest`.
Future<double> _capturedValue(String severity) async {
  final mockApi = MockApiClient();

  when(
    () => mockApi.post(
      any(),
      data: any(named: 'data'),
      queryParameters: any(named: 'queryParameters'),
    ),
  ).thenAnswer((_) async => _fakeIngestResponse());

  final repo = TodayRepository(apiClient: mockApi);

  await repo.logSymptom(
    bodyAreas: ['head'],
    severity: severity,
  );

  // Capture the data argument passed to ApiClient.post.
  final captured = verify(
    () => mockApi.post(
      any(),
      data: captureAny(named: 'data'),
      queryParameters: any(named: 'queryParameters'),
    ),
  ).captured;

  final body = captured.first as Map<String, dynamic>;
  return (body['value'] as num).toDouble();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TodayRepository._severityToValue', () {
    test('mild maps to 1.0', () async {
      expect(await _capturedValue('mild'), equals(1.0));
    });

    test('moderate maps to 2.0', () async {
      expect(await _capturedValue('moderate'), equals(2.0));
    });

    test('bad maps to 2.5', () async {
      expect(await _capturedValue('bad'), equals(2.5));
    });

    test('severe maps to 3.0', () async {
      expect(await _capturedValue('severe'), equals(3.0));
    });
  });
}
