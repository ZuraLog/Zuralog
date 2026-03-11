/// Integrations Screen (under Settings).
///
/// Displays Connected, Available, and Coming Soon integrations. Reads live
/// data from [integrationsProvider] — the same source the Integrations Hub
/// uses — so connection status is always real and up-to-date.
///
/// Connect and Disconnect actions delegate to [IntegrationsNotifier], which
/// handles OAuth flows, device-local permissions, and backend API calls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Maps integration IDs to display icons.
const Map<String, IconData> _integrationIcons = {
  'strava': Icons.directions_run_rounded,
  'apple_health': Icons.favorite_rounded,
  'fitbit': Icons.watch_rounded,
  'oura': Icons.ring_volume_rounded,
  'withings': Icons.monitor_weight_rounded,
  'polar': Icons.monitor_heart_rounded,
  'google_health_connect': Icons.health_and_safety_rounded,
  'garmin': Icons.watch_rounded,
  'whoop': Icons.monitor_heart_rounded,
};

/// Maps integration IDs to icon tint colours.
const Map<String, Color> _integrationColors = {
  'strava': AppColors.categoryActivity,
  'apple_health': AppColors.categoryHeart,
  'fitbit': AppColors.categoryBody,
  'oura': AppColors.categorySleep,
  'withings': AppColors.categoryVitals,
  'polar': AppColors.categoryHeart,
  'google_health_connect': AppColors.primary,
  'garmin': AppColors.categoryVitals,
  'whoop': AppColors.categoryHeart,
};

/// Formats a [DateTime] as a human-readable relative time string.
String _formatLastSynced(DateTime? lastSynced) {
  if (lastSynced == null) return 'Never';
  final diff = DateTime.now().difference(lastSynced);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${lastSynced.month}/${lastSynced.day}/${lastSynced.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

/// Integrations management screen — displays Connected, Available, and Coming
/// Soon sections with sync status, platform badges, and real connect flows.
class IntegrationsScreen extends ConsumerWidget {
  /// Creates the [IntegrationsScreen].
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intState = ref.watch(integrationsProvider);

    // Split integrations into three buckets based on their current status.
    final connected = intState.integrations
        .where((i) =>
            i.status == IntegrationStatus.connected ||
            i.status == IntegrationStatus.syncing ||
            i.status == IntegrationStatus.error)
        .toList();
    final available = intState.integrations
        .where((i) => i.status == IntegrationStatus.available)
        .toList();
    final comingSoon = intState.integrations
        .where((i) => i.status == IntegrationStatus.comingSoon)
        .toList();

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
                  color: AppColorsOf(context).textPrimary,
                ),
              ),
            ),
          ),

          // ── Loading indicator ──────────────────────────────────────────────
          if (intState.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.spaceLg),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // ── Connected section ──────────────────────────────────────────────
          if (connected.isNotEmpty) ...[
            const _SectionHeader(label: 'CONNECTED'),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final integration = connected[index];
                  return _ConnectedCard(
                    key: ValueKey('connected_${integration.id}'),
                    integration: integration,
                  );
                },
                childCount: connected.length,
              ),
            ),
          ],

          // ── Available section ──────────────────────────────────────────────
          if (available.isNotEmpty) ...[
            const _SectionHeader(label: 'AVAILABLE'),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final integration = available[index];
                  return _AvailableCard(
                    key: ValueKey('available_${integration.id}'),
                    integration: integration,
                  );
                },
                childCount: available.length,
              ),
            ),
          ],

          // ── Coming soon section ────────────────────────────────────────────
          if (comingSoon.isNotEmpty) ...[
            const _SectionHeader(label: 'COMING SOON'),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final integration = comingSoon[index];
                  return _ComingSoonRow(
                    key: ValueKey('coming_${integration.id}'),
                    integration: integration,
                  );
                },
                childCount: comingSoon.length,
              ),
            ),
          ],

          // ── Empty state ────────────────────────────────────────────────────
          if (!intState.isLoading && intState.integrations.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: Center(
                  child: Text(
                    'No integrations available.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColorsOf(context).textSecondary,
                    ),
                  ),
                ),
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

class _ConnectedCard extends ConsumerWidget {
  const _ConnectedCard({super.key, required this.integration});

