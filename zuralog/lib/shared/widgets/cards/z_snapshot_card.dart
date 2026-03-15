/// Zuralog Design System — Snapshot Card.
///
/// A small card showing today's value for a single health metric.
/// Used in the horizontally scrollable snapshot row on the Today screen.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';

/// A compact card showing today's value for one health metric.
///
/// When [data.isEmpty] is true, renders a dimmed empty state (opacity 0.5)
/// with a "—" value. Tapping opens the log sheet to encourage entry.
class ZSnapshotCard extends StatelessWidget {
  const ZSnapshotCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final SnapshotCardData data;

  /// Called when the card is tapped. The caller should open the log grid sheet.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: data.isEmpty ? 0.5 : 1.0,
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: AppDimens.spaceMd,
          ),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.icon,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                data.value ?? '—',
                style: AppTextStyles.titleMedium.copyWith(
                  color: data.isEmpty ? colors.textTertiary : colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (data.unit != null) ...[
                const SizedBox(height: 2),
                Text(
                  data.unit!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                data.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
