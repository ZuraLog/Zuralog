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
/// Always mounted so the full sheet can fade + scale in/out in sync with
/// the inline mini pill's `AnimatedSize` collapse/expand. An [IgnorePointer]
/// prevents the invisible overlay from eating taps when hidden.
class RestTimerOverlay extends ConsumerWidget {
  const RestTimerOverlay({super.key});

  /// Matches the inline morph duration so the pill and sheet feel like a
  /// single morphing element.
  static const Duration _duration = Duration(milliseconds: 320);

  /// Material 3 "emphasized decelerate" — a more expressive ease-out than
  /// the stock [Curves.easeOutCubic], used here to match the inline pill.
  static const Curve _curve = Cubic(0.05, 0.7, 0.1, 1.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final show = timer.isVisible && !timer.isMinimized;
    return IgnorePointer(
      ignoring: !show,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: show ? 1 : 0),
        duration: _duration,
        curve: _curve,
        builder: (context, t, child) {
          // Fade from 0 → 1 and scale from 0.98 → 1.0 on enter; reverse on exit.
          final scale = 0.98 + (0.02 * t);
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        // Keep the body built so its internal state survives minimize/expand.
        child: _FullSheetBody(timer: timer),
      ),
    );
  }
}

class _FullSheetBody extends ConsumerWidget {
  const _FullSheetBody({required this.timer});

  final RestTimerState timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);

    final remaining = timer.remainingSecondsInt;
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

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) {
          HapticFeedback.selectionClick();
          ref.read(restTimerProvider.notifier).minimize();
        }
      },
      child: Material(
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
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(restTimerProvider.notifier).addTime(30);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: colors.primary),
                      ),
                      child: Text(
                        '+30s',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: colors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(restTimerProvider.notifier).skip();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        'Skip',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: colors.textOnSage),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
    final remaining = timer.remainingSecondsInt;
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
      // Zero bottom margin so the pill hugs the bottom action bar directly.
      // The sibling `_BottomActions` widget handles safe-area bottom padding.
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceXs,
        AppDimens.spaceMd,
        0,
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
            // Compact vertical padding — keeps the pill around 40–44 pt tall.
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceXs,
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
