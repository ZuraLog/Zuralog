/// Zuralog — Compatible App Info Bottom Sheet.
///
/// Shows details about how a compatible third-party app feeds data into
/// Zuralog through Apple HealthKit or Google Health Connect.
///
/// Use [showCompatibleAppInfoSheet] to present this sheet.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/compatible_app.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_logo.dart';
import 'package:zuralog/features/integrations/presentation/widgets/platform_badges.dart';

/// Shows a modal bottom sheet with details about [app].
///
/// Parameters:
///   context: The build context for presenting the sheet.
///   app: The compatible app to display information for.
void showCompatibleAppInfoSheet(BuildContext context, CompatibleApp app) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => CompatibleAppInfoSheet(app: app),
  );
}

/// The content widget for the compatible app info bottom sheet.
///
/// Displays the app's logo, name, platform badges, data flow explanation,
/// and optional action buttons (deep link + store link).
///
/// Parameters:
///   app: The compatible app to display.
class CompatibleAppInfoSheet extends StatelessWidget {
  /// Creates a [CompatibleAppInfoSheet] for [app].
  const CompatibleAppInfoSheet({super.key, required this.app});

  /// The compatible app to display information for.
  final CompatibleApp app;

  /// Launches the given [url] in an external application.
  ///
  /// Parameters:
  ///   url: The URL string to open.
  ///
  /// Silently ignores errors (e.g., app not installed for deep links).
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently ignore — app may not be installed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceSm,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // ── App header: logo + name ──────────────────────────────────────
            Row(
              children: [
                IntegrationLogo(
                  id: app.id,
                  name: app.name,
                  simpleIconSlug: app.simpleIconSlug,
                  brandColorValue: app.brandColor,
                  size: 44,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Text(
                    app.name,
                    style: AppTextStyles.h3.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // ── Platform badges ──────────────────────────────────────────────
            PlatformBadges(
              supportsHealthKit: app.supportsHealthKit,
              supportsHealthConnect: app.supportsHealthConnect,
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // ── Divider ──────────────────────────────────────────────────────
            Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: AppDimens.spaceSm),

            // ── How data flows ───────────────────────────────────────────────
            Text(
              'How data flows',
              style: AppTextStyles.caption.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              app.dataFlowExplanation,
              style: AppTextStyles.body.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // ── Action buttons ───────────────────────────────────────────────
            if (app.deepLinkUrl != null || app.storeUrl != null) ...[
              if (app.deepLinkUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _launch(app.deepLinkUrl!),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceSm,
                      ),
                    ),
                    child: Text(
                      'Open App',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (app.storeUrl != null) ...[
                if (app.deepLinkUrl != null)
                  const SizedBox(height: AppDimens.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _launch(app.storeUrl!),
                    style: TextButton.styleFrom(
                      backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                      foregroundColor: cs.onSurface,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceSm,
                      ),
                    ),
                    child: Text(
                      'Open in Store',
                      style: AppTextStyles.body.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
