/// Zuralog — Onboarding Step 6: Discovery.
///
/// Asks the user "Where did you hear about Zuralog?" via a tile selector.
/// The selected value is reported to the parent via [onSourceChanged].
/// The parent ([OnboardingFlowScreen]) fires the PostHog `onboarding_discovery`
/// event on successful completion so it fires at most once.
/// Selection is optional — the user can proceed without answering.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Discovery Sources ─────────────────────────────────────────────────────────

const List<String> _sources = [
  'App Store / Google Play',
  'Friend or family',
  'Social media (Instagram / TikTok)',
  'YouTube',
  'Reddit',
  'Twitter / X',
  'Search engine',
  'Podcast',
  'News article / blog',
  'Other',
];

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 6 — discovery source selection.
///
/// Reports selection changes to the parent via [onSourceChanged].
/// The parent ([OnboardingFlowScreen]) fires the PostHog event on successful
/// submission so the event fires at most once (not on every tap).
class DiscoveryStep extends StatelessWidget {
  const DiscoveryStep({
    super.key,
    required this.selectedSource,
    required this.onSourceChanged,
  });

  final String? selectedSource;
  final ValueChanged<String?> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          // ── Heading ────────────────────────────────────────────────────
          Text(
            'One last thing',
            style: AppTextStyles.h1.copyWith(
              color: colorScheme.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Where did you hear about Zuralog?',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Source tiles ───────────────────────────────────────────────
          ...List.generate(_sources.length, (index) {
            final source = _sources[index];
            final isSelected = source == selectedSource;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _sources.length - 1
                    ? AppDimens.spaceSm
                    : 0,
              ),
              child: _SourceTile(
                label: source,
                isSelected: isSelected,
                onTap: () {
                  final newSource = isSelected ? null : source;
                  onSourceChanged(newSource);
                },
              ),
            );
          }),

          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'This is optional — tap Finish to complete setup.',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Source Tile ───────────────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: isSelected
                      ? colorScheme.onSurface
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: AppDimens.iconMd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
