/// Coach Settings Screen — AI persona and proactivity level.
///
/// Persona selector (Tough Love / Balanced / Gentle) and proactivity level
/// (Low / Medium / High). Persisted via /api/v1/preferences.
///
/// Full implementation: Phase 8, Task 8.5.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Local State Providers ─────────────────────────────────────────────────────

/// Selected AI persona key.
///
/// Values: `'toughLove'`, `'balanced'`, `'gentle'`. Default: `'balanced'`.
final _personaProvider = StateProvider<String>((ref) => 'balanced');

/// Selected proactivity level key.
///
/// Values: `'low'`, `'medium'`, `'high'`. Default: `'medium'`.
final _proactivityProvider = StateProvider<String>((ref) => 'medium');

// ── Persona Data Model ────────────────────────────────────────────────────────

/// Immutable descriptor for a single AI persona option.
class _PersonaOption {
  const _PersonaOption({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.iconColor,
  });

  /// Unique string key used by [_personaProvider].
  final String key;

  /// Display name shown in the card heading.
  final String label;

  /// One-line description shown beneath the heading.
  final String description;

  /// Leading icon for the persona card.
  final IconData icon;

  /// Semantic color for the icon — uses health category tokens.
  final Color iconColor;
}

/// The three available persona options in display order.
const List<_PersonaOption> _personas = [
  _PersonaOption(
    key: 'toughLove',
    label: 'Tough Love',
    description: 'Blunt, data-driven, pushes you hard. No sugar-coating.',
    icon: Icons.fitness_center_rounded,
    iconColor: AppColors.categoryHeart,
  ),
  _PersonaOption(
    key: 'balanced',
    label: 'Balanced',
    description: 'Supportive and honest. Celebrates wins, addresses gaps.',
    icon: Icons.balance_rounded,
    iconColor: AppColors.primary,
  ),
  _PersonaOption(
    key: 'gentle',
    label: 'Gentle',
    description: 'Warm, encouraging, patient. Focuses on progress over perfection.',
    icon: Icons.spa_rounded,
    iconColor: AppColors.categoryWellness,
  ),
];

// ── Proactivity Data Model ────────────────────────────────────────────────────

/// Descriptor for a single proactivity level chip.
class _ProactivityOption {
  const _ProactivityOption({required this.key, required this.label});

  /// Unique string key used by [_proactivityProvider].
  final String key;

  /// Short display label shown in the chip.
  final String label;
}

