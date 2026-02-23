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

/// A list tile representing a single third-party health integration.
///
/// Renders:
///   - A branded logo on the left (with [IntegrationLogo] fallback).
///   - The integration name and description.
///   - A status control on the right that depends on [IntegrationModel.status]:
///       - [IntegrationStatus.available] → [OutlinedButton] labelled "Connect".
///       - [IntegrationStatus.connected] → green "Connected" badge + disconnect
///         [IconButton] with [Icons.link_off_rounded].
///       - [IntegrationStatus.syncing] → [CircularProgressIndicator].
///       - [IntegrationStatus.comingSoon] → grey "Soon" pill badge.
///       - [IntegrationStatus.error] → error icon.
///
/// [comingSoon] tiles are rendered at 50% opacity and are fully non-interactive.
class IntegrationTile extends ConsumerWidget {
  /// Creates an [IntegrationTile] for the given [integration].
  const IntegrationTile({super.key, required this.integration});

  /// The integration data to render.
  final IntegrationModel integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComingSoon = integration.status == IntegrationStatus.comingSoon;

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
          _StatusControl(integration: integration),
        ],
      ),
    );

    // Dim the tile when the integration is coming soon.
    if (isComingSoon) {
      tile = Opacity(opacity: 0.5, child: tile);
    }

    return tile;
  }
}

// ── Status Control ─────────────────────────────────────────────────────────────

/// Renders the right-side status control for an [IntegrationTile].
///
/// Switches between a Connect [OutlinedButton], a Connected badge with a
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
        return _SoonBadge();

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
            _ConnectedBadge(),
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
        return OutlinedButton(
          onPressed: () => ref
              .read(integrationsProvider.notifier)
              .connect(integration.id, context),
          child: const Text('Connect'),
        );
    }
  }
}

// ── Connected Badge ────────────────────────────────────────────────────────────

/// A green pill badge reading "Connected".
///
/// Displayed alongside the disconnect [IconButton] when an integration is
/// in the [IntegrationStatus.connected] state.
class _ConnectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        'Connected',
        style: AppTextStyles.caption.copyWith(
          color: Colors.green.shade800,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 4,
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
