/// Zuralog Design System — Category Summary Card.
///
/// Editorial one-card-per-category surface used by the Data tab.
/// Each card presents a single health category (Sleep, Activity, Heart,
/// Nutrition, …) with a gradient emblem, a large Lora hero value,
/// a plain-English summary sentence, a shared 7-day sparkline, and a
/// footer chevron that routes into the category's detail screen.
///
/// The card's shell is a [ZuralogSpringButton] wrapping a
/// [ZuralogCard] with [ZCardVariant.feature] so the per-category pattern
/// overlay matches the insight card treatment on the Today tab.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/z_mini_sparkline.dart';

/// Direction of a week-over-week delta shown in the hero row pill.
///
/// - [better]  — the change is positive for the user (green pill).
/// - [worse]   — the change is negative for the user (amber pill).
/// - [flat]    — no meaningful change (neutral pill).
/// - [none]    — no delta available; pill falls back to neutral styling.
enum ZCategoryDelta { better, worse, flat, none }

/// One-card-per-category surface for the Data tab.
///
/// Rendering contract:
/// 1. Top row  — 40pt gradient emblem, category name, 'Today' eyebrow.
/// 2. Hero row — large Lora value (38pt) plus optional delta pill.
/// 3. Summary  — single plain-English sentence, up to two lines.
/// 4. Sparkline — rendered only when [trend] has 3+ values.
/// 5. Footer   — 'View details' (or 'Connect a source' when [isNoData])
///    followed by a chevron tinted with the category color.
class ZCategorySummaryCard extends StatelessWidget {
  /// Creates a [ZCategorySummaryCard].
  const ZCategorySummaryCard({
    super.key,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.heroValue,
    required this.summaryLine,
    required this.trend,
    required this.todayIndex,
    required this.onTap,
    this.deltaLabel,
    this.deltaDirection = ZCategoryDelta.none,
    this.isNoData = false,
    this.onConnectTap,
  });

  /// Display name of the category ('Sleep', 'Activity', 'Heart', …).
  final String categoryName;

  /// Flat line icon rendered inside the emblem tile.
  final IconData icon;

  /// Category accent color — drives the emblem gradient, sparkline,
  /// feature-card pattern overlay, and footer chevron.
  final Color color;

  /// Pre-formatted hero value ('7h 24m', '74 bpm', '—').
  final String heroValue;

  /// Single plain-English sentence describing today's state.
  final String summaryLine;

  /// Seven daily values, oldest first. Pass an empty list to hide the
  /// sparkline. Fewer than three values also hides it.
  final List<double> trend;

  /// Index of today inside [trend]; pass -1 to hide the "today" glow dot.
  final int todayIndex;

  /// Called on whole-card tap when the card has data (or when
  /// [onConnectTap] is null in the no-data state).
  final VoidCallback onTap;

  /// Pre-formatted delta label shown in the pill ('↑ 12m vs last week').
  /// When null, the pill is hidden entirely.
  final String? deltaLabel;

  /// Direction used to tint the delta pill. Ignored when [deltaLabel]
  /// is null.
  final ZCategoryDelta deltaDirection;

  /// Whether the card should render its dimmed "no data / not connected"
  /// treatment. The shell + layout stay identical; only the opacity and
  /// footer text change.
  final bool isNoData;

  /// Optional "connect a source" callback. When [isNoData] is true and
  /// this is non-null, tapping the card calls this instead of [onTap].
  final VoidCallback? onConnectTap;

  @override
  Widget build(BuildContext context) {
    final VoidCallback effectiveTap =
        (isNoData && onConnectTap != null) ? onConnectTap! : onTap;
    final showSparkline = trend.length >= 3;

    return ZuralogSpringButton(
      onTap: effectiveTap,
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: color,
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Opacity(
          opacity: isNoData ? 0.62 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopRow(
                categoryName: categoryName,
                icon: icon,
                color: color,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              _HeroRow(
                heroValue: heroValue,
                deltaLabel: deltaLabel,
                deltaDirection: deltaDirection,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                summaryLine,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColorsOf(context).textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (showSparkline) ...[
                const SizedBox(height: AppDimens.spaceMd),
                ZMiniSparkline(
                  values: trend,
                  todayIndex: todayIndex,
                  color: color,
                ),
              ],
              const SizedBox(height: AppDimens.spaceSm),
              _FooterRow(color: color, isNoData: isNoData),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top row ──────────────────────────────────────────────────────────────────

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.categoryName,
    required this.icon,
    required this.color,
  });

  final String categoryName;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CategoryEmblem(icon: icon, color: color),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Text(
            categoryName,
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          'Today',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ── Category emblem ──────────────────────────────────────────────────────────

class _CategoryEmblem extends StatelessWidget {
  const _CategoryEmblem({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── Hero row ─────────────────────────────────────────────────────────────────

class _HeroRow extends StatelessWidget {
  const _HeroRow({
    required this.heroValue,
    required this.deltaLabel,
    required this.deltaDirection,
  });

  final String heroValue;
  final String? deltaLabel;
  final ZCategoryDelta deltaDirection;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            heroValue,
            style: AppTextStyles.displayLarge.copyWith(
              fontFamily: 'Lora',
              fontWeight: FontWeight.w600,
              fontSize: 38,
              height: 1.05,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (deltaLabel != null) ...[
          const SizedBox(width: AppDimens.spaceSm),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _DeltaPill(
              label: deltaLabel!,
              direction: deltaDirection,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Delta pill ───────────────────────────────────────────────────────────────

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.label, required this.direction});

  final String label;
  final ZCategoryDelta direction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final Color background;
    final Color foreground;
    switch (direction) {
      case ZCategoryDelta.better:
        background = colors.success.withValues(alpha: 0.14);
        foreground = colors.success;
        break;
      case ZCategoryDelta.worse:
        background = colors.warning.withValues(alpha: 0.14);
        foreground = colors.warning;
        break;
      case ZCategoryDelta.flat:
      case ZCategoryDelta.none:
        background = colors.surfaceRaised;
        foreground = colors.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Footer row ───────────────────────────────────────────────────────────────

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.color, required this.isNoData});

  final Color color;
  final bool isNoData;

  @override
  Widget build(BuildContext context) {
    final label = isNoData ? 'Connect a source' : 'View details';
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Icon(
          Icons.chevron_right_rounded,
          size: AppDimens.iconSm,
          color: color,
        ),
      ],
    );
  }
}
