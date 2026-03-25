/// Zuralog Design System — Topographic Card Component.
///
/// A card that applies the brand topographic contour-line pattern as a subtle
/// surface overlay using [BlendMode.overlay]. Unlike [PatternFill], which uses
/// [BlendMode.srcIn] to fill text/shapes, this widget renders the pattern as a
/// background texture on top of the card surface.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';

/// A card widget with a brand topographic pattern as a surface overlay.
///
/// Asynchronously loads the brand pattern PNG asset and applies it with
/// [BlendMode.overlay] so the contour lines appear as a subtle texture on the
/// card background. Falls back gracefully (no pattern) if the asset is not yet
/// loaded or unavailable.
///
/// Layout structure (top to bottom):
/// - A 3px accent strip in [accentColor].
/// - The [child] content padded by [padding], stacked above the pattern layer.
///
/// Example usage:
/// ```dart
/// ZTopographicCard(
///   accentColor: AppColors.trendsSage,
///   child: Text('Trends hero content'),
/// )
/// ```
class ZTopographicCard extends StatefulWidget {
  /// The content widget rendered inside the card.
  final Widget child;

  /// The color of the 3px accent strip at the top of the card.
  ///
  /// Defaults to [AppColors.trendsSage].
  final Color? accentColor;

  /// Inner padding around [child].
  ///
  /// Defaults to [AppDimens.spaceMd] (16px) on all sides.
  final EdgeInsetsGeometry? padding;

  /// Creates a [ZTopographicCard].
  const ZTopographicCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding,
  });

  @override
  State<ZTopographicCard> createState() => _ZTopographicCardState();
}

class _ZTopographicCardState extends State<ZTopographicCard> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadPattern();
  }

  @override
  void reassemble() {
    super.reassemble();
    _image?.dispose();
    _image = null;
    _loadPattern();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadPattern() async {
    try {
      final data = await rootBundle.load('assets/images/brand_pattern.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _image = frame.image);
    } catch (_) {
      // Asset unavailable — no overlay is shown, card renders normally.
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppColors.trendsSage;
    final padding = widget.padding ?? const EdgeInsets.all(AppDimens.spaceMd);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final borderRadius = BorderRadius.circular(AppDimens.radiusCard);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.trendsSurface,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.trendsBorderStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top accent strip ─────────────────────────────────────────
            Container(height: 3, color: accentColor),

            // ── Card body: pattern overlay + child ───────────────────────
            Flexible(
              child: Stack(
                children: [
                  // Layer 1 — brand pattern overlay (non-interactive)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ShaderMask(
                        blendMode: BlendMode.overlay,
                        shaderCallback: (bounds) {
                          if (_image != null) {
                            return ImageShader(
                              _image!,
                              TileMode.repeated,
                              TileMode.repeated,
                              (Matrix4.identity()
                                    ..scaleByDouble(
                                      1.0 / dpr,
                                      1.0 / dpr,
                                      1.0,
                                      1.0,
                                    ))
                                  .storage,
                            );
                          }
                          // No image yet — fully transparent shader, no overlay shown.
                          return const LinearGradient(
                            colors: [Colors.transparent, Colors.transparent],
                          ).createShader(bounds);
                        },
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                  ),

                  // Layer 2 — content (above the pattern)
                  Padding(padding: padding, child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
