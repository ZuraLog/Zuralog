/// A compact chip used in recovery / vitals rails.
///
/// Shows a small uppercase label, a large value, an optional unit,
/// an optional delta, and an optional child viz (sparkline / bar).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.unit,
    this.delta,
    this.deltaColor,
    this.viz,
    this.onTap,
  });

  final String label;
  final String? value;
  final String? unit;
  final String? delta;
  final Color? deltaColor;
  final Color accent;
  final Widget? viz;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
            fontSize: 9,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value ?? '—',
              style: AppTextStyles.titleLarge.copyWith(
                color: value == null ? colors.textSecondary : accent,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (delta != null) ...[
          const SizedBox(height: AppDimens.spaceXxs),
          Text(
            delta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: deltaColor ?? colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (viz != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          SizedBox(height: 16, child: viz),
        ],
      ],
    );

    return Semantics(
      button: onTap != null,
      label: '$label ${value ?? 'no data'}'
          '${unit != null ? ' $unit' : ''}'
          '${delta != null ? ', $delta' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
          child: content,
        ),
      ),
    );
  }
}
