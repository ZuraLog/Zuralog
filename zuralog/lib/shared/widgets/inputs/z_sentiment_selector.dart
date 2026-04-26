/// Zuralog Design System — Sentiment Selector Input Component.
///
/// A row of 5 tappable face icons for wellness check-ins (mood, energy, stress).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A row of 5 tappable sentiment face icons for wellness check-ins.
///
/// Each icon is a 48×48 circle with a Material sentiment icon inside.
/// Tapping fires [onChanged] with the selected level (1–5 left to right).
/// The selected icon gets a color-coded background and border.
///
/// ## Color gradient (left to right, non-reversed)
/// Index 0 (level 1): red   — [AppColors.categoryHeart]
/// Index 1 (level 2): amber — [AppColors.categoryNutrition]
/// Index 2 (level 3): purple — [AppColors.categoryWellness]
/// Index 3 (level 4): green — [AppColors.categoryActivity]
/// Index 4 (level 5): bright green — [AppColors.success]
///
/// ## Usage
/// ```dart
/// ZSentimentSelector(
///   selectedLevel: _moodLevel,
///   onChanged: (level) => setState(() => _moodLevel = level),
/// )
/// ```
///
/// For the Stress row, pass `reversed: true` so the leftmost icon is calm
/// (green) and the rightmost is very stressed (red). The emitted level is
/// still 1–5 left to right regardless of reversal.
class ZSentimentSelector extends StatelessWidget {
  /// Creates a [ZSentimentSelector].
  const ZSentimentSelector({
    super.key,
    required this.selectedLevel,
    required this.onChanged,
    this.reversed = false,
  });

  /// The currently selected level (1–5), or null if nothing is selected.
  final int? selectedLevel;

  /// Called when the user taps an icon. Receives the level (1–5).
  final ValueChanged<int> onChanged;

  /// When true, reverses the color gradient so index 0 is calm/green and
  /// index 4 is stressed/red. Used for the Stress row.
  ///
  /// The emitted level numbers are still 1–5 left to right.
  final bool reversed;

  static const List<IconData> _icons = [
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_very_satisfied_rounded,
  ];

  static const List<String> _semanticLabels = [
    'Very dissatisfied',
    'Dissatisfied',
    'Neutral',
    'Satisfied',
    'Very satisfied',
  ];

  static const List<Color> _colors = [
    AppColors.categoryHeart,       // index 0 — red
    AppColors.categoryNutrition,   // index 1 — amber
    AppColors.categoryWellness,    // index 2 — purple
    AppColors.categoryActivity,    // index 3 — green
    AppColors.success,             // index 4 — bright green
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Semantics(
      label: 'Sentiment selector: ${selectedLevel != null ? 'level $selectedLevel selected' : 'nothing selected'}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
          final level = index + 1; // 1-based level emitted to onChanged
          final iconIndex = reversed ? (4 - index) : index;
          final color = _colors[iconIndex];
          final isSelected = selectedLevel == level;

          return Semantics(
            label: _semanticLabels[iconIndex],
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(level);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                width: AppDimens.touchTargetMin,
                height: AppDimens.touchTargetMin,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : colors.surface,
                  border: Border.all(
                    color: isSelected ? color : colors.border,
                    width: isSelected ? 2.0 : 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _icons[iconIndex],
                    size: AppDimens.iconMd,
                    color: isSelected ? color : colors.textTertiary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
