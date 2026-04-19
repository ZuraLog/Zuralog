// zuralog/lib/features/sleep/presentation/widgets/sleep_hero_card.dart
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

class SleepHeroCard extends StatelessWidget {
  const SleepHeroCard({super.key, required this.summary});

  final SleepDaySummary summary;

  @override
  Widget build(BuildContext context) {
    return ZuralogCard(
      variant: ZCardVariant.hero,
      category: AppColors.categorySleep,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: summary.hasData
            ? _DataContent(summary: summary)
            : const _EmptyContent(),
      ),
    );
  }
}

class _DataContent extends StatelessWidget {
  const _DataContent({required this.summary});
  final SleepDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Duration + quality badge on same row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              summary.durationMinutes != null
                  ? _formatDuration(summary.durationMinutes!)
                  : '\u2013',
              style: AppTextStyles.displayLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (summary.qualityLabel != null) ...[
              const SizedBox(width: AppDimens.spaceSm),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _QualityBadge(label: summary.qualityLabel!),
              ),
            ],
          ],
        ),
        // Bedtime → Wake time
        if (summary.bedtime != null || summary.wakeTime != null) ...[
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            _formatBedtimeWake(summary.bedtime, summary.wakeTime),
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        // vs 7-day average
        if (summary.avgVs7DayMinutes != null) ...[
          const SizedBox(height: AppDimens.spaceXs),
          _VsAvgRow(minutes: summary.avgVs7DayMinutes!),
        ],
        // Sleep efficiency
        if (summary.sleepEfficiencyPct != null) ...[
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            '${summary.sleepEfficiencyPct!.round()}% efficiency',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        // Source attribution chips
        if (summary.sources.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Wrap(
            spacing: AppDimens.spaceXs,
            runSpacing: AppDimens.spaceXs,
            children: summary.sources
                .map((s) => _SourceChip(source: s))
                .toList(),
          ),
        ],
      ],
    );
  }

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _formatBedtimeWake(DateTime? bedtime, DateTime? wakeTime) {
    String fmt(DateTime dt) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
    }
    if (bedtime == null) return 'Wake ${fmt(wakeTime!)}';
    if (wakeTime == null) return 'Bed ${fmt(bedtime)}';
    return '${fmt(bedtime)} \u2192 ${fmt(wakeTime)}';
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No sleep data yet',
          style: AppTextStyles.titleLarge.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          'Log your sleep or connect a wearable to see your sleep summary here.',
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Row(
          children: [
            _CtaChip(
              label: 'Log sleep',
              icon: Icons.bedtime_rounded,
              onTap: (ctx) => ctx.pushNamed(RouteNames.sleepLog),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            _CtaChip(
              label: 'Connect wearable',
              icon: Icons.watch_rounded,
              onTap: (ctx) => ctx.pushNamed(RouteNames.settingsIntegrations),
            ),
          ],
        ),
      ],
    );
  }
}

class _CtaChip extends StatelessWidget {
  const _CtaChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final void Function(BuildContext ctx) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceXs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
          border: Border.all(
            color: AppColors.categorySleep.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppDimens.iconSm, color: AppColors.categorySleep),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.categorySleep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label});
  final String label;

  static const _colors = {
    'Awful': Color(0xFFFF375F),
    'Poor': Color(0xFFFF9F0A),
    'Okay': Color(0xFFFFD60A),
    'Good': Color(0xFF30D158),
    'Great': Color(0xFF32ADE6),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[label] ?? AppColors.categorySleep;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.shapeXs),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _VsAvgRow extends StatelessWidget {
  const _VsAvgRow({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final isAbove = minutes >= 0;
    final color = isAbove ? const Color(0xFF30D158) : const Color(0xFFFF375F);
    final sign = isAbove ? '+' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isAbove ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          '$sign${_fmt(minutes.abs())} vs 7-day avg',
          style: AppTextStyles.labelSmall.copyWith(color: color),
        ),
      ],
    );
  }

  static String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});
  final SleepSource source;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    try {
      final hex = source.brandColor.replaceFirst('#', '');
      dotColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        border: Border.all(color: dotColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            source.name,
            style: AppTextStyles.labelSmall.copyWith(color: dotColor),
          ),
        ],
      ),
    );
  }
}
