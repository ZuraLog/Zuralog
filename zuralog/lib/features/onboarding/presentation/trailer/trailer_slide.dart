/// Zuralog Onboarding — Single Trailer Slide View.
///
/// Renders one photo filling the top 62% of the screen with a slow
/// Ken Burns zoom (1.0 → 1.04 over 8s), a centered headline that
/// fades up 8px after the photo settles, and a single drifting
/// sage contour accent at the photo/canvas boundary.
///
/// The slide view does not own pagination, auto-advance, or the Get
/// Started button — those belong to its parent `TrailerScreen`.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/onboarding/presentation/trailer/trailer_data.dart';
import 'package:zuralog/shared/widgets/pattern/z_contour_accent.dart';

class TrailerSlideView extends StatefulWidget {
  const TrailerSlideView({
    super.key,
    required this.slide,
    this.animate = true,
  });

  final TrailerSlide slide;

  /// When false, the zoom + fade settle instantly. Reduced-motion callers
  /// and test harnesses pass false.
  final bool animate;

  @override
  State<TrailerSlideView> createState() => _TrailerSlideViewState();
}

class _TrailerSlideViewState extends State<TrailerSlideView>
    with TickerProviderStateMixin {
  // Photo occupies the top 62% of the screen — the other 38% is canvas
  // holding the headline's runway, the contour accent, page dots, and CTA.
  static const double _photoHeightFraction = 0.62;

  // Ken Burns zoom: 1.0 → 1.04 over 8 seconds. Barely perceptible, but the
  // frame never feels static.
  static const double _zoomFrom = 1.0;
  static const double _zoomTo = 1.04;
  static const Duration _zoomDuration = Duration(seconds: 8);

  // Headline fade: starts 200ms after the photo settles so the two events
  // don't land on the same frame (that's the amateur move).
  static const Duration _headlineFadeDuration = Duration(milliseconds: 400);
  static const Duration _headlineFadeDelay = Duration(milliseconds: 200);

  // Offset the headline fades in from (8px up).
  static const double _headlineSlideOffsetPx = 8.0;

  // Top scrim that darkens the upper edge so logos / status bar icons stay
  // legible against bright photos.
  static const double _topScrimHeight = 110.0;
  static const double _topScrimAlpha = 0.55;

  // Bottom fade from photo to canvas — occupies the lower quarter of the
  // photo region so there is no hard seam.
  static const double _bottomFadeStartFraction = 0.75;
  static const double _bottomFadeHeightFraction = 0.25;

  // Contour accent sits centered on the seam — half above the photo edge,
  // half below, with a total band height of 90px.
  static const double _contourBandHeight = 90.0;
  static const double _contourBandOffsetFromSeam = 45.0;

  // Headline vertical anchor — lower third of the photo, leaving room
  // below for the contour to breathe.
  static const double _headlineTopFraction = 0.55;

  // Shadow under the headline text so it stays readable on busy photos.
  static const double _headlineShadowAlpha = 0.54;
  static const double _headlineShadowBlur = 8.0;

  late final AnimationController _zoomCtrl;
  late final AnimationController _headlineCtrl;

  @override
  void initState() {
    super.initState();
    _zoomCtrl = AnimationController(vsync: this, duration: _zoomDuration);
    _headlineCtrl =
        AnimationController(vsync: this, duration: _headlineFadeDuration);
    if (widget.animate) {
      _zoomCtrl.forward();
      Future.delayed(_headlineFadeDelay, () {
        if (mounted) _headlineCtrl.forward();
      });
    } else {
      _zoomCtrl.value = 1.0;
      _headlineCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    _headlineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.sizeOf(context).height;
    final photoHeight = mediaHeight * _photoHeightFraction;
    final canvas = AppColorsOf(context).canvas;
    // Intentionally white on photo, not a theme token — the headline sits
    // over imagery, not the canvas, so it must read the same in both themes.
    const textPrimary = Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Canvas fills the screen so the bottom 38% is pure canvas.
        ColoredBox(color: canvas),

        // Photo — top 62% with the slow Ken Burns zoom.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: photoHeight,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _zoomCtrl,
              builder: (context, child) {
                final scale =
                    _zoomFrom + (_zoomCtrl.value * (_zoomTo - _zoomFrom));
                return Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: Image.asset(widget.slide.imageAsset, fit: BoxFit.cover),
            ),
          ),
        ),

        // Top scrim — darkens for logo legibility.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _topScrimHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: _topScrimAlpha),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom fade — photo → canvas (no hard seam).
        Positioned(
          top: photoHeight * _bottomFadeStartFraction,
          left: 0,
          right: 0,
          height: photoHeight * _bottomFadeHeightFraction,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, canvas],
                ),
              ),
            ),
          ),
        ),

        // Contour accent — sits at the seam between photo and canvas.
        Positioned(
          top: photoHeight - _contourBandOffsetFromSeam,
          left: 0,
          right: 0,
          height: _contourBandHeight,
          child: IgnorePointer(
            child: ClipRect(
              child: ZContourAccent(animate: widget.animate),
            ),
          ),
        ),

        // Headline — lower third of photo, fades up 8px.
        Positioned(
          left: AppDimens.spaceLg,
          right: AppDimens.spaceLg,
          top: photoHeight * _headlineTopFraction,
          child: AnimatedBuilder(
            animation: _headlineCtrl,
            builder: (context, child) {
              return Opacity(
                opacity: _headlineCtrl.value,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    (1.0 - _headlineCtrl.value) * _headlineSlideOffsetPx,
                  ),
                  child: child,
                ),
              );
            },
            child: Text(
              widget.slide.headline,
              textAlign: TextAlign.center,
              style: AppTextStyles.displayMedium.copyWith(
                color: textPrimary,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: _headlineShadowAlpha),
                    blurRadius: _headlineShadowBlur,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
