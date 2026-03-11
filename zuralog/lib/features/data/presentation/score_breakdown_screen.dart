/// Score Breakdown Screen — pushed from the Health Score hero on the Data tab.
///
/// Shows the composite health score ring and each input's contribution as
/// a labelled horizontal bar with sub-score and weight percentage.
///
/// Gracefully handles the case where the backend does not yet return input
/// breakdown data (displays an informational empty state).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';

// ── ScoreBreakdownScreen ──────────────────────────────────────────────────────

/// Displays the health score and each input's weighted contribution.
class ScoreBreakdownScreen extends ConsumerWidget {
  /// Creates the [ScoreBreakdownScreen].
  const ScoreBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final scoreAsync = ref.watch(healthScoreProvider);

    return ZuralogScaffold(
      appBar: AppBar(
        title: Text('Score Breakdown', style: AppTextStyles.displaySmall),
      ),
      body: scoreAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 40, color: AppColors.textTertiary),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Could not load score',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        data: (score) => _ScoreBreakdownBody(score: score),
      ),
    );
  }
}

// ── _ScoreBreakdownBody ───────────────────────────────────────────────────────

class _ScoreBreakdownBody extends StatelessWidget {
  const _ScoreBreakdownBody({required this.score});
  final HealthScoreData score;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      children: [
        // ── Score ring + subtitle ─────────────────────────────────────────
        Center(
          child: Column(
            children: [
              HealthScoreWidget.hero(score: score.score),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Your composite health score',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimens.spaceLg),

        // ── Section title ─────────────────────────────────────────────────
        Text('Score Inputs', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Each input is normalized to 0–100 based on your 30-day history. '
          'Missing inputs are excluded and weights redistribute proportionally.',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Input breakdown list or empty state ───────────────────────────
        if (score.inputs.isEmpty)
          const _EmptyInputsCard()
        else
          ...score.inputs.map(
            (input) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
              child: _InputRow(input: input),
            ),
          ),

        if (score.commentary != null && score.commentary!.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _CommentaryCard(commentary: score.commentary!),
        ],
      ],
    );
  }
}

// ── _InputRow ─────────────────────────────────────────────────────────────────

class _InputRow extends StatelessWidget {
  const _InputRow({required this.input});
  final HealthScoreInput input;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final barColor = input.hasData
        ? HealthScoreWidget.colorForScore(input.subScore)
        : AppColors.textTertiary;
    final barFraction =
        input.hasData && input.subScore != null ? input.subScore! / 100.0 : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  input.label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Weight badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(input.weight * 100).round()}%',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              // Sub-score value
              Text(
                input.hasData && input.subScore != null
                    ? '${input.subScore}'
                    : '—',
                style: AppTextStyles.titleMedium.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Progress bar ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barFraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colors.border.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),

          // ── Description ───────────────────────────────────────────────────
          if (!input.hasData) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'No data connected for this input',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ] else if (input.description != null &&
              input.description!.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              // Clamp to prevent abnormally long description strings from the API.
              input.description!.length > 120
                  ? '${input.description!.substring(0, 120)}…'
                  : input.description!,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── _EmptyInputsCard ──────────────────────────────────────────────────────────

class _EmptyInputsCard extends StatelessWidget {
  const _EmptyInputsCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text('Breakdown coming soon', style: AppTextStyles.bodyLarge),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Score input breakdown will be available once more of your health '
            'data builds up. Keep your integrations connected.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CommentaryCard ───────────────────────────────────────────────────────────

class _CommentaryCard extends StatelessWidget {
  const _CommentaryCard({required this.commentary});
  final String commentary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: colors.primary),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                color: colors.cardBackground,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                       child: Text(
                         commentary,
                         style: AppTextStyles.bodySmall.copyWith(
                           color: Theme.of(context).colorScheme.onSurface,
                         ),
                       ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
