/// Top-level Your-Body-Today hero card used on the Today tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/features/body/presentation/body_detail_sheet.dart';
import 'package:zuralog/features/body/presentation/muscle_state_picker_sheet.dart';
import 'package:zuralog/features/body/providers/body_now_coach_message_provider.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/check_in_provider.dart';
import 'package:zuralog/features/body/providers/pillar_metrics_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_coach_strip.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_figure_stack.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_headline.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_metrics_rail.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

String _todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class BodyNowHeroCard extends ConsumerWidget {
  const BodyNowHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bodyAsync = ref.watch(bodyStateProvider);
    final metricsAsync = ref.watch(pillarMetricsProvider);
    final coachAsync = ref.watch(bodyNowCoachMessageProvider);

    return ZuralogCard(
      variant: ZCardVariant.hero,
      padding: EdgeInsets.zero,
      onTap: () => _openDetail(context, ref),
      child: Stack(children: [
        const Positioned.fill(
          child: IgnorePointer(child: _AmbientGlow()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(),
              const SizedBox(height: AppDimens.spaceMd),
              bodyAsync.when(
                loading: () => const _HeroSkeleton(),
                error: (_, __) => const _HeroSkeleton(),
                data: (state) => _LoadedBody(
                  state: state,
                  metricsAsync: metricsAsync,
                  onChipTapped: (chip) => _onChip(context, chip),
                ),
              ),
              coachAsync.maybeWhen(
                data: (msg) {
                  if (msg == null) return const SizedBox.shrink();
                  return BodyNowCoachStrip(
                    message: msg,
                    onCtaTap: () => _onCta(context, ref, msg),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.todayBodyNowOpened,
        );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => const BodyDetailSheet(),
    );
  }

  void _onChip(BuildContext context, BodyNowChip chip) {
    context.push(
      switch (chip) {
        BodyNowChip.nutrition => '/nutrition',
        BodyNowChip.fitness => '/data',
        BodyNowChip.sleep => '/sleep',
        BodyNowChip.heart => '/heart',
      },
    );
  }

  void _onCta(BuildContext context, WidgetRef ref, CoachMessage msg) {
    ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.todayBodyNowCtaTapped,
        );
    if (msg.isCheckIn) {
      ref.read(checkInProvider.notifier).markSeen(_todayIso());
      if (msg.checkInMuscleGroup != null) {
        showMuscleStatePicker(context, msg.checkInMuscleGroup!);
      } else {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useRootNavigator: true,
          builder: (_) => const BodyDetailSheet(),
        );
      }
    } else {
      context.push(msg.ctaRoute);
    }
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.state,
    required this.metricsAsync,
    required this.onChipTapped,
  });

  final BodyState state;
  final AsyncValue<PillarMetrics> metricsAsync;
  final void Function(BodyNowChip) onChipTapped;

  @override
  Widget build(BuildContext context) {
    final metrics = metricsAsync.maybeWhen(
      data: (m) => m,
      orElse: () => PillarMetrics.empty,
    );
    return Column(children: [
      BodyNowFigureStack(state: state),
      const SizedBox(height: AppDimens.spaceSm),
      BodyNowHeadline(state: state),
      const SizedBox(height: AppDimens.spaceMd),
      BodyNowMetricsRail(metrics: metrics, onChipTapped: onChipTapped),
      const SizedBox(height: AppDimens.spaceMd),
    ]);
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.7),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      const SizedBox(width: 9),
      Text(
        'YOUR BODY TODAY',
        style: AppTextStyles.labelSmall.copyWith(
          color: colors.textSecondary,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    ]);
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.8,
          colors: [
            Color(0x1ACFE1B9),
            Color(0x00000000),
          ],
        ),
      ),
    );
  }
}
