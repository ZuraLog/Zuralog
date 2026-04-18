/// Static prompt list for the Journal Writing Studio.
///
/// Today this is a hand-curated list resolved deterministically per-day.
/// In a future iteration [journalPromptProvider] becomes an
/// [AsyncNotifierProvider] that hits `/api/v1/journal/prompt` for
/// AI-generated prompts — the UI contract (`String`) stays the same.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hand-curated journaling prompts.
///
/// Keep entries under 120 chars so they fit the prompt band on a narrow
/// iPhone screen without wrapping to three lines.
const List<String> journalPrompts = [
  "What's one small win from today — however tiny?",
  'What did you notice about your energy this morning?',
  'Name one thing you are grateful for right now.',
  "What's one thing you want to carry into tomorrow?",
  'How did your body feel today, in three words?',
  'What pulled your attention most today?',
  'What did you let yourself skip today, and was that okay?',
  'Who did you think about today?',
  "What's one thing you wish you had said?",
  'What did you eat today that you enjoyed?',
  'What made you laugh — even a little?',
  'Where did you feel tension in your body today?',
  "What's one thing you're proud of this week?",
  'What would you do differently if today restarted?',
  'What kind of rest does your body actually want?',
  'What did you give yourself permission to do today?',
  "What's a belief you're ready to let go of?",
  'What does "enough" look like for you this week?',
  'What did you avoid today — and why?',
  'What are you looking forward to tomorrow?',
  "What's been on your mind more than you've admitted?",
  'Who made you feel seen this week?',
  "What's one kind thing you can do for yourself tonight?",
  'When did you feel most like yourself today?',
  "What's a question you are sitting with?",
  'What did you learn about your limits this week?',
  "What's one thing that deserves to feel normal again?",
  'How did you move your body today?',
  'What did your inner voice sound like today?',
  'What changed for you this month, even a little?',
  'What do you need less of this week?',
  'What do you need more of this week?',
  "What's one thing that went better than you expected?",
  'What is your body asking for that you keep ignoring?',
  "What's one boundary you want to hold this week?",
  'What did you do today that future-you will thank you for?',
  "What's something beautiful you noticed today?",
  'What felt heavy today, and where did it sit?',
  "What's one hour of today you wish you could have back?",
  "What's one hour of today you'd relive?",
];

/// The index of today's prompt. Defaults to day-of-year so every user sees
/// the same prompt on the same day — deterministic, no randomness.
///
/// Tap the reload icon on the prompt band to `update((v) => v + 1)` which
/// rotates to the next prompt. The index is not persisted across rebuilds
/// beyond the life of the provider container (resets daily naturally when
/// the default recomputes).
final journalPromptIndexProvider = StateProvider<int>((ref) {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  return dayOfYear;
});

/// The current journaling prompt. Reads [journalPromptIndexProvider] and
/// wraps the index modulo the list length.
///
/// Future AI variant: swap this body to an [AsyncNotifierProvider] that
/// awaits `/api/v1/journal/prompt`. UI readers will need a `.when` branch
/// at that point, but the static list can stay as the fallback.
final journalPromptProvider = Provider<String>((ref) {
  final index = ref.watch(journalPromptIndexProvider);
  return journalPrompts[index.abs() % journalPrompts.length];
});
