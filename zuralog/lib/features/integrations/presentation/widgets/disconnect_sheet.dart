/// Zuralog — Disconnect Confirmation Bottom Sheet.
///
/// Provides the [showDisconnectSheet] helper function that presents a
/// modal bottom sheet asking the user to confirm disconnecting a
/// third-party integration.
///
/// Uses the "safe-action-prominent" pattern:
///   - Primary button → "Keep Connected" (safe, prominent).
///   - Text button    → "Disconnect" (destructive, visually subdued).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_logo.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Presents a modal bottom sheet confirming the disconnection of [integration].
///
/// Follows the safe-action-prominent UX pattern: the keep-connected action
/// is the visually dominant button, and the destructive disconnect action
/// is a plain text button.
///
/// Parameters:
///   context: The [BuildContext] used to show the sheet.
///   integration: The [IntegrationModel] the user wants to disconnect.
///   onConfirm: Callback invoked when the user confirms disconnection.
///     The sheet is dismissed automatically after calling this callback.
void showDisconnectSheet(
  BuildContext context,
  IntegrationModel integration,
  VoidCallback onConfirm,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusCard),
      ),
    ),
    builder: (sheetContext) => _DisconnectSheetContent(
      integration: integration,
      onConfirm: () {
        onConfirm();
        Navigator.of(sheetContext).pop();
      },
      onCancel: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// Internal widget that renders the disconnect sheet content.
///
/// Extracted to keep [showDisconnectSheet] concise and testable.
class _DisconnectSheetContent extends StatelessWidget {
  /// Creates [_DisconnectSheetContent].
  const _DisconnectSheetContent({
    required this.integration,
    required this.onConfirm,
    required this.onCancel,
  });

  /// The integration being disconnected.
  final IntegrationModel integration;

  /// Called when the user confirms disconnection.
  final VoidCallback onConfirm;

  /// Called when the user chooses to keep the integration connected.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            const SizedBox(height: AppDimens.spaceMd),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // ── Integration logo + name + badge ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IntegrationLogo(
                  id: integration.id,
                  logoAsset: integration.logoAsset,
                  name: integration.name,
                  size: 44,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(integration.name, style: AppTextStyles.h3),
                    const SizedBox(height: AppDimens.spaceXs),
                    // Red "Connected" badge.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                      ),
                      child: Text(
                        'Connected',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // ── Warning text ───────────────────────────────────────────────
            Text(
              'Disconnecting will stop syncing data from ${integration.name}.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXl),

            // ── Action buttons (safe-action-prominent pattern) ─────────────
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Keep Connected',
                onPressed: onCancel,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onConfirm,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
                child: const Text('Disconnect'),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
  }
}
