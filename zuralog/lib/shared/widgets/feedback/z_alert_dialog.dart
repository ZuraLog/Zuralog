/// Zuralog Design System — Alert Dialog Component.
///
/// Confirmation dialog with brand-correct surface, typography,
/// and primary/destructive action buttons with pattern overlay.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A themed alert dialog following the Zuralog design system.
///
/// Uses [surfaceOverlay] background with [shapeXl] corners, and provides
/// a confirm/cancel button pair. The confirm button can be styled as
/// destructive (red) when [isDestructive] is true.
///
/// Prefer the static [ZAlertDialog.show] helper for simple confirm/cancel
/// flows.
class ZAlertDialog extends StatelessWidget {
  const ZAlertDialog({
    super.key,
    required this.title,
    this.body,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  /// The dialog headline.
  final String title;

  /// Optional descriptive text below the title.
  final String? body;

  /// Text for the confirm (right) button.
  final String confirmLabel;

  /// Text for the cancel (left) button.
  final String cancelLabel;

  /// When true, the confirm button uses the error color instead of Sage.
  final bool isDestructive;

  /// Shows a confirm/cancel dialog and returns `true` when confirmed,
  /// `false` when cancelled, or `null` when dismissed via the barrier.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? body,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (_) => ZAlertDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final confirmColor =
        isDestructive ? AppColors.error : AppColors.primary;
    final confirmTextColor =
        isDestructive ? Colors.white : AppColors.textOnSage;

    return Dialog(
      backgroundColor: colors.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.shapeXl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title.
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),

            // Body.
            if (body != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                body!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: AppDimens.spaceLg),

            // Button row.
            Row(
              children: [
                // Cancel button — outlined.
                Expanded(
                  child: _OutlinedButton(
                    label: cancelLabel,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Confirm button — filled with pattern.
                Expanded(
                  child: _FilledPatternButton(
                    label: confirmLabel,
                    backgroundColor: confirmColor,
                    textColor: confirmTextColor,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private helper buttons ──────────────────────────────────────────────────

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
          border: Border.all(
            color: const Color(0x33F0EEE9), // rgba(240,238,233,0.2)
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.warmWhite,
          ),
        ),
      ),
    );
  }
}

class _FilledPatternButton extends StatelessWidget {
  const _FilledPatternButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        child: SizedBox(
          height: 48,
          child: Stack(
            children: [
              // Solid fill.
              Positioned.fill(
                child: ColoredBox(color: backgroundColor),
              ),
              // Pattern overlay on the colored surface.
              Positioned.fill(
                child: ZPatternOverlay(
                  variant: ZPatternVariant.sage,
                  opacity: 0.12,
                ),
              ),
              // Label.
              Center(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
