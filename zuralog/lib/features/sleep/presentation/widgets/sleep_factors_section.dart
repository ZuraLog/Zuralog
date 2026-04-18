library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

const _factorLabels = <String, String>{
  'exercise':       'Exercise',
  'no_caffeine':    'No caffeine',
  'late_meal':      'Late meal',
  'alcohol':        'Alcohol',
  'stress':         'Stress',
  'screen_time':    'Screen time',
  'melatonin':      'Melatonin',
  'nap':            'Nap today',
  'travel':         'Travel / jet lag',
};

class SleepFactorsSection extends StatelessWidget {
  const SleepFactorsSection({super.key, required this.factors});

  final List<String> factors;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const sleepColor = AppColors.categorySleep;

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logged Factors',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceXs,
              children: factors.map((slug) {
                final label = _factorLabels[slug] ??
                    slug.replaceAll('_', ' ').split(' ').map((w) {
                      if (w.isEmpty) return w;
                      return '${w[0].toUpperCase()}${w.substring(1)}';
                    }).join(' ');

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: AppDimens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: sleepColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppDimens.shapePill),
                    border: Border.all(
                      color: sleepColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: sleepColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
