/// Zuralog Design System — Log Success Overlay.
///
/// A full-screen celebration overlay shown after any successful log action.
/// Renders the branded checkmark Lottie animation over the brand topographic
/// pattern on a dark backdrop.
library;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Full-screen log-success celebration overlay.
///
/// Inserts above the root navigator so it appears above bottom sheets, dialogs,
/// and every other route. Auto-removes itself when the animation finishes.
///
/// ## Usage
/// ```dart
/// ZLogSuccessOverlay.show(context);
/// ```
class ZLogSuccessOverlay extends StatefulWidget {
  const ZLogSuccessOverlay({super.key, this.onComplete});

  /// Called after the animation fully fades out.
  final VoidCallback? onComplete;

  /// Shows the overlay above everything and auto-dismisses after the animation.
  static void show(BuildContext context, {VoidCallback? onComplete}) {
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => ZLogSuccessOverlay(
        onComplete: () {
          entry.remove();
          onComplete?.call();
        },
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<ZLogSuccessOverlay> createState() => _ZLogSuccessOverlayState();
}

class _ZLogSuccessOverlayState extends State<ZLogSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;
  bool _fadingOut = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _lottieController.duration = composition.duration;
    _lottieController.forward().whenComplete(_startDismiss);
  }

  void _startDismiss() {
    if (!mounted) return;
    setState(() => _fadingOut = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _fadingOut ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 350),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark backdrop
            Container(color: const Color(0xD9000000)),
            // Brand topographic pattern drifting gently over the backdrop
            const ZPatternOverlay(
              variant: ZPatternVariant.sage,
              opacity: 0.12,
              animate: true,
            ),
            // Checkmark animation
            Center(
              child: Lottie.asset(
                'assets/animations/checkmark.json',
                controller: _lottieController,
                width: 220,
                height: 220,
                onLoaded: _onLoaded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
