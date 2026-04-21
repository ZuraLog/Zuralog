/// Zuralog — Workout Resume Service Tests.
///
/// Exercises the cold-start resume heuristics of [WorkoutResumeService]
/// against the in-memory SharedPreferences mock. Covers:
///   - no draft  → null
///   - fresh draft → ResumableWorkout with parsed metadata
///   - draft older than 6h → null and cleared
///   - malformed draft → null and cleared
///   - discard → key removed
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/workout/data/workout_resume_service.dart';

const _kDraftKey = 'workout_active_draft';

Map<String, dynamic> _sampleDraft({
  required DateTime startedAt,
  int exercises = 0,
}) {
  return <String, dynamic>{
    'id': 'test-session-id',
    'startedAt': startedAt.toUtc().toIso8601String(),
    'exercises': List<Map<String, dynamic>>.generate(
      exercises,
      (i) => <String, dynamic>{
        'exerciseId': 'ex-$i',
        'exerciseName': 'Exercise $i',
        'muscleGroup': 'chest',
        'sets': const <Map<String, dynamic>>[],
      },
    ),
  };
}

void main() {
  group('WorkoutResumeService', () {
    late SharedPreferences prefs;
    late WorkoutResumeService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      service = WorkoutResumeService(prefs);
    });

    test('returns null when no draft is stored', () {
      expect(service.checkResumable(), isNull);
    });

    test('returns ResumableWorkout when draft exists and is fresh', () async {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 14));
      await prefs.setString(
        _kDraftKey,
        jsonEncode(_sampleDraft(startedAt: startedAt, exercises: 3)),
      );

      final result = service.checkResumable();

      expect(result, isNotNull);
      expect(result!.exerciseCount, 3);
      // Tolerate sub-second skew from ISO round-trip.
      expect(
        result.startedAt.difference(startedAt).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(result.age.inMinutes, greaterThanOrEqualTo(13));
      expect(result.age.inMinutes, lessThanOrEqualTo(15));
      // Draft must remain so the session screen can rehydrate from it.
      expect(prefs.getString(_kDraftKey), isNotNull);
    });

    test('returns null and clears when draft is older than 6 hours', () async {
      final startedAt = DateTime.now().subtract(const Duration(hours: 7));
      await prefs.setString(
        _kDraftKey,
        jsonEncode(_sampleDraft(startedAt: startedAt, exercises: 2)),
      );

      final result = service.checkResumable();

      expect(result, isNull);
      // Allow the fire-and-forget remove to settle.
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(_kDraftKey), isNull);
    });

    test('returns null and clears when draft JSON is malformed', () async {
      await prefs.setString(_kDraftKey, 'not-json-at-all');

      final result = service.checkResumable();

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(_kDraftKey), isNull);
    });

    test('returns null and clears when startedAt is missing', () async {
      await prefs.setString(
        _kDraftKey,
        jsonEncode(<String, dynamic>{
          'id': 'test-session-id',
          'exercises': const <Map<String, dynamic>>[],
        }),
      );

      final result = service.checkResumable();

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(_kDraftKey), isNull);
    });

    test('returns null and clears when startedAt is unparseable', () async {
      await prefs.setString(
        _kDraftKey,
        jsonEncode(<String, dynamic>{
          'id': 'test-session-id',
          'startedAt': 'definitely-not-a-date',
          'exercises': const <Map<String, dynamic>>[],
        }),
      );

      final result = service.checkResumable();

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(_kDraftKey), isNull);
    });

    test('exerciseCount defaults to 0 when exercises is missing', () async {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 1));
      await prefs.setString(
        _kDraftKey,
        jsonEncode(<String, dynamic>{
          'id': 'test-session-id',
          'startedAt': startedAt.toUtc().toIso8601String(),
        }),
      );

      final result = service.checkResumable();

      expect(result, isNotNull);
      expect(result!.exerciseCount, 0);
    });

    test('discard removes the draft key', () async {
      await prefs.setString(
        _kDraftKey,
        jsonEncode(_sampleDraft(startedAt: DateTime.now())),
      );
      expect(prefs.getString(_kDraftKey), isNotNull);

      await service.discard();

      expect(prefs.getString(_kDraftKey), isNull);
    });
  });
}
