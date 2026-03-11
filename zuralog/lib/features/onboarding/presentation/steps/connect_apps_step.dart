/// Zuralog — Onboarding Step 4: Connect Apps.
///
/// Shows a curated 2-column grid of 6 featured integration tiles.
/// Each tile has a brand-color icon, app name, description, and a "Later"
/// pill badge. Connecting from onboarding is optional — users can connect
/// later via Settings → Integrations.
///
/// For the MVP onboarding this step is informational — showing users which
/// apps they can connect — without blocking flow on completion.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

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

/// Step 4 — featured integration tiles in a 2-column grid.
///
/// Informational — shows which apps can be connected. Users can connect
/// later in Settings → Integrations.
class ConnectAppsStep extends StatelessWidget {
  const ConnectAppsStep({super.key});

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
            style: AppTextStyles.body.copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── 2-column integration grid ──────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppDimens.spaceMd,
              crossAxisSpacing: AppDimens.spaceMd,
              childAspectRatio: 1.0,
            ),
            itemCount: _featuredApps.length,
            itemBuilder: (context, index) =>
                _IntegrationTile(app: _featuredApps[index]),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Footer note ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimens.shapeSm),
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
                        .copyWith(color: colors.textSecondary),
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
    final colors = AppColorsOf(context);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App icon in rounded colored container.
          ZIconBadge(
            icon: app.icon,
            color: app.color,
            size: 44,
            iconSize: 22,
          ),

          // Name + description.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.name,
                style: AppTextStyles.h3
                    .copyWith(color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                app.description,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: colors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // "Later" pill badge.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimens.shapePill),
              ),
              child: Text(
                'Later',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
