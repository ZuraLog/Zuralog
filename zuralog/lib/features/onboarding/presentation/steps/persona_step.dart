/// Zuralog — Onboarding Step 3: AI Persona.
///
/// Presents 3 persona cards (Motivator, Analyst, Coach) and a proactivity
/// slider. The selected persona determines the AI coach's communication style.
/// Each card has a 4px left accent bar; selected state shows a Sage Green border.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Persona Model ─────────────────────────────────────────────────────────────

class _Persona {
  const _Persona({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;

  /// Category color used for the 4px left accent bar.
  final Color accentColor;
}

const List<_Persona> _personas = [
  _Persona(
    id: 'motivator',
    icon: Icons.local_fire_department_rounded,
    title: 'Motivator',
    description: 'Energetic, upbeat, pushes you to achieve more every day.',
    accentColor: AppColors.categoryActivity,
  ),
  _Persona(
    id: 'analyst',
    icon: Icons.insights_rounded,
    title: 'Analyst',
    description: 'Data-driven, precise, explains the numbers behind your health.',
    accentColor: AppColors.categoryBody,
  ),
  _Persona(
    id: 'coach',
    icon: Icons.self_improvement_rounded,
    title: 'Coach',
    description: 'Balanced, supportive, focuses on sustainable long-term habits.',
    accentColor: AppColors.categoryWellness,
  ),
];

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 3 — AI persona selection + proactivity toggle.
class PersonaStep extends StatelessWidget {
  const PersonaStep({
    super.key,
    required this.selectedPersona,
    required this.proactivity,
    required this.onPersonaChanged,
    required this.onProactivityChanged,
  });

  final String selectedPersona;
  final double proactivity;
  final ValueChanged<String> onPersonaChanged;
  final ValueChanged<double> onProactivityChanged;

  String get _proactivityLabel {
    if (proactivity < 0.35) return 'Quiet — only when I ask';
    if (proactivity < 0.7) return 'Balanced';
    return 'Proactive — daily nudges';
  }

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
          // ── Heading ────────────────────────────────────────────────────
          Text(
            'Choose your\nAI persona',
            style: AppTextStyles.displayLarge.copyWith(
              color: colors.primary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Pick the coaching style that resonates with you.',
            style: AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Persona cards ─────────────────────────────────────────────
          ...List.generate(_personas.length, (index) {
            final persona = _personas[index];
            final isSelected = persona.id == selectedPersona;
            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    index < _personas.length - 1 ? AppDimens.spaceMd : 0,
              ),
              child: _PersonaCard(
                persona: persona,
                isSelected: isSelected,
                onTap: () => onPersonaChanged(persona.id),
              ),
            );
          }),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Proactivity section ───────────────────────────────────────
          Text(
            'Proactivity',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'How often should your AI coach reach out?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          ZSlider(
            value: proactivity,
            onChanged: onProactivityChanged,
          ),
          Center(
            child: Text(
              _proactivityLabel,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Persona Card ──────────────────────────────────────────────────────────────

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.isSelected,
    required this.onTap,
  });

  final _Persona persona;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZSelectableTile(
      isSelected: isSelected,
      onTap: onTap,
      showCheckIndicator: false,
      scaleTarget: 0.97,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 4px left accent bar ─────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 4,
                color: isSelected
                    ? persona.accentColor
                    : persona.accentColor.withValues(alpha: 0.25),
              ),

              // ── Card content ────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Row(
                    children: [
                      // Emoji icon in a circle.
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? persona.accentColor.withValues(alpha: 0.15)
                              : colors.surfaceRaised,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          persona.icon,
                          size: 24,
                          color: persona.accentColor,
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              persona.title,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: isSelected
                                    ? colors.primary
                                    : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              persona.description,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
