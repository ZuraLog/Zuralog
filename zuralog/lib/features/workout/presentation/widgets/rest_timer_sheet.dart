/// Zuralog — Rest Timer Widgets.
///
/// Two widgets driven by [restTimerProvider]:
/// - [RestTimerFullSheet]: large bottom-sheet overlay, drag-to-minimize.
/// - [RestTimerMiniBanner]: compact pill shown when minimized, tap to expand.
///
/// Both are rendered inside a Stack in WorkoutSessionScreen — never pushed
/// onto the navigation stack or shown via showBottomSheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

// ── Full Sheet ────────────────────────────────────────────────────────────────

/// Large bottom overlay that counts down.
/// Drag down (or tap Skip) to minimize. Timer continues in mini banner.
class RestTimerFullSheet extends ConsumerStatefulWidget {
  const RestTimerFullSheet({super.key});

  @override
  ConsumerState<RestTimerFullSheet> createState() => _RestTimerFullSheetState();
}

class _RestTimerFullSheetState extends ConsumerState<RestTimerFullSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(restTimerProvider);
    final colors = AppColorsOf(context);

    if (!timer.isVisible || timer.isMinimized) return const SizedBox.shrink();

    final remaining = timer.remainingSeconds ?? 0;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Urgency color: red tint when ≤10 s left.
    final urgent = remaining <= 10 && remaining > 0;
    final expired = timer.hasExpired;
    final timeColor = expired
        ? colors.primary
        : urgent
            ? colors.error
            : colors.textPrimary;

    // Progress 0→1 over the full duration.
    final progress = timer.totalSeconds > 0
        ? (remaining / timer.totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return SlideTransition(
      position: _slideAnim,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          // Drag down fast → minimize.
          if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
            HapticFeedback.selectionClick();
            ref.read(restTimerProvider.notifier).minimize();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceOverlay,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.shapeXl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            12,
            AppDimens.spaceMd,
            AppDimens.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                expired ? 'Time to work!' : 'Rest',
                style: AppTextStyles.titleMedium
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              // Linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colors.textSecondary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    urgent ? colors.error : colors.primary,
                  ),
                ),
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
              const SizedBox(height: AppDimens.spaceSm),
              // Minimize hint
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(restTimerProvider.notifier).minimize();
                },
                child: Text(
                  'Minimize',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini Banner ───────────────────────────────────────────────────────────────

/// Compact pill shown above the bottom actions when the full sheet is minimized.
/// Tap to expand back to the full sheet.
class RestTimerMiniBanner extends ConsumerWidget {
  const RestTimerMiniBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final colors = AppColorsOf(context);

    if (!timer.isVisible || !timer.isMinimized) return const SizedBox.shrink();

    final remaining = timer.remainingSeconds ?? 0;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final expired = timer.hasExpired;
    final urgent = remaining <= 10 && !expired;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(restTimerProvider.notifier).expand();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: expired
              ? colors.primary.withValues(alpha: 0.15)
              : urgent
                  ? colors.error.withValues(alpha: 0.12)
                  : colors.surfaceOverlay,
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          border: Border.all(
            color: expired
                ? colors.primary.withValues(alpha: 0.40)
                : urgent
                    ? colors.error.withValues(alpha: 0.35)
                    : colors.textSecondary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              expired ? Icons.fitness_center_rounded : Icons.timer_outlined,
              size: AppDimens.iconMd,
              color: expired ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              expired ? 'Rest over — start your set!' : 'Rest  $timeStr',
              style: AppTextStyles.labelLarge.copyWith(
                color: expired ? colors.primary : colors.textPrimary,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Icon(
              Icons.expand_less_rounded,
              size: AppDimens.iconMd,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
