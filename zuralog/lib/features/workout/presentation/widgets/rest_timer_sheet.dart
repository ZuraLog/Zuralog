/// Zuralog — Rest Timer Widgets.
///
/// Two widgets driven by [restTimerProvider]:
/// - [RestTimerOverlay]: the full sheet that slides up from the bottom
///   when a timer is active and expanded. Always present in the widget
///   tree; slid off-screen via [AnimatedSlide] when hidden so animations
///   are consistent and nothing leaks into the workout UI behind it.
/// - [RestTimerMiniBanner]: compact tap-to-expand pill. Lives inline in
///   the screen's Column, between the exercise list and the bottom bar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

// ── Full Sheet Overlay ────────────────────────────────────────────────────────

/// Floating bottom sheet that counts down between sets.
///
/// Always rendered; uses [AnimatedSlide] to move off-screen when the
/// timer isn't visible or has been minimized. [IgnorePointer] prevents
/// hit-testing from leaking to the UI behind it when hidden.
class RestTimerOverlay extends ConsumerWidget {
  const RestTimerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final show = timer.isVisible && !timer.isMinimized;

    return IgnorePointer(
      ignoring: !show,
      child: AnimatedSlide(
        offset: show ? Offset.zero : const Offset(0, 1.2),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: const _FullSheetBody(),
      ),
    );
  }
}

class _FullSheetBody extends ConsumerWidget {
  const _FullSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
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
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceOverlay,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.shapeXl),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
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
                  // Drag handle — its own gesture detector so other areas
                  // of the sheet don't accidentally trigger minimize.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) > 200) {
                        HapticFeedback.selectionClick();
                        ref.read(restTimerProvider.notifier).minimize();
                      }
                    },
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(restTimerProvider.notifier).minimize();
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

    // Animated show/hide using AnimatedSize so inserting/removing
    // the banner doesn't jank the Column above/below it.
    final show = timer.isVisible && timer.isMinimized;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: show ? _MiniBannerBody(timer: timer) : const SizedBox.shrink(),
    );
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
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(restTimerProvider.notifier).expand();
          },
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppDimens.shapeMd),
              border: Border.all(color: borderColor),
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
