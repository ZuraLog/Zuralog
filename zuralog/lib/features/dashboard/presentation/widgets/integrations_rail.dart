/// Zuralog Dashboard — Integrations Rail Widget.
///
/// A horizontal scrollable row of branded integration status pills.
/// Each pill displays a brand icon, the app name, and a connection status dot.
/// Hardcoded integration list — real data wiring is deferred to Phase 2.3+.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Data class ────────────────────────────────────────────────────────────────

/// Represents one integration entry in the [IntegrationsRail].
///
/// [brandColor] is intentionally a raw hex colour — these are brand
/// identity colours that are not part of the Zuralog design-system palette.
class IntegrationPill {
  /// Creates an [IntegrationPill].
  const IntegrationPill({
    required this.name,
    required this.icon,
    required this.brandColor,
    required this.isConnected,
  });

  /// Human-readable name of the integration (e.g., "Strava").
  final String name;

  /// Icon representing the integration.
  final IconData icon;

  /// Brand accent colour used for the pill background and icon tint.
  ///
  // Brand color — not a design system token.
  final Color brandColor;

  /// Whether the user has connected this integration.
  final bool isConnected;
}

// ── Static integration list ───────────────────────────────────────────────────

const List<IntegrationPill> _kPills = [
  IntegrationPill(
    name: 'Strava',
    icon: Icons.directions_run_rounded,
    // Brand color — not a design system token.
    brandColor: Color(0xFFFC4C02),
    isConnected: false,
  ),
  IntegrationPill(
    name: 'Apple Health',
    icon: Icons.favorite_rounded,
    // Brand color — not a design system token.
    brandColor: Color(0xFFFF2D55),
    isConnected: false,
  ),
  IntegrationPill(
    name: 'Fitbit',
    icon: Icons.watch_rounded,
    // Brand color — not a design system token.
    brandColor: Color(0xFF00B0B9),
    isConnected: false,
  ),
  IntegrationPill(
    name: 'Garmin',
    icon: Icons.watch_later_rounded,
    // Brand color — not a design system token.
    brandColor: Color(0xFF006E9E),
    isConnected: false,
  ),
  IntegrationPill(
    name: 'MyFitnessPal',
    icon: Icons.restaurant_rounded,
    // Brand color — not a design system token.
    brandColor: Color(0xFF0088CC),
    isConnected: false,
  ),
];

// ── Widget ────────────────────────────────────────────────────────────────────

/// A labelled section containing a horizontally scrollable row of integration
/// status pills.
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
class IntegrationsRail extends StatelessWidget {
  /// Creates an [IntegrationsRail].
  const IntegrationsRail({super.key, this.onManageTap});

  /// Callback invoked when the "Manage" action link is tapped.
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
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _kPills.length,
            itemBuilder: (context, index) {
              return _IntegrationPillTile(pill: _kPills[index]);
            },
          ),
        ),
      ],
    );
  }
}

// ── Pill tile ─────────────────────────────────────────────────────────────────

/// A single branded integration pill tile.
///
/// Renders a semi-transparent brand-coloured background, the brand icon,
/// the app name, and a status dot in the top-right corner.
class _IntegrationPillTile extends StatelessWidget {
  /// Creates a [_IntegrationPillTile] for [pill].
  const _IntegrationPillTile({required this.pill});

  /// The integration data to render.
  final IntegrationPill pill;

  // Status dot size constant.
  static const double _dotSize = 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: AppDimens.integrationPillWidth,
      height: 64,
      margin: const EdgeInsets.only(right: AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: pill.brandColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(
          color: pill.brandColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // ── Centre content ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  pill.icon,
                  color: pill.brandColor,
                  size: 20,
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  pill.name,
                  style: AppTextStyles.caption.copyWith(
                    color: pill.brandColor,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Status dot (top-right) ─────────────────────────────────────
          Positioned(
            top: AppDimens.spaceXs,
            right: AppDimens.spaceXs,
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                // Green when connected, grey otherwise.
                color: pill.isConnected
                    ? const Color(0xFF34C759) // iOS system green
                    : AppColors.textSecondary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
