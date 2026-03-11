/// Integrations Screen (under Settings).
///
/// Connected / Available / Coming Soon integrations. Rebuild of the existing
/// Integrations Hub, relocated under Settings. Compact sync status badge
/// (green/yellow/red dot), last-synced timestamp, OAuth connect flows.
///
/// Full implementation: Phase 8, Task 8.6.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain models
// ─────────────────────────────────────────────────────────────────────────────

/// Connection status for a synced integration.
enum IntegrationStatus { connected, connecting, error }

/// Target platform for platform-badge display.
enum IntegrationPlatform { ios, android, both }

/// Data model for a connected integration.
class ConnectedIntegration {
  const ConnectedIntegration({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.status,
    required this.lastSynced,
    this.platform,
  });

  final String name;
  final IconData icon;
  final Color iconColor;
  final IntegrationStatus status;
  final String lastSynced;
  final IntegrationPlatform? platform;
}

/// Data model for an available (not yet connected) integration.
class AvailableIntegration {
  const AvailableIntegration({
    required this.name,
    required this.icon,
    required this.iconColor,
    this.platform,
  });

  final String name;
  final IconData icon;
  final Color iconColor;
  final IntegrationPlatform? platform;
}

/// Data model for a coming-soon integration.
class ComingSoonIntegration {
  const ComingSoonIntegration({
    required this.name,
    required this.icon,
    required this.iconColor,
  });

  final String name;
  final IconData icon;
  final Color iconColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock data
// ─────────────────────────────────────────────────────────────────────────────

const List<ConnectedIntegration> _connectedIntegrations = [
  ConnectedIntegration(
    name: 'Strava',
    icon: Icons.directions_run_rounded,
    iconColor: AppColors.categoryActivity,
    status: IntegrationStatus.connected,
    lastSynced: '2 min ago',
  ),
  ConnectedIntegration(
    name: 'Apple Health',
    icon: Icons.favorite_rounded,
    iconColor: AppColors.categoryHeart,
    status: IntegrationStatus.connected,
    lastSynced: 'Just now',
    platform: IntegrationPlatform.ios,
  ),
  ConnectedIntegration(
    name: 'Fitbit',
    icon: Icons.watch_rounded,
    iconColor: AppColors.categoryBody,
    status: IntegrationStatus.connecting,
    lastSynced: '1 hour ago',
  ),
];

const List<AvailableIntegration> _availableIntegrations = [
  AvailableIntegration(
    name: 'Google Fit',
    icon: Icons.fitness_center_rounded,
    iconColor: AppColors.categoryActivity,
    platform: IntegrationPlatform.android,
  ),
  AvailableIntegration(
    name: 'Garmin',
    icon: Icons.watch_rounded,
    iconColor: AppColors.categoryVitals,
  ),
  AvailableIntegration(
    name: 'Health Connect',
    icon: Icons.health_and_safety_rounded,
    iconColor: AppColors.primary,
    platform: IntegrationPlatform.android,
  ),
];

const List<ComingSoonIntegration> _comingSoonIntegrations = [
  ComingSoonIntegration(
    name: 'MyFitnessPal',
    icon: Icons.restaurant_rounded,
    iconColor: AppColors.categoryNutrition,
  ),
  ComingSoonIntegration(
    name: 'Oura Ring',
    icon: Icons.ring_volume_rounded,
    iconColor: AppColors.categorySleep,
  ),
  ComingSoonIntegration(
    name: 'Whoop',
    icon: Icons.monitor_heart_rounded,
    iconColor: AppColors.categoryHeart,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

/// Integrations management screen — displays Connected, Available, and Coming
/// Soon sections with sync status, platform badges, and OAuth connect flows.
class IntegrationsScreen extends ConsumerWidget {
  /// Creates the [IntegrationsScreen].
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZuralogScaffold(
      body: CustomScrollView(
        slivers: [
          // ── Large-title app bar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                bottom: AppDimens.spaceMd,
              ),
              title: Text(
                'Integrations',
                style: AppTextStyles.displaySmall.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ),

          // ── Connected section ──────────────────────────────────────────────
          if (_connectedIntegrations.isNotEmpty) ...[
            _SectionHeader(label: 'CONNECTED'),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final integration = _connectedIntegrations[index];
                  return _ConnectedCard(
                    key: ValueKey('connected_${integration.name}'),
                    integration: integration,
                  );
                },
                childCount: _connectedIntegrations.length,
              ),
            ),
          ],

          // ── Available section ──────────────────────────────────────────────
          _SectionHeader(label: 'AVAILABLE'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final integration = _availableIntegrations[index];
                return _AvailableCard(
                  key: ValueKey('available_${integration.name}'),
                  integration: integration,
                );
              },
              childCount: _availableIntegrations.length,
            ),
          ),

