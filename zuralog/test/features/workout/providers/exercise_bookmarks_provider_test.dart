import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/workout/providers/exercise_bookmarks_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExerciseBookmarksNotifier', () {
    test('starts empty when no stored data', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = ExerciseBookmarksNotifier(prefs);
      expect(notifier.state, isEmpty);
    });

    test('toggle adds a bookmark', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = ExerciseBookmarksNotifier(prefs);
      notifier.toggle('bench_press');
      expect(notifier.state, contains('bench_press'));
    });

    test('toggle removes an existing bookmark', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = ExerciseBookmarksNotifier(prefs);
      notifier.toggle('squat');
      notifier.toggle('squat');
      expect(notifier.state, isNot(contains('squat')));
    });

    test('persists across notifier instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier1 = ExerciseBookmarksNotifier(prefs);
      notifier1.toggle('deadlift');

      // Simulate reload — same prefs instance holds the JSON written by notifier1.
      final notifier2 = ExerciseBookmarksNotifier(prefs);
      expect(notifier2.state, contains('deadlift'));
    });

    test('loads empty when stored data is empty string', () async {
      SharedPreferences.setMockInitialValues(
          {'workout_bookmarked_exercises': ''});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ExerciseBookmarksNotifier(prefs);
      expect(notifier.state, isEmpty);
    });
  });
}
