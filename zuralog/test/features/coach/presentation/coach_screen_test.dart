import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/coach_screen.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_idle_state.dart';

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: CoachScreen()),
    );

void main() {
  testWidgets('shows CoachIdleState when no messages', (tester) async {
    await tester.pumpWidget(_wrap([]));
    await tester.pump();
    expect(find.byType(CoachIdleState), findsOneWidget);
    // Cancel pending async work before the test ends.
    await tester.pump(const Duration(seconds: 30));
  });
}
