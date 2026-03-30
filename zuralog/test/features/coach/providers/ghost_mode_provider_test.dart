// zuralog/test/features/coach/providers/ghost_mode_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';

void main() {
  test('ghostModeProvider starts false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(ghostModeProvider), false);
  });

  test('ghostModeProvider can be set to true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(ghostModeProvider.notifier).state = true;
    expect(container.read(ghostModeProvider), true);
  });
}
