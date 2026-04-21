import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuralog/core/theme/theme.dart';

/// A modal bottom sheet that counts down from a given number of seconds.
///
/// Shows a large mm:ss countdown, a "+30s" button to add time, and a "Skip"
/// button to dismiss early. Vibrates and auto-dismisses when the countdown
/// reaches zero.
///
/// Usage:
/// ```dart
/// await RestTimerSheet.show(context, seconds: 90);
/// ```
class RestTimerSheet extends StatefulWidget {
  const RestTimerSheet({super.key, required this.initialSeconds});

  final int initialSeconds;

  static Future<void> show(BuildContext context, {required int seconds}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      builder: (_) => RestTimerSheet(initialSeconds: seconds),
    );
  }

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        _timer?.cancel();
        HapticFeedback.heavyImpact();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
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
            'Rest',
            style: AppTextStyles.titleMedium
                .copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            timeStr,
            style: AppTextStyles.displaySmall.copyWith(
              color: colors.textPrimary,
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
                  setState(() => _remaining += 30);
                  if (_timer == null || !_timer!.isActive) {
                    _startTimer();
                  }
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
                  Navigator.of(context).pop();
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
    );
  }
}
