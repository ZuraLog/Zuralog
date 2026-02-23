/// Zuralog Dashboard — Integrations Rail Widget.
///
/// A horizontal scrollable row of branded integration status pills.
/// Each pill displays the integration logo asset, the app name, and a
/// connection status dot. Live data is sourced from [integrationsProvider],
/// filtered to [IntegrationStatus.connected] entries only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Main widget ───────────────────────────────────────────────────────────────

/// A labelled section containing a horizontally scrollable row of integration
/// status pills, driven by live data from [integrationsProvider].
///
/// Only integrations with [IntegrationStatus.connected] are shown.
/// When no integrations are connected, an empty-state prompt is rendered
/// inside the same chrome ([_RailShell]).
///
/// Tapping the "Manage" action invokes [onManageTap], typically navigating to
/// the integrations hub screen.
///
/// Example:
/// ```dart
/// IntegrationsRail(
///   onManageTap: () => context.go(RouteNames.integrationsPath),
/// )
/// ```
class IntegrationsRail extends ConsumerWidget {
  /// Creates an [IntegrationsRail].
  const IntegrationsRail({super.key, this.onManageTap});

  /// Callback invoked when the "Manage" action link is tapped.
  final VoidCallback? onManageTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationsState = ref.watch(integrationsProvider);
    final connected = integrationsState.integrations
        .where((i) => i.status == IntegrationStatus.connected)
        .toList();

    return _RailShell(
      onManageTap: onManageTap,
      child: connected.isEmpty
          ? const _EmptyState()
          : SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: connected.length,
                itemBuilder: (context, index) {
                  return _IntegrationPillTile(integration: connected[index]);
                },
              ),
            ),
    );
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────

/// Chrome wrapper that renders the "Connected Apps" section header and the
/// "Manage" action link above whatever [child] content is provided.
///
/// Extracted so the header/footer chrome is reusable independently of
/// whether pills or an empty state is displayed inside.
class _RailShell extends StatelessWidget {
  /// Creates a [_RailShell].
  const _RailShell({required this.child, this.onManageTap});

  /// The content to render below the section header row.
  final Widget child;

  /// Callback for the "Manage" action link.
  final VoidCallback? onManageTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Connected Apps',
          actionLabel: 'Manage',
          onAction: onManageTap,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        child,
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

/// Shown inside [_RailShell] when no integrations are connected.
///
/// Prompts the user to connect an app via the integrations hub.
class _EmptyState extends StatelessWidget {
  /// Creates an [_EmptyState].
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Icon(
            Icons.link_off_rounded,
            size: AppDimens.iconSm,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            'No apps connected',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pill tile ─────────────────────────────────────────────────────────────────

/// A single branded integration pill tile for a connected [IntegrationModel].
///
/// Renders a semi-transparent brand-coloured background, the integration logo
/// (with initials fallback), the app name, and a green status dot indicating
/// the connected state.
class _IntegrationPillTile extends StatelessWidget {
  /// Creates an [_IntegrationPillTile] for [integration].
  const _IntegrationPillTile({required this.integration});

  /// The connected integration to render.
  final IntegrationModel integration;

  // Status dot size constant.
  static const double _dotSize = 8.0;

  // Connected status colour — iOS system green.
  static const Color _connectedColor = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: AppDimens.integrationPillWidth,
      height: 64,
      margin: const EdgeInsets.only(right: AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // ── Centre content ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with initials fallback.
                _IntegrationLogo(
                  logoAsset: integration.logoAsset,
                  name: integration.name,
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  integration.name,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Status dot (top-right) — always green for connected ──────────
          Positioned(
            top: AppDimens.spaceXs,
            right: AppDimens.spaceXs,
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: const BoxDecoration(
                color: _connectedColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo helper ───────────────────────────────────────────────────────────────

/// Renders the integration logo from [logoAsset], falling back to a two-letter
/// initials [Text] if the asset cannot be loaded.
///
/// Parameters:
///   logoAsset: Asset path for the integration image.
///   name: Integration name used to derive initials for the fallback.
class _IntegrationLogo extends StatelessWidget {
  /// Creates an [_IntegrationLogo].
  const _IntegrationLogo({required this.logoAsset, required this.name});

  /// Asset path for the integration logo.
  final String logoAsset;

  /// Integration name used for the initials fallback.
  final String name;

  /// Derives up to two-character initials from [name].
  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      logoAsset,
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Text(
        _initials,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
