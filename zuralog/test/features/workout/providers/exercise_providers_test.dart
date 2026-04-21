library;

import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/providers/exercise_providers.dart';

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

const _fixture = '['
    '{"id":"bench_press","name":"Bench Press","muscleGroup":"chest","equipment":"barbell","instructions":""},'
    '{"id":"pull_up","name":"Pull-Up","muscleGroup":"back","equipment":"bodyweight","instructions":""},'
    '{"id":"squat","name":"Back Squat","muscleGroup":"quads","equipment":"barbell","instructions":""}'
    ']';

void main() {
  setUp(() async {
    await _stubAsset('assets/data/exercises.json', _fixture);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('exerciseListProvider returns the full bundled list', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final list = await container.read(exerciseListProvider.future);
    expect(list, hasLength(3));
  });

  test('exerciseSearchProvider returns full list when query empty and no filter', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(exerciseListProvider.future);
    final results = await container.read(exerciseSearchProvider.future);
    expect(results, hasLength(3));
  });

  test('exerciseSearchProvider filters by query', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(exerciseListProvider.future);
    container.read(exerciseSearchQueryProvider.notifier).state = 'press';
    final results = await container.read(exerciseSearchProvider.future);
    expect(results, hasLength(1));
    expect(results.single.id, 'bench_press');
  });

  test('exerciseSearchProvider filters by muscle group', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(exerciseListProvider.future);
    container.read(exerciseMuscleGroupFilterProvider.notifier).state =
        MuscleGroup.back;
    final results = await container.read(exerciseSearchProvider.future);
    expect(results, hasLength(1));
    expect(results.single.id, 'pull_up');
  });

  test('null muscle group filter clears the filter', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(exerciseListProvider.future);
    container.read(exerciseMuscleGroupFilterProvider.notifier).state =
        MuscleGroup.back;
    container.read(exerciseMuscleGroupFilterProvider.notifier).state = null;
    final results = await container.read(exerciseSearchProvider.future);
    expect(results, hasLength(3));
  });
}
