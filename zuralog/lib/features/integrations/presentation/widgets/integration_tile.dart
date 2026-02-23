/// Zuralog — Integration Tile Widget.
///
/// A single row in the Integrations Hub list, showing the integration logo,
/// name, description, and an appropriate status control (Connect button,
/// Connected badge with disconnect icon, "Soon" badge,
/// or [CircularProgressIndicator]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/presentation/widgets/disconnect_sheet.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_logo.dart';

// ── Internal dimension constants ──────────────────────────────────────────────

/// Height of the compact connect pill button.
const double _kConnectButtonHeight = 30.0;

/// Horizontal padding inside the connect pill button.
const double _kConnectButtonPaddingH = 10.0;

/// A list tile representing a single third-party health integration.
///
/// Renders:
///   - A branded logo on the left (with [IntegrationLogo] fallback).
///   - The integration name and description.
///   - A status control on the right that depends on [IntegrationModel.status]:
///       - [IntegrationStatus.available] → neutral pill [_ConnectButton] labelled "Connect".
///       - [IntegrationStatus.connected] → green "Connected" badge + disconnect
///         [IconButton] with [Icons.link_off_rounded].
///       - [IntegrationStatus.syncing] → [CircularProgressIndicator].
///       - [IntegrationStatus.comingSoon] → grey "Soon" pill badge.
///       - [IntegrationStatus.error] → error icon.
///
/// Opacity rules:
///   - [comingSoon] tiles are rendered at 50% opacity (non-interactive).
///   - Incompatible-platform tiles are rendered at 45% opacity and show an
///     [_IncompatibleBadge] instead of the Connect button.
class IntegrationTile extends ConsumerWidget {
  /// Creates an [IntegrationTile] for the given [integration].
  const IntegrationTile({super.key, required this.integration});

  /// The integration data to render.
  final IntegrationModel integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComingSoon = integration.status == IntegrationStatus.comingSoon;
    final isIncompatible = !integration.isCompatibleWithCurrentPlatform;

    Widget tile = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Logo ─────────────────────────────────────────────────────────
          IntegrationLogo(
            id: integration.id,
            logoAsset: integration.logoAsset,
            name: integration.name,
          ),
          const SizedBox(width: AppDimens.spaceMd),

          // ── Name + description ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  integration.name,
                  style: AppTextStyles.h3.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  integration.description,
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),

          // ── Status control ────────────────────────────────────────────────
          // Show incompatibility badge when the integration does not support
          // the current platform; otherwise fall through to the normal status
          // control.
          if (isIncompatible)
            _IncompatibleBadge(label: integration.incompatibilityNote ?? '')
          else
            _StatusControl(integration: integration),
        ],
      ),
    );

    // Dim the tile when coming soon OR when incompatible with this platform.
    if (isComingSoon) {
      tile = Opacity(opacity: 0.5, child: tile);
    } else if (isIncompatible) {
      tile = Opacity(opacity: 0.45, child: tile);
    }

    return tile;
  }
}

// ── Status Control ─────────────────────────────────────────────────────────────

/// Renders the right-side status control for an [IntegrationTile].
///
/// Switches between a neutral [_ConnectButton] pill, a Connected badge with a
/// disconnect [IconButton], a "Soon" badge, a loading spinner, or an error
/// icon depending on [IntegrationModel.status].
class _StatusControl extends ConsumerWidget {
  /// Creates a [_StatusControl] for the given [integration].
  const _StatusControl({required this.integration});

  /// The integration whose status drives the rendered control.
  final IntegrationModel integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (integration.status) {
      case IntegrationStatus.syncing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

      case IntegrationStatus.comingSoon:
        return const _SoonBadge();

      case IntegrationStatus.error:
        return Icon(
          Icons.error_outline_rounded,
          color: AppColors.accentLight,
          size: AppDimens.iconMd,
        );

      case IntegrationStatus.connected:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ConnectedBadge(),
            IconButton(
              icon: const Icon(Icons.link_off_rounded),
              tooltip: 'Disconnect',
              onPressed: () => showDisconnectSheet(
                context,
                integration,
                () => ref
                    .read(integrationsProvider.notifier)
                    .disconnect(integration.id),
              ),
            ),
          ],
        );

      case IntegrationStatus.available:
        return _ConnectButton(
          onPressed: () => ref
              .read(integrationsProvider.notifier)
              .connect(integration.id, context),
        );
    }
  }
}

// ── Connect Button ─────────────────────────────────────────────────────────────

/// A compact, neutral pill-shaped button used to initiate an integration
/// connection.
///
/// Intentionally **not** green — green is reserved exclusively for the
/// [_ConnectedBadge] success state. This button uses the surface-variant
/// palette so it reads as a secondary/neutral action without implying success.
///
/// Parameters:
///   onPressed: Callback invoked when the user taps "Connect".
class _ConnectButton extends StatelessWidget {
  /// Creates a [_ConnectButton] with the given [onPressed] callback.
  const _ConnectButton({required this.onPressed});

  /// Callback invoked on tap.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: _kConnectButtonHeight,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: cs.onSurface.withValues(alpha: 0.08),
          foregroundColor: cs.onSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: _kConnectButtonPaddingH,
            vertical: 0,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
        icon: Icon(Icons.add_rounded, size: AppDimens.iconSm),
        label: Text(
          'Connect',
          style: AppTextStyles.caption.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Connected Badge ────────────────────────────────────────────────────────────

/// A green pill badge reading "Connected".
///
/// Displayed alongside the disconnect [IconButton] when an integration is
/// in the [IntegrationStatus.connected] state.
class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.statusConnected.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        'Connected',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.statusConnected,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Soon Badge ─────────────────────────────────────────────────────────────────

/// A greyed-out pill badge reading "Soon".
///
/// Displayed on [IntegrationStatus.comingSoon] tiles instead of a switch.
class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        'Soon',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Incompatible Badge ─────────────────────────────────────────────────────────

/// A neutral pill badge indicating that an integration is not available on
/// the current platform (e.g. "iOS only" or "Android only").
///
/// Uses the same pill shape as [_SoonBadge] for visual consistency, but
/// renders [AppColors.textSecondary] text on a [surfaceContainerHighest]
/// background to keep it clearly distinct from the green "Connected" badge
/// and the coral error state.
///
/// Parameters:
///   label: The human-readable incompatibility note (e.g. `'iOS only'`).
class _IncompatibleBadge extends StatelessWidget {
  /// Creates an [_IncompatibleBadge] with the given platform [label].
  const _IncompatibleBadge({required this.label});

  /// Short platform label to display (e.g. `'iOS only'`, `'Android only'`).
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
