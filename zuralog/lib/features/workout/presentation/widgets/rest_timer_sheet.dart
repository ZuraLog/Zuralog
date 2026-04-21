/// Zuralog — Rest Timer Widgets.
///
/// Two widgets driven by [restTimerProvider]:
/// - [RestTimerOverlay]: the full sheet shown at the bottom when a rest
///   timer is active and expanded. Only present in the tree when visible.
/// - [RestTimerMiniBanner]: compact tap-to-expand pill. Lives inline in
///   the screen's Column, between the exercise list and the bottom bar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

// ── Full Sheet Overlay ────────────────────────────────────────────────────────

/// Bottom sheet shown while the rest timer is running and expanded.
///
/// Renders nothing when the timer is hidden or minimized — that keeps the
/// layout simple and avoids layout-timing bugs from manual slide animations.
class RestTimerOverlay extends ConsumerWidget {
  const RestTimerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final show = timer.isVisible && !timer.isMinimized;
    if (!show) return const SizedBox.shrink();
    return _FullSheetBody(timer: timer);
  }
}

class _FullSheetBody extends ConsumerWidget {
  const _FullSheetBody({required this.timer});

  final RestTimerState timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);

    final remaining = timer.remainingSeconds ?? 0;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final urgent = remaining <= 10 && remaining > 0;
    final expired = timer.hasExpired;
    final timeColor = expired
        ? colors.primary
        : urgent
            ? colors.error
            : colors.textPrimary;

    final progress = timer.totalSeconds > 0
        ? (remaining / timer.totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: colors.surfaceOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.shapeXl),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceLg,
            AppDimens.spaceSm,
            AppDimens.spaceLg,
            AppDimens.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — tap or swipe down to minimize.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(restTimerProvider.notifier).minimize();
                },
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 200) {
                    HapticFeedback.selectionClick();
                    ref.read(restTimerProvider.notifier).minimize();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceSm,
                  ),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                expired ? 'Time to work!' : 'Rest',
                style: AppTextStyles.titleMedium
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                expired ? '00:00' : timeStr,
                style: AppTextStyles.displaySmall.copyWith(
                  color: timeColor,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor:
                      colors.textSecondary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    urgent ? colors.error : colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(restTimerProvider.notifier).addTime(30);
                    },
                    child: Text(
                      '+30s',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: colors.primary),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  FilledButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(restTimerProvider.notifier).skip();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                    ),
                    child: Text(
                      'Skip',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: colors.textOnSage),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini Banner ───────────────────────────────────────────────────────────────

/// Compact pill shown between the exercise list and the bottom action bar
/// when the full sheet is minimized. Tap to expand.
class RestTimerMiniBanner extends ConsumerWidget {
  const RestTimerMiniBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    if (!timer.isVisible || !timer.isMinimized) return const SizedBox.shrink();
    return _MiniBannerBody(timer: timer);
  }
}

class _MiniBannerBody extends ConsumerWidget {
  const _MiniBannerBody({required this.timer});

  final RestTimerState timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final remaining = timer.remainingSeconds ?? 0;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final expired = timer.hasExpired;
    final urgent = remaining <= 10 && !expired;

    final bgColor = expired
        ? colors.primary.withValues(alpha: 0.15)
        : urgent
            ? colors.error.withValues(alpha: 0.12)
            : colors.surfaceOverlay;
    final borderColor = expired
        ? colors.primary.withValues(alpha: 0.40)
        : urgent
            ? colors.error.withValues(alpha: 0.35)
            : colors.textSecondary.withValues(alpha: 0.18);
    final textColor = expired ? colors.primary : colors.textPrimary;
    final iconColor = expired ? colors.primary : colors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceXs,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(restTimerProvider.notifier).expand();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            child: Row(
              children: [
                Icon(
                  expired ? Icons.fitness_center_rounded : Icons.timer_outlined,
                  size: AppDimens.iconMd,
                  color: iconColor,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    expired
                        ? 'Rest over — start your set!'
                        : 'Rest  $timeStr',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: textColor,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_less_rounded,
                  size: AppDimens.iconMd,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
