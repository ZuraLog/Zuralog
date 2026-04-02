/// Zuralog — Onboarding Step 5: Fitness Level.
///
/// Single-select step for self-assessed fitness level. Used to calibrate AI
/// coach language and recommendation intensity.
///
/// Backend field: `fitness_level` in `PATCH /api/v1/preferences`.
/// NOTE: This is a new field added in Phase 2. The backend ignores unknown
/// fields in the PATCH body, so this is safe to send even before the backend
/// field is added.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Fitness Level Model ────────────────────────────────────────────────────────

class _FitnessLevel {
  const _FitnessLevel({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
}

const List<_FitnessLevel> _levels = [
  _FitnessLevel(
    id: 'beginner',
    icon: Icons.directions_walk_rounded,
    title: 'Beginner',
    subtitle: 'Just getting started',
  ),
  _FitnessLevel(
    id: 'active',
    icon: Icons.directions_run_rounded,
    title: 'Active',
    subtitle: 'Regular exercise routine',
  ),
  _FitnessLevel(
    id: 'athletic',
    icon: Icons.fitness_center_rounded,
    title: 'Athletic',
    subtitle: 'Serious training & performance goals',
  ),
];

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 5 — single-select fitness level picker.
///
/// 3 full-width selection tiles. Selecting one deselects the others.
/// Supports spring animation on selection via [TweenAnimationBuilder].
class FitnessLevelStep extends StatelessWidget {
  /// Creates a [FitnessLevelStep].
  const FitnessLevelStep({
    super.key,
    required this.selectedLevel,
    required this.onLevelChanged,
  });

  /// Currently selected fitness level ID, or `null` if none selected.
  final String? selectedLevel;

  /// Called when the user taps a tile.
  final ValueChanged<String> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ───────────────────────────────────────────────────
          ZPatternText(
            text: 'How active\nare you?',
            style: AppTextStyles.displayLarge.copyWith(
              height: 1.1,
            ),
            variant: ZPatternVariant.sage,
            animate: true,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Helps your AI coach calibrate recommendations.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Fitness level tiles ────────────────────────────────────────
          ...List.generate(_levels.length, (index) {
            final level = _levels[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _levels.length - 1 ? AppDimens.spaceSm : 0,
              ),
              child: _FitnessLevelTile(
                level: level,
                isSelected: level.id == selectedLevel,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onLevelChanged(level.id);
                },
              ),
            );
          }),

          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Fitness Level Tile ────────────────────────────────────────────────────────

/// Full-width selection tile for a fitness level option.
///
/// Selected state: [AppColors.primary] at 8% tint + 1.5px border.
/// Press scale is handled by [ZSelectableTile] via [ZuralogSpringButton].
class _FitnessLevelTile extends StatelessWidget {
  const _FitnessLevelTile({
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  final _FitnessLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZSelectableTile(
      isSelected: isSelected,
      onTap: onTap,
      showCheckIndicator: true,
      scaleTarget: 0.97,
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            ),
            child: Icon(
              level.icon,
              size: 22,
              color: isSelected
                  ? colors.primary
                  : colors.textSecondary,
            ),
          ),

          const SizedBox(width: AppDimens.spaceMd),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isSelected
                        ? colors.primary
                        : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  level.subtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
