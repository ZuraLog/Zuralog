/// Zuralog — Compatible App Tile Widget.
///
/// A single row displaying a compatible third-party health/fitness app.
/// Tapping opens [CompatibleAppInfoSheet] with data flow details.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/compatible_app.dart';
import 'package:zuralog/features/integrations/presentation/widgets/compatible_app_info_sheet.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_logo.dart';
import 'package:zuralog/features/integrations/presentation/widgets/platform_badges.dart';

/// A list tile for a compatible health/fitness app.
///
/// Displays the app's logo, name, description, and platform badges.
/// Tapping opens an info bottom sheet explaining data flow.
///
/// Parameters:
///   app: The compatible app to display.
class CompatibleAppTile extends StatelessWidget {
  /// Creates a [CompatibleAppTile] for [app].
  const CompatibleAppTile({super.key, required this.app});

  /// The app to display.
  final CompatibleApp app;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => showCompatibleAppInfoSheet(context, app),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Logo ─────────────────────────────────────────────────────
            IntegrationLogo(
              id: app.id,
              name: app.name,
              simpleIconSlug: app.simpleIconSlug,
              brandColorValue: app.brandColor,
            ),
            const SizedBox(width: AppDimens.spaceMd),

            // ── Name + description ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    app.name,
                    style: AppTextStyles.h3.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.description,
                    style: AppTextStyles.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),

            // ── Platform badges ───────────────────────────────────────────
            PlatformBadges(
              supportsHealthKit: app.supportsHealthKit,
              supportsHealthConnect: app.supportsHealthConnect,
            ),
          ],
        ),
      ),
    );
  }
}