  final IntegrationModel integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final icon = _integrationIcons[integration.id] ?? Icons.extension_rounded;
    final iconColor = _integrationColors[integration.id] ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Material(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          onTap: () => _showConnectedBottomSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceMd,
            ),
            child: Row(
              children: [
                // Icon badge
                _IntegrationIconBadge(icon: icon, iconColor: iconColor),
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
                              color: colors.textPrimary,
                            ),
                          ),
                          if (integration.compatibility !=
                              PlatformCompatibility.all) ...[
                            const SizedBox(width: AppDimens.spaceSm),
                            _PlatformBadge(
                                compatibility: integration.compatibility),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last synced ${_formatLastSynced(integration.lastSynced)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
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

  void _showConnectedBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColorsOf(context).surface,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      builder: (ctx) =>
          _ConnectedBottomSheet(integration: integration),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Available integration card
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableCard extends ConsumerWidget {
  const _AvailableCard({super.key, required this.integration});

  final IntegrationModel integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final icon = _integrationIcons[integration.id] ?? Icons.extension_rounded;
    final iconColor = _integrationColors[integration.id] ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        child: Row(
          children: [
            // Icon badge
            _IntegrationIconBadge(icon: icon, iconColor: iconColor),
            const SizedBox(width: AppDimens.spaceMd),

            // Name + platform badge
            Expanded(
              child: Row(
                children: [
                  Text(
                    integration.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (integration.compatibility !=
                      PlatformCompatibility.all) ...[
                    const SizedBox(width: AppDimens.spaceSm),
                    _PlatformBadge(compatibility: integration.compatibility),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),

            // Connect button — calls the real integration flow
            _ConnectButton(integration: integration),
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

  final IntegrationModel integration;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final icon = _integrationIcons[integration.id] ?? Icons.extension_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Opacity(
        opacity: 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
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
                icon: icon,
                iconColor: AppColors.textTertiary,
              ),
              const SizedBox(width: AppDimens.spaceMd),

              // Name
              Expanded(
                child: Text(
                  integration.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),

              // "Coming soon" caption chip
              const _ComingSoonChip(),
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

/// 36x36 icon badge with a subtle tinted background.
class _IntegrationIconBadge extends StatelessWidget {
  const _IntegrationIconBadge({
    required this.icon,
    required this.iconColor,
  });

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ZIconBadge(
      icon: icon,
      color: iconColor,
      iconSize: 18,
    );
  }
}

/// Inline platform badge (iOS / Android).
class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.compatibility});

  final PlatformCompatibility compatibility;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (compatibility) {
      PlatformCompatibility.iosOnly => (Icons.apple, 'iOS only'),
      PlatformCompatibility.androidOnly => (Icons.android, 'Android'),
      PlatformCompatibility.all => (Icons.devices, 'All'),
    };

    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
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
      IntegrationStatus.syncing => (AppColors.statusConnecting, 'Syncing'),
      IntegrationStatus.error => (AppColors.statusError, 'Error'),
      IntegrationStatus.available => (AppColors.textTertiary, 'Available'),
      IntegrationStatus.comingSoon => (AppColors.textTertiary, 'Coming soon'),
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
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColorsOf(context).textSecondary),
        ),
      ],
    );
  }
}

/// Small "Connect" FilledButton for available integrations.
///
/// Calls [IntegrationsNotifier.connect] with the real integration ID,
/// triggering the actual OAuth flow or device permission request.
class _ConnectButton extends ConsumerWidget {
  const _ConnectButton({required this.integration});

  final IntegrationModel integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Disable the button if the integration isn't compatible with this device.
    final isCompatible = integration.isCompatibleWithCurrentPlatform;

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            isCompatible ? AppColors.primary : AppColors.textTertiary,
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
      onPressed: isCompatible
          ? () => ref
              .read(integrationsProvider.notifier)
              .connect(integration.id, context)
          : null,
      child: Text(isCompatible
          ? 'Connect'
          : (integration.incompatibilityNote ?? 'Unavailable')),
    );
  }
}

/// "Coming soon" caption chip for greyed-out integrations.
class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
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

class _ConnectedBottomSheet extends ConsumerWidget {
  const _ConnectedBottomSheet({required this.integration});

  final IntegrationModel integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final icon = _integrationIcons[integration.id] ?? Icons.extension_rounded;
    final iconColor = _integrationColors[integration.id] ?? AppColors.primary;

    return Padding(
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
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // Header row
          Row(
            children: [
              _IntegrationIconBadge(icon: icon, iconColor: iconColor),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      integration.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _StatusIndicator(status: integration.status),
                  ],
                ),
              ),
              if (integration.compatibility != PlatformCompatibility.all)
                _PlatformBadge(compatibility: integration.compatibility),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // Sync details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: colors.cardBackground,
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
                  value: _formatLastSynced(integration.lastSynced),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                _SyncDetailRow(
                  label: 'Status',
                  value: switch (integration.status) {
                    IntegrationStatus.connected => 'Active',
                    IntegrationStatus.syncing => 'Syncing...',
                    IntegrationStatus.error => 'Error - tap to retry',
                    IntegrationStatus.available => 'Disconnected',
                    IntegrationStatus.comingSoon => 'Coming soon',
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // Disconnect action — calls the real disconnect method
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
              onPressed: () => _confirmDisconnect(context, ref),
              child: Text(
                'Disconnect',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        title: Text(
          'Disconnect ${integration.name}?',
          style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Your historical data will be retained. You can reconnect at any time.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Actually disconnect via the real provider.
              ref
                  .read(integrationsProvider.notifier)
                  .disconnect(integration.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Disconnect',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.accent,
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
    final colors = AppColorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
