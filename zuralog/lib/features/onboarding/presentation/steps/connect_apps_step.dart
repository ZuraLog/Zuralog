/// Zuralog — Onboarding Step 6: Connect Apps.
///
/// Shows the platform's native health integration (Apple Health on iOS,
/// Health Connect on Android) as a prominent connectable card, plus a
/// preview grid of third-party integrations available later in Settings.
///
/// Tapping the health card triggers the real permission flow via
/// [IntegrationsNotifier.connect], which requests HealthKit / Health Connect
/// access, configures background sync, and fires the initial 30-day import.
///
/// Third-party integrations (Strava, Fitbit, Oura, MyFitnessPal) require
/// OAuth flows that need the full app context, so they show "Later" badges
/// and can be connected from Settings → Integrations after onboarding.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Third-party Apps (connect later via Settings) ────────────────────────────

class _ThirdPartyApp {
  const _ThirdPartyApp({
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

const List<_ThirdPartyApp> _thirdPartyApps = [
  _ThirdPartyApp(
    name: 'Strava',
    icon: Icons.directions_run_rounded,
    description: 'Running & cycling workouts',
    color: AppColors.brandStrava,
  ),
  _ThirdPartyApp(
    name: 'Fitbit',
    icon: Icons.watch_rounded,
    description: 'Activity, sleep & heart rate',
    color: AppColors.brandFitbit,
  ),
  _ThirdPartyApp(
    name: 'Oura Ring',
    icon: Icons.nightlight_round,
    description: 'Sleep, readiness & recovery',
    color: AppColors.brandOura,
  ),
  _ThirdPartyApp(
    name: 'MyFitnessPal',
    icon: Icons.restaurant_rounded,
    description: 'Nutrition & calorie tracking',
    color: AppColors.brandMfp,
  ),
];

// ── Step Widget ──────────────────────────────────────────────────────────────

/// Step 6 — health platform connection + third-party integration preview.
class ConnectAppsStep extends ConsumerWidget {
  const ConnectAppsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final integrationsState = ref.watch(integrationsProvider);

    // Show the platform-appropriate health integration.
    final healthId =
        Platform.isIOS ? 'apple_health' : 'google_health_connect';
    final healthName = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    final healthDescription = Platform.isIOS
        ? 'Steps, heart rate, sleep & more from HealthKit'
        : 'Sync workouts and health data from Android';
    final healthIcon =
        Platform.isIOS ? Icons.favorite_rounded : Icons.health_and_safety_rounded;
    final healthColor =
        Platform.isIOS ? AppColors.categoryHeart : AppColors.categoryActivity;

    // Check connection status from the integrations provider.
    final healthModel = integrationsState.integrations.cast<IntegrationModel?>().firstWhere(
          (i) => i!.id == healthId,
          orElse: () => null,
        );
    final healthStatus = healthModel?.status ?? IntegrationStatus.available;
    final isConnected = healthStatus == IntegrationStatus.connected;
    final isConnecting = healthStatus == IntegrationStatus.syncing;

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
          // ── Heading ──────────────────────────────────────────────────────
          Text(
            'Connect your\nhealth data',
            style: AppTextStyles.displayLarge.copyWith(
              color: colors.primary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Zuralog works best when it can read your health data. '
            'Connect now to get personalised insights right away.',
            style: AppTextStyles.bodyLarge
                .copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Primary health platform card ─────────────────────────────────
          _HealthConnectCard(
            name: healthName,
            description: healthDescription,
            icon: healthIcon,
            color: healthColor,
            isConnected: isConnected,
            isConnecting: isConnecting,
            onConnect: () {
              ref.read(integrationsProvider.notifier).connect(healthId, context);
            },
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Third-party integrations header ──────────────────────────────
          Text(
            'More integrations',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Connect these from Settings after setup.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Third-party grid ─────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppDimens.spaceMd,
              crossAxisSpacing: AppDimens.spaceMd,
              childAspectRatio: 1.6,
            ),
            itemCount: _thirdPartyApps.length,
            itemBuilder: (context, index) =>
                _ThirdPartyTile(app: _thirdPartyApps[index]),
          ),

          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Health Connect Card ──────────────────────────────────────────────────────

/// Prominent card for the platform health integration with a Connect button.
class _HealthConnectCard extends StatelessWidget {
  const _HealthConnectCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.isConnecting,
    required this.onConnect,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: isConnected
            ? colors.primary.withValues(alpha: 0.08)
            : colors.surface,
        border: Border.all(
          color: isConnected ? colors.primary : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon badge.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              // Name + description.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // Connect / Connected button.
          SizedBox(
            width: double.infinity,
            child: ZButton(
              label: isConnected
                  ? 'Connected'
                  : isConnecting
                      ? 'Connecting...'
                      : 'Connect',
              icon: isConnected ? Icons.check_circle_rounded : null,
              variant: isConnected
                  ? ZButtonVariant.secondary
                  : ZButtonVariant.primary,
              size: ZButtonSize.medium,
              isLoading: isConnecting,
              onPressed: isConnected || isConnecting ? null : onConnect,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Third-party Tile ─────────────────────────────────────────────────────────

/// Compact tile for third-party integrations available after onboarding.
class _ThirdPartyTile extends StatelessWidget {
  const _ThirdPartyTile({required this.app});

  final _ThirdPartyApp app;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App icon.
          ZIconBadge(
            icon: app.icon,
            color: app.color,
            size: 36,
            iconSize: 18,
          ),

          // Name + "Later" badge.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.name,
                style: AppTextStyles.labelMedium
                    .copyWith(color: colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'In Settings',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
