/// Welcoming zero-data state for the Your-Body-Now hero.
///
/// Uses the shipping body_map.svg tinted to a neutral surface colour
/// (so the card still feels like the same product) plus a friendly call
/// to connect a wearable.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/muscle_highlight_diagram.dart';

class BodyNowZeroState extends StatelessWidget {
  const BodyNowZeroState({super.key, required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(children: [
        const SizedBox(
          height: 240,
          child: Row(children: [
            Expanded(
              child: MuscleHighlightDiagram.zones(
                zones: {},
                onlyFront: true,
                strokeless: true,
              ),
            ),
            Expanded(
              child: MuscleHighlightDiagram.zones(
                zones: {},
                onlyBack: true,
                strokeless: true,
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          "Let's meet your body.",
          textAlign: TextAlign.center,
          style: AppTextStyles.displaySmall.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          'Connect a wearable or log your first workout and I can start '
          'reading how you recover.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        FilledButton(
          onPressed: onConnect,
          child: const Text('Connect'),
        ),
      ]),
    );
  }
}
