/// Zuralog — Onboarding Step 6: Discovery.
///
/// Asks the user "Where did you hear about Zuralog?" via a custom Radio-style
/// ZuralogCard tile selector. Selected value is reported via [onSourceChanged].
/// The parent ([OnboardingFlowScreen]) fires the PostHog `onboarding_discovery`
/// event on successful completion so it fires at most once.
/// Selection is optional — the user can proceed without answering.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

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
            style: AppTextStyles.body.copyWith(color: colors.textSecondary),
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
                .copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Source Tile ───────────────────────────────────────────────────────────────

/// A custom Radio-style ZuralogCard row for the discovery source selection.
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
    final colors = AppColorsOf(context);

    return ZSelectableTile(
      isSelected: isSelected,
      onTap: onTap,
      showCheckIndicator: false,
      scaleTarget: 0.98,
      child: Row(
        children: [
          // Custom radio indicator.
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : colors.border,
                width: isSelected ? 0 : 1.5,
              ),
              color: isSelected ? AppColors.primary : Colors.transparent,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.primaryButtonText,
                    size: 14,
                  )
                : null,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: isSelected
                    ? colorScheme.onSurface
                    : colors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