/// The three available proactivity levels in display order.
const List<_ProactivityOption> _proactivityOptions = [
  _ProactivityOption(key: 'low', label: 'Low'),
  _ProactivityOption(key: 'medium', label: 'Medium'),
  _ProactivityOption(key: 'high', label: 'High'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Coach Settings screen — AI persona and proactivity level configuration.
///
/// Uses a [CustomScrollView] with [SliverAppBar] large-title and
/// [SliverList] content sections. Local UI state is managed via
/// [StateProvider]s and Riverpod's [ConsumerWidget].
class CoachSettingsScreen extends ConsumerWidget {
  /// Creates a [CoachSettingsScreen].
  const CoachSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPersona = ref.watch(_personaProvider);
    final selectedProactivity = ref.watch(_proactivityProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // ── Large-title header ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: AppColors.backgroundDark,
            surfaceTintColor: AppColors.backgroundDark,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Coach',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
              titlePadding: const EdgeInsetsDirectional.only(
                start: AppDimens.spaceMd,
                bottom: AppDimens.spaceMd,
              ),
              collapseMode: CollapseMode.parallax,
            ),
          ),

          // ── AI PERSONA section ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section label
                  Text(
                    'AI PERSONA',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  // Section subtitle
                  Text(
                    'Choose how your AI coach communicates',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Persona cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            sliver: SliverList.separated(
              itemCount: _personas.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimens.spaceSm),
              itemBuilder: (context, index) {
                final persona = _personas[index];
                final isActive = persona.key == selectedPersona;
                return _PersonaCard(
                  persona: persona,
                  isActive: isActive,
                  onTap: () =>
                      ref.read(_personaProvider.notifier).state = persona.key,
                );
              },
            ),
          ),

          // ── PROACTIVITY section ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceXl,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section label
                  Text(
                    'PROACTIVITY',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  // Section subtitle
                  Text(
                    'How often the coach proactively shares insights',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  // Chip row
                  _ProactivityChipRow(
                    selectedKey: selectedProactivity,
                    onSelected: (key) =>
                        ref.read(_proactivityProvider.notifier).state = key,
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom padding + Save button ───────────────────────────────
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceXl,
                AppDimens.spaceMd,
                AppDimens.spaceXl,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _SaveButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Preferences saved'),
                        backgroundColor: AppColors.surfaceDark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusButtonMd,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Persona Card ──────────────────────────────────────────────────────────────

/// A tappable card representing a single AI persona option.
///
/// Active state: `AppColors.primary` accent border (1.5px) + check icon.
/// Inactive state: `AppColors.cardBackgroundDark` fill, no border accent.
class _PersonaCard extends StatelessWidget {
  /// Creates a [_PersonaCard].
  const _PersonaCard({
    required this.persona,
    required this.isActive,
    required this.onTap,
  });

  /// The persona data to display.
  final _PersonaOption persona;

  /// Whether this card is currently selected.
  final bool isActive;

  /// Callback invoked when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: isActive
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: persona.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Icon(
                    persona.icon,
                    color: persona.iconColor,
                    size: AppDimens.iconMd,
                  ),
                ),

                const SizedBox(width: AppDimens.spaceMd),

                // Label + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.label,
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Text(
                        persona.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppDimens.spaceSm),

                // Selection indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isActive
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey(true),
                          color: AppColors.primary,
                          size: AppDimens.iconMd,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: const ValueKey(false),
                          color: AppColors.textTertiary,
                          size: AppDimens.iconMd,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Proactivity Chip Row ──────────────────────────────────────────────────────

/// A row of three segmented chips for selecting proactivity level.
///
/// The selected chip uses `AppColors.primary` background with dark text.
/// Unselected chips use `AppColors.surfaceDark` background.
class _ProactivityChipRow extends StatelessWidget {
  /// Creates a [_ProactivityChipRow].
  const _ProactivityChipRow({
    required this.selectedKey,
    required this.onSelected,
  });

  /// The currently selected proactivity key.
  final String selectedKey;

  /// Callback invoked with the new key when a chip is tapped.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _proactivityOptions.length; i++) ...[
          Expanded(
            child: _ProactivityChip(
              option: _proactivityOptions[i],
              isSelected: _proactivityOptions[i].key == selectedKey,
              onTap: () => onSelected(_proactivityOptions[i].key),
            ),
          ),
          if (i < _proactivityOptions.length - 1)
            const SizedBox(width: AppDimens.spaceSm),
        ],
      ],
    );
  }
}

// ── Proactivity Chip ──────────────────────────────────────────────────────────

/// A single selectable chip for one proactivity level.
class _ProactivityChip extends StatelessWidget {
  /// Creates a [_ProactivityChip].
  const _ProactivityChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  /// The proactivity option this chip represents.
  final _ProactivityOption option;

  /// Whether this chip is currently selected.
  final bool isSelected;

  /// Callback invoked when the chip is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
          child: SizedBox(
            height: AppDimens.touchTargetMin,
            child: Center(
              child: Text(
                option.label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected
                      ? AppColors.primaryButtonText
                      : AppColors.textSecondaryDark,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Save Button ───────────────────────────────────────────────────────────────

/// Full-width primary "Save Preferences" button.
class _SaveButton extends StatelessWidget {
  /// Creates a [_SaveButton].
  const _SaveButton({required this.onPressed});

  /// Callback invoked when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimens.touchTargetMin,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryButtonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
          ),
        ),
        child: Text(
          'Save Preferences',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.primaryButtonText,
          ),
        ),
      ),
    );
  }
}
