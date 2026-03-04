/// Zuralog — Onboarding Step 4: Connect Apps.
///
/// Shows a curated list of 6 featured integration tiles with a "Connect" CTA.
/// Connecting from onboarding is optional — users can also connect later via
/// Settings → Integrations. The step is read-only during onboarding; tapping
/// "Connect" navigates into the full Integrations Hub.
///
/// For the MVP onboarding this step is informational — showing users which
/// apps they can connect — without blocking flow on completion.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Featured Apps ─────────────────────────────────────────────────────────────

class _FeaturedApp {
  const _FeaturedApp({
    required this.name,
    required this.icon,
    required this.description,
    required this.color,
  });

  final String name;
  final IconData icon;
  final String description;
  final Color color;
}

const List<_FeaturedApp> _featuredApps = [
  _FeaturedApp(
    name: 'Apple Health',
    icon: Icons.favorite_rounded,
    description: 'Steps, heart rate, sleep & more',
    color: AppColors.categoryHeart,
  ),
  _FeaturedApp(
    name: 'Health Connect',
    icon: Icons.health_and_safety_rounded,
    description: 'Android health platform',
    color: AppColors.categoryActivity,
  ),
  _FeaturedApp(
    name: 'Strava',
    icon: Icons.directions_run_rounded,
    description: 'Running & cycling workouts',
    color: AppColors.brandStrava,
  ),
  _FeaturedApp(
    name: 'Fitbit',
    icon: Icons.watch_rounded,
    description: 'Activity, sleep & heart rate',
    color: AppColors.brandFitbit,
  ),
  _FeaturedApp(
    name: 'Oura Ring',
    icon: Icons.nightlight_round,
    description: 'Sleep, readiness & recovery',
    color: AppColors.brandOura,
  ),
  _FeaturedApp(
    name: 'MyFitnessPal',
    icon: Icons.restaurant_rounded,
    description: 'Nutrition & calorie tracking',
    color: AppColors.brandMfp,
  ),
];

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 4 — featured integration tiles.
///
/// Informational — shows which apps can be connected. Users can connect
/// later in Settings → Integrations.
class ConnectAppsStep extends StatelessWidget {
  const ConnectAppsStep({super.key});

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
            'Connect your\napps & devices',
            style: AppTextStyles.h1.copyWith(
              color: colorScheme.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Zuralog works best with your existing health apps. '
            'Connect them now or any time from Settings.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Integration tiles ──────────────────────────────────────────
          ...List.generate(_featuredApps.length, (index) {
            final app = _featuredApps[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _featuredApps.length - 1
                    ? AppDimens.spaceSm
                    : 0,
              ),
              child: _IntegrationTile(app: app),
            );
          }),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Footer note ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: AppDimens.iconSm,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    '45+ apps supported via Apple Health and Google Health Connect.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Integration Tile ──────────────────────────────────────────────────────────

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({required this.app});

  final _FeaturedApp app;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          // App icon in colored circle.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: app.color.withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Icon(app.icon, color: app.color, size: 22),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: AppTextStyles.h3
                      .copyWith(color: colorScheme.onSurface),
                ),
                Text(
                  app.description,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppDimens.radiusChip),
            ),
            child: Text(
              'Later',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
