/// Zuralog — Metric Tile widget.
///
/// A single tile in the Today tab's user-configurable metric grid.
///
/// Visual states:
///   - Lit: full category colour, shows today's value.
///   - Greyscale: muted/grey, shows '—' placeholder. Used when the metric
///     has not been logged or synced today.
///
/// Edit mode:
///   - When [inEditMode] is true, a red ✕ badge appears in the top-right
///     corner. Tapping it calls [onRemove].
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/metric_grid_models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns a short relative-time hint string for greyscale tiles, e.g. "4d ago".
/// Returns null when [data.lastLoggedAt] is null (user has never logged this).
String? _buildLastLoggedHint(MetricTileData data) {
  final at = data.lastLoggedAt;
  if (at == null) return null;

  final diff = DateTime.now().difference(at);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays == 1) {
    return 'yesterday';
  } else if (diff.inDays < 30) {
    return '${diff.inDays}d ago';
  } else if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    return '${months}mo ago';
  } else {
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }
}

// ── MetricTile ────────────────────────────────────────────────────────────────

/// A single user-pinned metric tile.
class MetricTile extends StatelessWidget {
  /// Creates a [MetricTile].
  const MetricTile({
    super.key,
    required this.data,
    this.inEditMode = false,
    this.onRemove,
  });

  /// The tile's data — metric type, value, colour.
  final MetricTileData data;

  /// When true, shows a remove button in the corner.
  final bool inEditMode;

  /// Called when the remove button is tapped. Only relevant when
  /// [inEditMode] is true.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final categoryColor = Color(data.categoryColor);

    // Build the last-logged hint shown on greyscale tiles.
    // e.g. "87kg · 4d ago"
    final hint = _buildLastLoggedHint(data);

    Widget tile = Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spaceSm,
        horizontal: AppDimens.spaceXs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji
          Text(data.emoji, style: TextStyle(fontSize: AppDimens.emojiSm)),
          const SizedBox(height: AppDimens.spaceXxs),
          // Today's value (lit) or last-logged value (unlit, if available)
          Text(
            data.isLit
                ? (data.value ?? '—')
                : (data.lastValue ?? '—'),
            style: AppTextStyles.labelMedium.copyWith(
              color: data.isLit ? categoryColor : colors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Metric label
          Text(
            data.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Last-logged date hint — only when not lit and we have a date
          if (!data.isLit && hint != null) ...[
            const SizedBox(height: 1),
            Text(
              hint,
              style: AppTextStyles.caption.copyWith(
                color: colors.textTertiary,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    // Apply greyscale filter when not lit
    if (!data.isLit) {
      tile = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.7, 0,
        ]),
        child: tile,
      );
    }

    // Always use a Stack so the widget tree stays stable between normal and
    // edit mode — this prevents Flutter from rebuilding with a different widget
    // type, which caused the "shrink" artefact when entering edit mode.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        if (inEditMode)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.statusError,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
