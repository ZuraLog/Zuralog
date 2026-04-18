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

  /// Fade-out controller. Runs after the 300 ms hold completes for a smooth 250 ms
  /// fade + scale out.
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
    _dismiss = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Sequential chain: check completes → 300 ms hold → dismiss fades out.
    _check.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _onCheckComplete();
    });
  }

  Future<void> _onCheckComplete() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _phase = _MorphPhase.dismissing);
    await _dismiss.forward();
    if (!mounted) return;
    if (!_completeFired) {
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
    _collapse.dispose();
    _check.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _MorphPhase.idle) {
      return SizedBox(
        width: double.infinity,
        child: ZButton(
          label: widget.label,
          onPressed: widget.onPressed,
          isLoading: widget.isSaving,
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_collapse, _check, _dismiss]),
      builder: (context, _) {
        final collapseT = Curves.easeInOutCubic.transform(_collapse.value);

        // The dismiss fade only becomes visible once the dismissing phase starts.
        // Until then, _phase stays checking and _dismiss hasn't been forwarded.
        final dismissT = _phase == _MorphPhase.dismissing ? _dismiss.value : 0.0;

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
                height: 52,
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
    final fromWidth = (screen - 32).clamp(52.0, screen); // minus screen padding
    return fromWidth + (52 - fromWidth) * t;
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
