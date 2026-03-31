/// Coach Tab — Idle State Layout.
///
/// Shown when the conversation is empty. Contains:
///   1. CoachBlob mascot (80px, idle animation) — top-center
///   2. Time-adaptive greeting (based on device clock hour)
///   3. 3 hardcoded suggestion cards
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_suggestion_card.dart';

/// Data for a single suggestion card in the idle state.
class _SuggestionCardData {
  const _SuggestionCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String prompt;
}

// Hardcoded suggestion cards. The server-side PromptSuggestion model only has
// a 'text' field — no icon, title, or subtitle. These are design-first static
// entries. Future work: extend the model to support card-format suggestions.
const _kSuggestions = [
  _SuggestionCardData(
    icon: Icons.bedtime_rounded,
    title: 'How did I sleep last night?',
    subtitle: 'Zura will check your recent sleep data and give you a plain summary.',
    prompt: 'How did I sleep last night?',
  ),
  _SuggestionCardData(
    icon: Icons.directions_run_rounded,
    title: 'How active have I been this week?',
    subtitle: 'Compare your step count and workouts against your usual patterns.',
    prompt: 'How active have I been this week?',
  ),
  _SuggestionCardData(
    icon: Icons.insights_rounded,
    title: "What's one thing I should focus on today?",
    subtitle: 'Get a personalised tip based on your health trends.',
    prompt: "What's one thing I should focus on today?",
  ),
];

/// Returns a time-adaptive greeting based on the current device hour.
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning.';
  if (hour < 17) return 'Good afternoon.';
  return 'Good evening.';
}

/// Idle state body — blob hero, greeting, and 3 suggestion cards.
///
/// [onSuggestionTap] is called with the prompt text when a card is tapped.
/// The parent [CoachScreen] populates the input field and sends immediately.
///
/// [bottomPadding] adds extra space at the bottom of the scroll content so the
/// last suggestion card is never hidden behind the floating input pill.
class CoachIdleState extends StatelessWidget {
  const CoachIdleState({
    super.key,
    required this.onSuggestionTap,
    this.bottomPadding = 0.0,
  });

  final void Function(String prompt) onSuggestionTap;

  /// Extra bottom clearance so cards don't scroll under the floating pill.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppDimens.spaceXl),
          // ── Blob mascot ───────────────────────────────────────────────
          const CoachBlob(state: BlobState.idle, size: 80),
          const SizedBox(height: AppDimens.spaceMd),
          // ── Greeting ──────────────────────────────────────────────────
          Text(
            _greeting(),
            style: AppTextStyles.displayMedium.copyWith(
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXl),
          // ── Suggestion cards ──────────────────────────────────────────
          ...List.generate(_kSuggestions.length, (i) {
            final s = _kSuggestions[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < _kSuggestions.length - 1 ? AppDimens.spaceSm : 0,
              ),
              child: CoachSuggestionCard(
                icon: s.icon,
                title: s.title,
                subtitle: s.subtitle,
                onTap: () => onSuggestionTap(s.prompt),
              ),
            );
          }),
          SizedBox(height: AppDimens.spaceXl + bottomPadding),
        ],
      ),
    );
  }
}
