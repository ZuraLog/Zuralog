/// Zuralog Design System — Error State Widget.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';

/// Displays an error message with an optional retry button.
///
/// Same card layout as [ZEmptyState] but without the pattern overlay,
/// and uses error red for the icon per brand bible.
///
/// Example:
/// ```dart
/// ZErrorState(
///   message: 'Failed to load data.',
///   onRetry: () => ref.refresh(dataProvider),
/// )
/// ```
class ZErrorState extends StatelessWidget {
  const ZErrorState({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 36,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                message,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppDimens.spaceLg),
                ZButton(
                  label: 'Try Again',
                  onPressed: onRetry,
                  isFullWidth: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