          // ── Coming soon section ────────────────────────────────────────────
          _SectionHeader(label: 'COMING SOON'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final integration = _comingSoonIntegrations[index];
                return _ComingSoonRow(
                  key: ValueKey('coming_${integration.name}'),
                  integration: integration,
                );
              },
              childCount: _comingSoonIntegrations.length,
            ),
          ),

          // ── Bottom breathing room ──────────────────────────────────────────
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spaceXxl),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppDimens.spaceMd,
          right: AppDimens.spaceMd,
          top: AppDimens.spaceLg,
          bottom: AppDimens.spaceSm,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connected integration card
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({super.key, required this.integration});

  final ConnectedIntegration integration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Material(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          onTap: () => _showConnectedBottomSheet(context, integration),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceMd,
            ),
            child: Row(
              children: [
                // Icon badge
                _IntegrationIconBadge(
                  icon: integration.icon,
                  iconColor: integration.iconColor,
                ),
                const SizedBox(width: AppDimens.spaceMd),

                // Name + last synced
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            integration.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          if (integration.platform != null) ...[
                            const SizedBox(width: AppDimens.spaceSm),
                            _PlatformBadge(platform: integration.platform!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last synced ${integration.lastSynced}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),

                // Status indicator
                _StatusIndicator(status: integration.status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConnectedBottomSheet(
    BuildContext context,
    ConnectedIntegration integration,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      builder: (ctx) => _ConnectedBottomSheet(integration: integration),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Available integration card
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({super.key, required this.integration});

  final AvailableIntegration integration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        child: Row(
          children: [
            // Icon badge
            _IntegrationIconBadge(
              icon: integration.icon,
              iconColor: integration.iconColor,
            ),
            const SizedBox(width: AppDimens.spaceMd),

            // Name + platform badge
            Expanded(
              child: Row(
                children: [
                  Text(
                    integration.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (integration.platform != null) ...[
                    const SizedBox(width: AppDimens.spaceSm),
                    _PlatformBadge(platform: integration.platform!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),

            // Connect button
            _ConnectButton(integrationName: integration.name),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coming soon row
// ─────────────────────────────────────────────────────────────────────────────

class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({super.key, required this.integration});

  final ComingSoonIntegration integration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Opacity(
        opacity: 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceMd,
          ),
          child: Row(
            children: [
              // Greyed-out icon badge
              _IntegrationIconBadge(
                icon: integration.icon,
                iconColor: AppColors.textTertiary,
              ),
              const SizedBox(width: AppDimens.spaceMd),

              // Name
              Expanded(
                child: Text(
                  integration.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),

              // "Coming soon" caption chip
              _ComingSoonChip(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// 36×36 icon badge with a subtle tinted background.
class _IntegrationIconBadge extends StatelessWidget {
  const _IntegrationIconBadge({
    required this.icon,
    required this.iconColor,
  });

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

/// Inline platform badge (iOS / Android).
class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.platform});

  final IntegrationPlatform platform;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (platform) {
      IntegrationPlatform.ios => (Icons.apple, 'iOS only'),
      IntegrationPlatform.android => (Icons.android, 'Android'),
      IntegrationPlatform.both => (Icons.devices, 'All'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.textTertiary),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 8px status dot + label for connected integrations.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final IntegrationStatus status;

  @override
  Widget build(BuildContext context) {
    final (dotColor, label) = switch (status) {
      IntegrationStatus.connected => (AppColors.statusConnected, 'Connected'),
      IntegrationStatus.connecting => (
        AppColors.statusConnecting,
        'Connecting',
      ),
      IntegrationStatus.error => (AppColors.statusError, 'Error'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Small "Connect" FilledButton for available integrations.
class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.integrationName});

  final String integrationName;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryButtonText,
        minimumSize: const Size(72, 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
        ),
        textStyle: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _showConnectDialog(context),
      child: const Text('Connect'),
    );
  }

  void _showConnectDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        title: Text(
          'Connect $integrationName?',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryDark),
        ),
        content: Text(
          'This will open the OAuth flow to authorize Zuralog to read your $integrationName data.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
              ),
              textStyle: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// "Coming soon" caption chip for greyed-out integrations.
class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        'Coming soon',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connected integration bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectedBottomSheet extends StatelessWidget {
  const _ConnectedBottomSheet({required this.integration});

  final ConnectedIntegration integration;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // Header row
            Row(
              children: [
                _IntegrationIconBadge(
                  icon: integration.icon,
                  iconColor: integration.iconColor,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        integration.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _StatusIndicator(status: integration.status),
                    ],
                  ),
                ),
                if (integration.platform != null)
                  _PlatformBadge(platform: integration.platform!),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // Sync details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.cardBackgroundDark,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYNC DETAILS',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  _SyncDetailRow(
                    label: 'Last synced',
                    value: integration.lastSynced,
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  _SyncDetailRow(
                    label: 'Status',
                    value: switch (integration.status) {
                      IntegrationStatus.connected => 'Active',
                      IntegrationStatus.connecting => 'Syncing…',
                      IntegrationStatus.error => 'Error — tap to retry',
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // Disconnect action
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceMd,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  ),
                ),
                onPressed: () => _confirmDisconnect(context),
                child: Text(
                  'Disconnect',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.accentDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        title: Text(
          'Disconnect ${integration.name}?',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryDark),
        ),
        content: Text(
          'Your historical data will be retained. You can reconnect at any time.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Disconnect',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single label/value row inside the sync details panel.
class _SyncDetailRow extends StatelessWidget {
  const _SyncDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
