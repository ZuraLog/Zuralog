/// Coach Settings Screen — AI persona, proactivity level, response length,
/// suggested prompts, and voice input.
///
/// ## Fixes applied (settings-mapping remediation)
/// All 5 settings previously used file-private [StateProvider]s that were
/// saved to the API on tap but never loaded back — resetting to defaults on
/// every cold start and being invisible to the Coach tab UI.
///
/// They now read from and write to [userPreferencesProvider], which is the
/// global [AsyncNotifier] that loads from [GET /api/v1/preferences] on app
/// start and persists changes via [PATCH /api/v1/preferences] + SharedPrefs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/analytics/feature_flag_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

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

// ── Proactivity / Chip Data Model ─────────────────────────────────────────────

/// Descriptor for a single segmented chip option (proactivity or response length).
class _ProactivityOption {
  const _ProactivityOption({required this.key, required this.label});

  /// Unique string key used by the relevant [StateProvider].
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

/// The two available response length options in display order.
const List<_ProactivityOption> _responseLengthOptions = [
  _ProactivityOption(key: 'concise', label: 'Concise'),
  _ProactivityOption(key: 'detailed', label: 'Detailed'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Coach Settings screen — AI persona, proactivity level, response length,
/// suggested prompts and voice input configuration.
///
/// Uses a [CustomScrollView] with [SliverAppBar] large-title and
/// [SliverList] content sections. Local UI state is managed via
/// [StateProvider]s and Riverpod's [ConsumerStatefulWidget].
class CoachSettingsScreen extends ConsumerStatefulWidget {
  /// Creates a [CoachSettingsScreen].
  const CoachSettingsScreen({super.key});

  @override
  ConsumerState<CoachSettingsScreen> createState() =>
      _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends ConsumerState<CoachSettingsScreen> {
  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Seed AI persona from PostHog feature flag — only if the user has never
    // saved a preference (i.e., preferences loaded and persona is still the
    // server default 'balanced').
    ref
        .read(featureFlagServiceProvider)
        .aiPersonaDefault()
        .then((flagPersona) {
      if (!mounted) return;
      final current = ref.read(userPreferencesProvider).valueOrNull;
      if (current != null && current.coachPersona == CoachPersona.balanced) {
        final seeded = CoachPersona.fromValue(flagPersona);
        if (seeded != CoachPersona.balanced) {
          ref.read(userPreferencesProvider.notifier).mutate(
                (p) => p.copyWith(coachPersona: seeded),
              );
        }
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // Read from global preferences — fall back to safe defaults while loading.
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;
    final selectedPersona =
        prefs?.coachPersona.value ?? CoachPersona.balanced.value;
    final selectedProactivity =
        prefs?.proactivityLevel.value ?? ProactivityLevel.medium.value;
    final selectedResponseLength =
        prefs?.responseLength.value ?? ResponseLength.concise.value;
    final selectedSuggestedPrompts = prefs?.suggestedPromptsEnabled ?? true;
    final selectedVoiceInput = prefs?.voiceInputEnabled ?? true;

    return ZuralogScaffold(
      body: CustomScrollView(
        slivers: [
          // ── Large-title header ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Coach',
                style: AppTextStyles.displaySmall.copyWith(
                  color: colors.textPrimary,
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
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  // Section subtitle
                  Text(
                    'Choose how your AI coach communicates',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
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
                  onTap: () {
                    ref.read(userPreferencesProvider.notifier).mutate(
                          (p) => p.copyWith(
                            coachPersona:
                                CoachPersona.fromValue(persona.key),
                          ),
                        );
                    ref.read(analyticsServiceProvider).capture(
                      event: AnalyticsEvents.personaChanged,
                      properties: {'persona': persona.key},
                    );
                  },
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
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  // Section subtitle
                  Text(
                    'How often the coach proactively shares insights',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  // Chip row
                  _ProactivityChipRow(
                    options: _proactivityOptions,
                    selectedKey: selectedProactivity,
                    onSelected: (key) {
                      ref.read(userPreferencesProvider.notifier).mutate(
                            (p) => p.copyWith(
                              proactivityLevel:
                                  ProactivityLevel.fromValue(key),
                            ),
                          );
                      ref.read(analyticsServiceProvider).capture(
                        event: AnalyticsEvents.proactivityChanged,
                        properties: {'level': key},
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── RESPONSE LENGTH section ────────────────────────────────────
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
                    'RESPONSE LENGTH',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  // Section subtitle
                  Text(
                    'How detailed AI responses should be',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  // Chip row
                  _ProactivityChipRow(
                    options: _responseLengthOptions,
                    selectedKey: selectedResponseLength,
                    onSelected: (key) {
                      ref.read(userPreferencesProvider.notifier).mutate(
                            (p) => p.copyWith(
                              responseLength: ResponseLength.fromValue(key),
                            ),
                          );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── PREFERENCES section (toggles) ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceXl,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Text(
                'PREFERENCES',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textTertiary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Suggested Prompts',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Show prompt chips in new conversations',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      value: selectedSuggestedPrompts,
                      onChanged: (v) =>
                          ref.read(userPreferencesProvider.notifier).mutate(
                                (p) => p.copyWith(suggestedPromptsEnabled: v),
                              ),
                      activeThumbColor: colors.primary,
                      activeTrackColor: colors.primary.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceXs,
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colors.border,
                      indent: AppDimens.spaceMd,
                    ),
                    SwitchListTile(
                      title: Text(
                        'Voice Input',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Enable hold-to-talk microphone button',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      value: selectedVoiceInput,
                      onChanged: (v) =>
                          ref.read(userPreferencesProvider.notifier).mutate(
                                (p) => p.copyWith(voiceInputEnabled: v),
                              ),
                      activeThumbColor: colors.primary,
                      activeTrackColor: colors.primary.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceXs,
                      ),
                    ),
                  ],
                ),
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
                    // Changes are already auto-saved via userPreferencesProvider.
                    // This button provides explicit user confirmation.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Preferences saved'),
                        backgroundColor: colors.surface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusButtonMd),
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
    final colors = AppColorsOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: isActive
            ? Border.all(color: colors.primary, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: [
                // Icon container
                ZIconBadge(
                  icon: persona.icon,
                  color: persona.iconColor,
                  size: 44,
                  iconSize: AppDimens.iconMd,
                ),

                const SizedBox(width: AppDimens.spaceMd),

                // Label + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.label,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Text(
                        persona.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
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
                          color: colors.primary,
                          size: AppDimens.iconMd,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: const ValueKey(false),
                          color: colors.textTertiary,
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

// ── Proactivity / Response Length Chip Row ────────────────────────────────────

/// A row of segmented chips for selecting a value from a list of options.
///
/// Used for both proactivity level (3 chips) and response length (2 chips).
/// The selected chip uses `AppColors.primary` background with dark text.
/// Unselected chips use `AppColors.surfaceDark` background.
class _ProactivityChipRow extends StatelessWidget {
  /// Creates a [_ProactivityChipRow].
  const _ProactivityChipRow({
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  /// The ordered list of options to render as chips.
  final List<_ProactivityOption> options;

  /// The currently selected option key.
  final String selectedKey;

  /// Callback invoked with the new key when a chip is tapped.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: _ProactivityChip(
              option: options[i],
              isSelected: options[i].key == selectedKey,
              onTap: () => onSelected(options[i].key),
            ),
          ),
          if (i < options.length - 1)
            const SizedBox(width: AppDimens.spaceSm),
        ],
      ],
    );
  }
}

// ── Proactivity Chip ──────────────────────────────────────────────────────────

/// A single selectable chip for one option in a chip row.
class _ProactivityChip extends StatelessWidget {
  /// Creates a [_ProactivityChip].
  const _ProactivityChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  /// The option this chip represents.
  final _ProactivityOption option;

  /// Whether this chip is currently selected.
  final bool isSelected;

  /// Callback invoked when the chip is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? colors.primary : colors.surface,
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
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected
                      ? AppColors.primaryButtonText
                      : colors.textSecondary,
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
    return ZButton(
      label: 'Save Preferences',
      onPressed: onPressed,
    );
  }
}
