library;

import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/workout/data/exercise_repository.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';

Future<void> _stubAsset(String assetKey, String payload) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == assetKey) {
        return ByteData.sublistView(utf8.encode(payload));
      }
      return null;
    },
  );
}

void _clearAssetStub() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}

const _fixture = '['
    '{"id":"bench_press","name":"Bench Press","muscleGroup":"chest","equipment":"barbell","instructions":"Press."},'
    '{"id":"pull_up","name":"Pull-Up","muscleGroup":"back","equipment":"bodyweight","instructions":"Pull."},'
    '{"id":"squat","name":"Back Squat","muscleGroup":"quads","equipment":"barbell","instructions":"Squat."},'
    '{"id":"running","name":"Running","muscleGroup":"cardio","equipment":"other","instructions":"Run."}'
    ']';

void main() {
  setUp(() async {
    await _stubAsset('assets/data/exercises.json', _fixture);
  });

  tearDown(_clearAssetStub);

  group('ExerciseRepository.loadAll', () {
    test('parses every record from the bundled JSON', () async {
      final repo = ExerciseRepository();
      final list = await repo.loadAll();
      expect(list, hasLength(4));
      expect(list.first.id, 'bench_press');
      expect(list.first.muscleGroup, MuscleGroup.chest);
    });

    test('results are cached on the instance — only loads once', () async {
      final repo = ExerciseRepository();
      final a = await repo.loadAll();
      _clearAssetStub();
      final b = await repo.loadAll();
      expect(identical(a, b), isTrue);
    });
  });

  group('ExerciseRepository.filter', () {
    test('unfiltered returns every exercise', () async {
      final repo = ExerciseRepository();
      await repo.loadAll();
      expect(repo.filter(), hasLength(4));
    });

    test('muscleGroup filter returns matching exercises only', () async {
      final repo = ExerciseRepository();
      await repo.loadAll();
      final chest = repo.filter(muscleGroup: MuscleGroup.chest);
      expect(chest, hasLength(1));
      expect(chest.single.id, 'bench_press');
    });

    test('query filter is case-insensitive substring match on name', () async {
      final repo = ExerciseRepository();
      await repo.loadAll();
      expect(repo.filter(query: 'squat'), hasLength(1));
      expect(repo.filter(query: 'SQUAT'), hasLength(1));
      expect(repo.filter(query: 'sq'), hasLength(1));
      expect(repo.filter(query: 'zzz'), isEmpty);
    });

    test('whitespace-only query is ignored', () async {
      final repo = ExerciseRepository();
      await repo.loadAll();
      expect(repo.filter(query: '   '), hasLength(4));
    });

    test('combined muscleGroup + query intersects both filters', () async {
      final repo = ExerciseRepository();
      await repo.loadAll();
      final result = repo.filter(
          muscleGroup: MuscleGroup.back, query: 'pull');
      expect(result, hasLength(1));
      expect(result.single.id, 'pull_up');
    });
  });
}
