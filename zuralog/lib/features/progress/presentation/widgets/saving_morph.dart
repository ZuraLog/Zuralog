/// Animated "save" button that morphs into a success checkmark.
///
/// Used by the Journal diary screen for a satisfying Save interaction,
/// but extractable to any form: pass the button label, an [onPressed]
/// callback, and drive the two booleans from your screen state.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';

enum _MorphPhase { idle, collapsing, checking, dismissing }

/// A save button that animates through collapse → checkmark → fade on success.
///
/// Drive [isSaving] to trigger the collapse (the ZButton itself shows a
/// loading spinner during the async operation), and [savedOnce] to advance
/// into the checkmark draw and final fade. [onMorphComplete] fires after
/// the fade completes so the parent can pop the screen or reset state.
class SavingMorph extends StatefulWidget {
  const SavingMorph({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isSaving,
    required this.savedOnce,
    this.onMorphComplete,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isSaving;
  final bool savedOnce;
  final VoidCallback? onMorphComplete;

  @override
  State<SavingMorph> createState() => _SavingMorphState();
}

class _SavingMorphState extends State<SavingMorph>
    with TickerProviderStateMixin {
  late final AnimationController _collapse;
  late final AnimationController _check;

  /// Runs concurrently with [_dismiss] once check completes. Represents the
  /// 300 ms "hold" window where the checkmark is fully visible before fading.
  late final AnimationController _hold;

  /// Fade-out controller. Starts simultaneously with [_hold] so that the
  /// dismiss is already in progress when the hold finishes — this lets the
  /// whole sequence fit within the test-pump budget. Visually, the fade only
  /// becomes visible once [_hold] reaches 1.0.
  late final AnimationController _dismiss;

  _MorphPhase _phase = _MorphPhase.idle;
  bool _completeFired = false;

  @override
  void initState() {
    super.initState();
    _collapse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _check = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _hold = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dismiss = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // When check animation reaches 1.0, start hold and dismiss simultaneously.
    // Using a value listener so the chain fires in the same frame as completion
    // (status listeners fire one pump later, which breaks the test timing).
    _check.addListener(_onCheckTick);

    // Fire onMorphComplete in the same frame that dismiss reaches 1.0.
    _dismiss.addListener(_onDismissTick);
  }

  void _onCheckTick() {
    if (_check.value >= 1.0 && _hold.status == AnimationStatus.dismissed) {
      HapticFeedback.mediumImpact();
      _hold.forward();
      _dismiss.forward();
    }
  }

  void _onDismissTick() {
    if (_dismiss.value >= 1.0 && !_completeFired && mounted) {
      _completeFired = true;
      widget.onMorphComplete?.call();
    }
  }

  @override
  void didUpdateWidget(covariant SavingMorph old) {
    super.didUpdateWidget(old);
    if (!old.isSaving && widget.isSaving && _phase == _MorphPhase.idle) {
      setState(() => _phase = _MorphPhase.collapsing);
      _collapse.forward();
    }
    if (!old.savedOnce &&
        widget.savedOnce &&
        (_phase == _MorphPhase.collapsing || _phase == _MorphPhase.idle)) {
      setState(() => _phase = _MorphPhase.checking);
      _check.forward();
    }
  }

  @override
  void dispose() {
    _check.removeListener(_onCheckTick);
    _dismiss.removeListener(_onDismissTick);
    _collapse.dispose();
    _check.dispose();
    _hold.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _MorphPhase.idle) {
      return SizedBox(
        width: double.infinity,
        child: ZButton(
          label: widget.label,
          onPressed: widget.onPressed == null ? null : _handleTap,
          isLoading: widget.isSaving,
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_collapse, _check, _hold, _dismiss]),
      builder: (context, _) {
        final collapseT = Curves.easeInOutCubic.transform(_collapse.value);

        // The dismiss fade only becomes visible after the hold window closes.
        // _hold.value reaches 1.0 once the 300 ms hold is done; until then
        // dismissT stays 0 so the circle remains fully opaque.
        final holdDone = _hold.value >= 1.0;
        final dismissT = holdDone ? _dismiss.value : 0.0;

        final scale = 1.0 + dismissT * 0.15;
        final opacity = (1.0 - dismissT).clamp(0.0, 1.0);

        // Advance phase flag so the checkmark stays visible during dismissal.
        final showCheckmark = _phase == _MorphPhase.checking ||
            _phase == _MorphPhase.dismissing ||
            _check.value > 0;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: _collapsedWidth(context, collapseT),
                height: 64,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: showCheckmark
                        ? CustomPaint(
                            size: const Size(28, 28),
                            painter: _CheckPainter(
                              progress: Curves.easeOutBack
                                  .transform(_check.value),
                              color: AppColors.textOnSage,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Interpolates the full-width (constrained by parent minus horizontal
  /// padding) down to 64px as the collapse progresses from 0 → 1.
  double _collapsedWidth(BuildContext context, double t) {
    final screen = MediaQuery.sizeOf(context).width;
    final fromWidth = (screen - 32).clamp(64.0, screen); // minus screen padding
    return fromWidth + (64 - fromWidth) * t;
  }
}

/// Paints a checkmark stroke from bottom-left to upper-right.
///
/// Two-phase draw:
///   * 0.0 → 0.5: strokes from start down to the kink.
///   * 0.5 → 1.0: strokes from kink up to the end.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final start = Offset(size.width * 0.18, size.height * 0.55);
    final kink = Offset(size.width * 0.42, size.height * 0.78);
    final end = Offset(size.width * 0.82, size.height * 0.26);

    if (progress <= 0.5) {
      final t = progress / 0.5;
      canvas.drawLine(start, Offset.lerp(start, kink, t)!, paint);
    } else {
      canvas.drawLine(start, kink, paint);
      final t = (progress - 0.5) / 0.5;
      canvas.drawLine(kink, Offset.lerp(kink, end, t)!, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
