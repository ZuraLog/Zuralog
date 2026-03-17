import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('mealLogModeProvider', () {
    test('default value is false (full mode)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = await container.read(mealLogModeProvider.future);
      expect(mode, isFalse);
    });

    test('setMode(true) updates state to true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(mealLogModeProvider.future);
      await container.read(mealLogModeProvider.notifier).setMode(true);

      final mode = await container.read(mealLogModeProvider.future);
      expect(mode, isTrue);
    });

    test('setMode(false) updates state to false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(mealLogModeProvider.future);
      await container.read(mealLogModeProvider.notifier).setMode(true);
      await container.read(mealLogModeProvider.notifier).setMode(false);

      final mode = await container.read(mealLogModeProvider.future);
      expect(mode, isFalse);
    });

    test('value persists across provider rebuilds (SharedPreferences round-trip)', () async {
      // First container: set to true.
      final container1 = ProviderContainer();
      await container1.read(mealLogModeProvider.future);
      await container1.read(mealLogModeProvider.notifier).setMode(true);
      container1.dispose();

      // Second container: should read true from SharedPreferences.
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      final mode = await container2.read(mealLogModeProvider.future);
      expect(mode, isTrue);
    });
  });
}
