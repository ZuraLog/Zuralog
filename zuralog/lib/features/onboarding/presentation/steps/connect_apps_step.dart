/// Zuralog — Onboarding Step 6: Connect Apps.
///
/// Shows the platform's native health integration (Apple Health on iOS,
/// Health Connect on Android) as a prominent connectable card, plus a
/// compact row of third-party integrations available later in Settings.
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

// ── Step Widget ──────────────────────────────────────────────────────────────

/// Step 6 — health platform connection + third-party integration preview.
class ConnectAppsStep extends ConsumerWidget {
  const ConnectAppsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final integrationsState = ref.watch(integrationsProvider);

    // Platform-appropriate health integration.
    final healthId =
        Platform.isIOS ? 'apple_health' : 'google_health_connect';
    final healthName = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    final healthDescription = Platform.isIOS
        ? 'Automatically sync your health data from HealthKit'
        : 'Automatically sync your health data from Android';
    final healthIcon = Platform.isIOS
        ? Icons.favorite_rounded
        : Icons.health_and_safety_rounded;
    final healthColor =
        Platform.isIOS ? AppColors.categoryHeart : AppColors.categoryActivity;

    // Connection status from the integrations provider.
    final healthModel = integrationsState.integrations
        .cast<IntegrationModel?>()
        .firstWhere((i) => i!.id == healthId, orElse: () => null);
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
          // ── Heading ────────────────────────────────────────────────────
          Text(
            'Connect your\nhealth data',
            style: AppTextStyles.displayLarge.copyWith(
              color: colors.primary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Get personalised insights powered by your real health data.',
            style: AppTextStyles.bodyLarge
                .copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Health platform card ───────────────────────────────────────
          _HealthConnectCard(
            name: healthName,
            description: healthDescription,
            icon: healthIcon,
            color: healthColor,
            isConnected: isConnected,
            isConnecting: isConnecting,
            onConnect: () {
              ref
                  .read(integrationsProvider.notifier)
                  .connect(healthId, context);
            },
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Third-party integrations ───────────────────────────────────
          Text(
            'More integrations available',
            style: AppTextStyles.labelLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Horizontal row of app icons.
          Row(
            children: [
              _AppIconChip(
                icon: Icons.directions_run_rounded,
                label: 'Strava',
                color: AppColors.brandStrava,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _AppIconChip(
                icon: Icons.watch_rounded,
                label: 'Fitbit',
                color: AppColors.brandFitbit,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _AppIconChip(
                icon: Icons.nightlight_round,
                label: 'Oura',
                color: AppColors.brandOura,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _AppIconChip(
                icon: Icons.restaurant_rounded,
                label: 'MFP',
                color: AppColors.brandMfp,
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // Footer note.
          Text(
            'Connect these and 40+ more from Settings after setup.',
            style: AppTextStyles.bodySmall
                .copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Health Connect Card ──────────────────────────────────────────────────────

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
            ? colors.primary.withValues(alpha: 0.06)
            : colors.surface,
        border: Border.all(
          color: isConnected
              ? colors.primary
              : colors.border,
          width: isConnected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + name row.
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: AppDimens.spaceMd),
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
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // Feature bullets.
          _FeatureBullet(
            icon: Icons.sync_rounded,
            text: 'Background sync — always up to date',
            colors: colors,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _FeatureBullet(
            icon: Icons.insights_rounded,
            text: 'AI-powered trends and health insights',
            colors: colors,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _FeatureBullet(
            icon: Icons.lock_outline_rounded,
            text: 'Your data stays private and secure',
            colors: colors,
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // Connect button — secondary to avoid competing with the
          // primary patterned "Next" button at the bottom of the screen.
          SizedBox(
            width: double.infinity,
            child: ZButton(
              label: isConnected
                  ? 'Connected'
                  : isConnecting
                      ? 'Connecting...'
                      : 'Connect ${Platform.isIOS ? 'Apple Health' : 'Health Connect'}',
              icon: isConnected ? Icons.check_circle_rounded : null,
              variant: isConnected
                  ? ZButtonVariant.secondary
                  : ZButtonVariant.primary,
              size: ZButtonSize.large,
              isLoading: isConnecting,
              onPressed: isConnected || isConnecting ? null : onConnect,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature Bullet ───────────────────────────────────────────────────────────

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.text,
    required this.colors,
  });

  final IconData icon;
  final String text;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── App Icon Chip ────────────────────────────────────────────────────────────

class _AppIconChip extends StatelessWidget {
  const _AppIconChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
