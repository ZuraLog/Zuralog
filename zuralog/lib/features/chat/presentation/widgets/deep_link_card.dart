/// Zuralog Edge Agent — Deep Link Card Widget.
///
/// Renders an actionable card when the AI assistant returns a [clientAction]
/// payload (e.g., opening the Strava app or a fallback URL). The card shows
/// an icon, title, and subtitle from the action data. Tapping launches the
/// URL via [url_launcher]. Falls back to a SnackBar on failure.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/theme/theme.dart';

/// An actionable card that renders a client-side deep-link action.
///
/// Displayed inside a message bubble when [ChatMessage.clientAction] is
/// non-null. Shows the action's title and subtitle, and opens the action URL
/// on tap using [url_launcher].
class DeepLinkCard extends StatelessWidget {
  /// The client action payload from the AI message.
  ///
  /// Expected keys:
  /// - `'title'` (String) — card headline.
  /// - `'subtitle'` (String) — card description.
  /// - `'url'` (String) — primary URL to launch.
  /// - `'fallback_url'` (String, optional) — secondary URL if primary fails.
  final Map<String, dynamic> clientAction;

  /// Creates a [DeepLinkCard].
  ///
  /// [clientAction] must not be empty.
  const DeepLinkCard({super.key, required this.clientAction});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = clientAction['title'] as String? ?? 'Open Link';
    final subtitle = clientAction['subtitle'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: isDark ? null : AppDimens.cardShadowLight,
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ───────────────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.primary,
                size: AppDimens.iconMd,
              ),
            ),

            const SizedBox(width: AppDimens.spaceMd),

            // ── Text Content ───────────────────────────────────────────────
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimens.spaceXs),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: AppDimens.spaceSm),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: AppDimens.iconMd,
            ),
          ],
        ),
      ),
    );
  }

  /// Handles a tap on the card — launches the action URL.
  ///
  /// Attempts the primary `'url'` first, then the `'fallback_url'` if
  /// the primary cannot be launched. Shows a [SnackBar] on failure.
  Future<void> _handleTap(BuildContext context) async {
    final primaryUrl = clientAction['url'] as String?;
    final fallbackUrl = clientAction['fallback_url'] as String?;

    if (primaryUrl == null && fallbackUrl == null) {
      _showError(context, 'No URL provided in this action.');
      return;
    }

    // Try primary URL first.
    if (primaryUrl != null) {
      final uri = Uri.tryParse(primaryUrl);
      if (uri != null && await launchUrl(uri)) return;
    }

    // Fall back to the fallback URL.
    if (fallbackUrl != null) {
      final uri = Uri.tryParse(fallbackUrl);
      if (uri != null && await launchUrl(uri)) return;
    }

    if (context.mounted) {
      _showError(context, 'Could not open the link. Please try again.');
    }
  }

  /// Shows an error [SnackBar] on [context].
  ///
  /// [message] is the human-readable error description.
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
