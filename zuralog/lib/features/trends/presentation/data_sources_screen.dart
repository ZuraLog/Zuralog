/// Data Sources Screen — /trends/sources
///
/// Read-only data provenance screen. Shows per-integration cards with:
///   - Integration name + icon
///   - Connection status dot (green/yellow/red)
///   - Last sync timestamp
///   - Data types contributed as chips
///   - Reconnect button for error-state integrations
///   (Reconnect navigates to Settings > Integrations — this screen is
///    read-only provenance, not connection management.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:simple_icons/simple_icons.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/features/trends/providers/trends_providers.dart';

// ── DataSourcesScreen ─────────────────────────────────────────────────────────

/// Data Sources screen — integration sync provenance.
class DataSourcesScreen extends ConsumerWidget {
  /// Creates the [DataSourcesScreen].
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(dataSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources'),
      ),
      body: sourcesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _DataSourcesErrorState(
          onRetry: () => ref.invalidate(dataSourcesProvider),
        ),
        data: (sourceList) => sourceList.sources.isEmpty
            ? const _EmptySourcesState()
            : _DataSourcesList(sources: sourceList.sources),
      ),
    );
  }
}

// ── Sources List ──────────────────────────────────────────────────────────────

class _DataSourcesList extends ConsumerWidget {
  const _DataSourcesList({
    required this.sources,
  });

  final List<DataSource> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group: connected first, then disconnected
    final connected = sources.where((s) => s.isConnected).toList();
    final disconnected = sources.where((s) => !s.isConnected).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(hapticServiceProvider).light();
        ref.invalidate(dataSourcesProvider);
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        children: [
          if (connected.isNotEmpty) ...[
            _SectionLabel(label: 'Connected'),
            ...connected.map((s) => _DataSourceCard(source: s)),
            const SizedBox(height: AppDimens.spaceMd),
          ],
          if (disconnected.isNotEmpty) ...[
            _SectionLabel(label: 'Not Connected'),
            ...disconnected.map((s) => _DataSourceCard(source: s)),
          ],
          const SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppDimens.spaceSm,
        top: AppDimens.spaceSm,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Data Source Card ──────────────────────────────────────────────────────────

class _DataSourceCard extends ConsumerWidget {
  const _DataSourceCard({required this.source});
  final DataSource source;

  Color _freshnessColor(DataFreshness freshness) {
    switch (freshness) {
      case DataFreshness.fresh:
        return AppColors.statusConnected;
      case DataFreshness.stale:
        return AppColors.statusConnecting;
      case DataFreshness.error:
        return AppColors.statusError;
    }
  }

  String _lastSyncLabel() {
    if (source.lastSyncedAt == null) return 'Never synced';
    try {
      final dt = DateTime.parse(source.lastSyncedAt!).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (_) {
      return source.lastSyncedAt!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freshnessColor = _freshnessColor(source.freshness);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────
          Row(
            children: [
              // Integration brand icon
              _IntegrationIcon(integrationId: source.integrationId),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.name, style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Freshness dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: source.isConnected
                                ? freshnessColor
                                : AppColors.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceXs),
                        Text(
                          source.isConnected
                              ? 'Last synced: ${_lastSyncLabel()}'
                              : 'Not connected',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Error badge
              if (source.hasError && source.isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusError.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusChip),
                  ),
                  child: Text(
                    'Error',
                    style: AppTextStyles.labelXs
                        .copyWith(color: AppColors.statusError),
                  ),
                ),
            ],
          ),

          // ── Data types chips ───────────────────────────────────
          if (source.dataTypes.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Wrap(
              spacing: AppDimens.spaceXs,
              runSpacing: AppDimens.spaceXs,
              children: source.dataTypes
                  .map(
                    (type) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusChip),
                      ),
                      child: Text(
                        type,
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          // ── Error message ──────────────────────────────────────
          if (source.hasError && source.errorMessage != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Unable to sync data. Please reconnect.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.statusError,
              ),
            ),
          ],

          // ── Reconnect button ───────────────────────────────────
          if (source.hasError || !source.isConnected) ...[
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.read(hapticServiceProvider).medium();
                  context.push(RouteNames.settingsIntegrationsPath);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusButtonMd),
                  ),
                ),
                child: Text(
                  source.isConnected ? 'Reconnect' : 'Connect',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty / Error States ──────────────────────────────────────────────────────

// ── Integration Brand Icon ────────────────────────────────────────────────────

/// Displays the brand icon for a known integration ID using [simple_icons].
/// Falls back to a generic hub icon for unknown integrations.
class _IntegrationIcon extends StatelessWidget {
  const _IntegrationIcon({required this.integrationId});
  final String integrationId;

  /// Returns [iconData, iconColor] for known integration IDs.
  /// Color is the brand's official color. Falls back to generic hub icon.
  (IconData, Color) _brandIcon() {
    switch (integrationId.toLowerCase()) {
      case 'strava':
        return (SimpleIcons.strava, const Color(0xFFFC4C02));
      case 'fitbit':
        return (SimpleIcons.fitbit, const Color(0xFF00B0B9));
      case 'garmin':
        return (SimpleIcons.garmin, const Color(0xFF007DC5));
      case 'apple_health':
      case 'apple health':
        return (SimpleIcons.apple, const Color(0xFFE8E8E8));
      case 'google_fit':
      case 'google fit':
        return (SimpleIcons.googlefit, const Color(0xFF4285F4));
      default:
        return (Icons.hub_rounded, AppColors.textSecondaryDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (iconData, iconColor) = _brandIcon();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor,
      ),
    );
  }
}

// ── Empty / Error States ──────────────────────────────────────────────────────

class _EmptySourcesState extends StatelessWidget {
  const _EmptySourcesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.device_hub_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text('No Data Sources', style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Connect integrations in Settings to see your data sources here.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: () =>
                  context.push(RouteNames.settingsIntegrationsPath),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryButtonText,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusButtonMd),
                ),
              ),
              child: const Text('Connect Integrations'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataSourcesErrorState extends StatelessWidget {
  const _DataSourcesErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text('Could not load data sources', style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryButtonText,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusButtonMd),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
