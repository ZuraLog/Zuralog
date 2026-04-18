import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/progress/data/journal_prompts.dart';
import 'package:zuralog/features/progress/presentation/journal_diary_screen.dart';

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: JournalDiaryScreen()),
    );

void main() {
  testWidgets('prompt band renders the current prompt', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pump();

    final expected = c.read(journalPromptProvider);
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('reload button rotates to a different prompt', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pump();

    final first = c.read(journalPromptProvider);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    final second = c.read(journalPromptProvider);
    expect(second, isNot(equals(first)));
  });

  testWidgets('word count updates as user types', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pump();

    expect(find.text('0 words'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello there friend');
    await tester.pump();

    expect(find.text('3 words'), findsOneWidget);
  });
}
