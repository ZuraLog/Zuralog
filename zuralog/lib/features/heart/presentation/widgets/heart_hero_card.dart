library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

class HeartHeroCard extends StatelessWidget {
  const HeartHeroCard({super.key, required this.summary});

  final HeartDaySummary summary;

  @override
  Widget build(BuildContext context) {
    return ZuralogCard(
      variant: ZCardVariant.hero,
      category: AppColors.categoryHeart,
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
  final HeartDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RHR + HRV side-by-side headline row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.restingHr != null
                        ? summary.restingHr!.round().toString()
                        : '\u2013',
                    style: AppTextStyles.displayLarge
                        .copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    'bpm  Resting HR',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                  if (summary.restingHrVs7Day != null) ...[
                    const SizedBox(height: AppDimens.spaceXs),
                    _VsAvgRow(
                      delta: summary.restingHrVs7Day!,
                      unit: 'bpm',
                      lowerIsBetter: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.hrvMs != null
                        ? summary.hrvMs!.round().toString()
                        : '\u2013',
                    style: AppTextStyles.displayLarge
                        .copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    'ms  HRV',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                  if (summary.hrvVs7Day != null) ...[
                    const SizedBox(height: AppDimens.spaceXs),
                    _VsAvgRow(
                      delta: summary.hrvVs7Day!,
                      unit: 'ms',
                      lowerIsBetter: false,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // Source chips
        if (summary.sources.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Wrap(
            spacing: AppDimens.spaceXs,
            runSpacing: AppDimens.spaceXs,
            children:
                summary.sources.map((s) => _SourceChip(source: s)).toList(),
          ),
        ],
      ],
    );
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
          'No heart data yet',
          style:
              AppTextStyles.titleLarge.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          'Connect a wearable or use Apple Health / Health Connect to see '
          'your heart metrics here.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _CtaChip(
          label: 'Connect wearable',
          icon: Icons.watch_rounded,
          onTap: (ctx) => ctx.pushNamed(RouteNames.settingsIntegrations),
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
            color: AppColors.categoryHeart.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppDimens.iconSm, color: AppColors.categoryHeart),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.categoryHeart),
            ),
          ],
        ),
      ),
    );
  }
}

class _VsAvgRow extends StatelessWidget {
  const _VsAvgRow({
    required this.delta,
    required this.unit,
    required this.lowerIsBetter,
  });
  final double delta;
  final String unit;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final isGood = lowerIsBetter ? delta <= 0 : delta >= 0;
    final color =
        isGood ? const Color(0xFF30D158) : const Color(0xFFFF375F);
    final sign = delta >= 0 ? '+' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          delta >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          '$sign${delta.round()} $unit vs avg',
          style: AppTextStyles.labelSmall.copyWith(color: color),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});
  final HeartSource source;

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
