/// Zuralog Design System — Suggested Rule Banner.
///
/// A small inline banner shown at the top of Meal Review (after the
/// walkthrough ends) when the backend detects a recurring follow-up
/// answer pattern — e.g. *"I always use oil when cooking eggs"*.
/// The banner offers the user two choices:
///
///   - **Save rule** — persist the rule via the Phase 3D rules system
///     and stop asking the underlying follow-up question forever.
///   - **Not now** — snooze the suggestion for the next 10 matching
///     occurrences.
///
/// Visual treatment mirrors [ZRefineTransitionCard]: a [ZuralogCard]
/// with [ZCardVariant.feature] tinted with [AppColors.categoryNutrition]
/// (amber). A small [Icons.lightbulb_outline] leads the row, followed
/// by a "Suggested rule" eyebrow label and the rule text.
///
/// The two action buttons are laid out side-by-side using
/// [ZButton] with `isFullWidth: false` wrapped in [Expanded] so each
/// takes half of the available row width. The primary "Save rule"
/// button accepts an [isSaving] flag that shows its built-in spinner
/// and disables the button; the tertiary "Not now" button stays
/// enabled throughout so the user can back out during a slow save.
///
/// ZButton's variant set is `primary / secondary / destructive / text`
/// — there is no `tertiary` variant. The closest low-emphasis option
/// is [ZButtonVariant.text], which renders a transparent background
/// with primary-colored label text. That is what "Not now" uses.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

/// An inline banner prompting the user to save a detected recurring
/// answer as a permanent rule.
///
/// Example:
/// ```dart
/// ZSuggestedRuleBanner(
///   ruleText: 'I always use oil when cooking eggs',
///   onAccept: _handleAcceptSuggestedRule,
///   onDismiss: _handleDismissSuggestedRule,
///   isSaving: _savingSuggestedRule,
/// )
/// ```
class ZSuggestedRuleBanner extends StatelessWidget {
  /// Creates a [ZSuggestedRuleBanner].
  const ZSuggestedRuleBanner({
    super.key,
    required this.ruleText,
    required this.onAccept,
    required this.onDismiss,
    this.isSaving = false,
  });

  /// The plain-language rule text composed by the backend
  /// (e.g. *"I always use oil when cooking eggs"*). Wraps across
  /// multiple lines when needed.
  final String ruleText;

  /// Called when the user taps **Save rule**. The caller is
  /// responsible for toggling [isSaving] to show the spinner and for
  /// dismissing the banner on success.
  final VoidCallback onAccept;

  /// Called when the user taps **Not now**. The caller typically hides
  /// the banner optimistically and fires the dismiss request in the
  /// background.
  final VoidCallback onDismiss;

  /// When true, the primary button shows its built-in spinner and is
  /// disabled. The secondary "Not now" button remains tappable so the
  /// user can back out during a slow network save.
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const accent = AppColors.categoryNutrition;

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Eyebrow row: bulb icon + "Suggested rule" label ────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: AppDimens.iconSm,
                color: accent,
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                'Suggested rule',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          // ── Rule text (wraps) ──────────────────────────────────────
          Text(
            ruleText,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          // ── Actions: Save rule (primary) + Not now (text) ──────────
          Row(
            children: [
              Expanded(
                child: ZButton(
                  label: 'Save rule',
                  onPressed: isSaving ? null : onAccept,
                  isLoading: isSaving,
                  size: ZButtonSize.medium,
                  isFullWidth: false,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: ZButton(
                  label: 'Not now',
                  onPressed: onDismiss,
                  variant: ZButtonVariant.text,
                  size: ZButtonSize.medium,
                  isFullWidth: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
