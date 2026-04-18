import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/progress/data/journal_prompts.dart';

void main() {
  group('journalPrompts list', () {
    test('has at least 30 entries', () {
      expect(journalPrompts.length, greaterThanOrEqualTo(30));
    });

    test('all entries are non-empty and under 120 chars', () {
      for (final p in journalPrompts) {
        expect(p.trim(), isNotEmpty, reason: 'prompt must not be empty');
        expect(p.length, lessThanOrEqualTo(120),
            reason: 'prompt must be under 120 chars: "$p"');
      }
    });
  });

  group('journalPromptProvider', () {
    test('returns a prompt from the static list', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final prompt = c.read(journalPromptProvider);
      expect(journalPrompts, contains(prompt));
    });

    test('reload via index provider returns a different prompt', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final first = c.read(journalPromptProvider);
      c.read(journalPromptIndexProvider.notifier).update((v) => v + 1);
      final second = c.read(journalPromptProvider);
      expect(second, isNot(equals(first)));
    });
  });
}
