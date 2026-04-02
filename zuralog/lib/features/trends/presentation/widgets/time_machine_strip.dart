/// Zuralog — Time Machine Strip.
///
/// A horizontal scroll section that shows weekly health summaries as compact
/// cards. Only visible to Pro users on the Trends tab.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/features/trends/presentation/widgets/time_period_card.dart';

/// Horizontal scroll strip displaying weekly [TimePeriodSummary] cards.
///
/// This widget should only be rendered when the user has a Pro subscription
/// and [periods] is not empty. The parent is responsible for that check.
class TimeMachineStrip extends StatelessWidget {
  const TimeMachineStrip({super.key, required this.periods});

  /// Weekly summaries to display — most recent first.
  final List<TimePeriodSummary> periods;

  /// Fixed height for the horizontal scroll region. Sized to fit a
  /// TimePeriodCard with score ring + 3 metric rows at default font scale.
  static const double _stripHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceLg,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: Text(
            'Time Machine',
            style: AppTextStyles.displaySmall.copyWith(
              color: colors.trendsTextPrimary,
            ),
          ),
        ),

        // Horizontal card strip
        SizedBox(
          height: _stripHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < periods.length - 1
                      ? AppDimens.spaceSm
                      : 0,
                ),
                child: TimePeriodCard(summary: periods[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
