/// Zuralog Design System — Pattern Overlay Component.
///
/// The single source of truth for applying the brand topographic contour-line
/// pattern to any surface. Replaces all previous inline pattern implementations.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// Which pre-colored pattern variant to use.
///
/// Each maps to a PNG in `assets/brand/pattern/`.
enum ZPatternVariant {
  original('Original.PNG'),
  sage('Sage.PNG'),
  crimson('Crimson.PNG'),
  green('Green.PNG'),
  periwinkle('Periwinkle.PNG'),
  rose('Rose.PNG'),
  amber('Amber.PNG'),
  skyBlue('Sky Blue.PNG'),
  teal('Teal.PNG'),
  purple('Purple.PNG'),
  yellow('Yellow.PNG'),
  mint('Mint.PNG');

  const ZPatternVariant(this.filename);
  final String filename;
  String get assetPath => 'assets/brand/pattern/$filename';
}

/// Returns the correct pattern variant for a health category color.
ZPatternVariant patternForCategory(Color category) {
  if (category == AppColors.categoryActivity) return ZPatternVariant.green;
  if (category == AppColors.categorySleep) return ZPatternVariant.periwinkle;
  if (category == AppColors.categoryHeart) return ZPatternVariant.rose;
  if (category == AppColors.categoryNutrition) return ZPatternVariant.amber;
  if (category == AppColors.categoryBody) return ZPatternVariant.skyBlue;
  if (category == AppColors.categoryVitals) return ZPatternVariant.teal;
  if (category == AppColors.categoryWellness) return ZPatternVariant.purple;
  if (category == AppColors.categoryCycle) return ZPatternVariant.rose;
  if (category == AppColors.categoryMobility) return ZPatternVariant.yellow;
  if (category == AppColors.categoryEnvironment) return ZPatternVariant.teal;
  return ZPatternVariant.original;
}

/// Applies the brand topographic contour-line pattern over its [child].
///
/// This is a decorative overlay — it sits on top of the child content and is
/// marked non-interactive ([IgnorePointer]) and non-accessible
/// ([ExcludeSemantics]).
///
/// ## Blend mode rules (from the brand bible)
///
/// - **Light/colored surfaces** (Sage buttons, destructive buttons):
///   [BlendMode.colorBurn] — etches dark contour lines into the surface.
/// - **Dark surfaces** (hero cards, feature cards, avatars):
///   [BlendMode.screen] — lightens the pattern onto the dark canvas.
///
/// ## Usage
///
/// ```dart
/// Stack(
///   children: [
///     // Your card background
///     Container(color: AppColors.surface),
///     // Pattern layer
///     ZPatternOverlay(
///       variant: ZPatternVariant.original,
///       opacity: 0.07,
///       blendMode: BlendMode.screen,
///     ),
///     // Your content
///     Padding(padding: ..., child: ...),
///   ],
/// )
/// ```
class ZPatternOverlay extends StatefulWidget {
  const ZPatternOverlay({
    super.key,
    this.variant = ZPatternVariant.original,
    this.opacity = 0.07,
    this.blendMode = BlendMode.screen,
  });

  /// Which pre-colored pattern PNG to use.
  final ZPatternVariant variant;

  /// Pattern opacity (0.0 – 1.0). Brand bible values:
  /// - Hero cards: 0.10
  /// - Feature cards: 0.07
  /// - Empty states: 0.06
  /// - Search bar: 0.05
  /// - Tab track: 0.04
  /// - Buttons (color-burn): 0.15
  /// - FAB (color-burn): 0.18
  final double opacity;

  /// How the pattern blends with the surface beneath.
  /// - [BlendMode.screen] for dark surfaces
  /// - [BlendMode.colorBurn] for light/colored surfaces
  final BlendMode blendMode;

  @override
  State<ZPatternOverlay> createState() => _ZPatternOverlayState();
}

class _ZPatternOverlayState extends State<ZPatternOverlay> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadPattern();
  }

  @override
  void didUpdateWidget(ZPatternOverlay old) {
    super.didUpdateWidget(old);
    if (old.variant != widget.variant) {
      _image?.dispose();
      _image = null;
      _loadPattern();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadPattern() async {
    final assetPath = widget.variant.assetPath;
    // Check shared cache first.
    final cached = _PatternCache.get(assetPath);
    if (cached != null) {
      if (mounted) setState(() => _image = cached.clone());
      return;
    }
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _PatternCache.put(assetPath, frame.image);
      if (mounted) {
        setState(() => _image = frame.image.clone());
      }
    } catch (_) {
      // Asset unavailable — no overlay shown.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return const SizedBox.shrink();

    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Positioned.fill(
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: widget.opacity,
            child: CustomPaint(
              painter: _PatternPainter(
                image: _image!,
                blendMode: widget.blendMode,
                devicePixelRatio: dpr,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a tiled pattern image with the specified blend mode.
class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.image,
    required this.blendMode,
    required this.devicePixelRatio,
  });

  final ui.Image image;
  final BlendMode blendMode;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = blendMode;

    // Scale the pattern to logical pixels.
    final scale = 1.0 / devicePixelRatio;

    canvas.save();
    canvas.scale(scale);

    for (var y = 0.0; y < size.height / scale; y += image.height.toDouble()) {
      for (var x = 0.0; x < size.width / scale; x += image.width.toDouble()) {
        canvas.drawImage(image, Offset(x, y), paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.image != image || old.blendMode != blendMode;
}

/// Simple in-memory cache so the pattern PNG is decoded once and shared
/// across all overlay instances using the same variant.
class _PatternCache {
  static final Map<String, ui.Image> _cache = {};

  static ui.Image? get(String key) => _cache[key];

  static void put(String key, ui.Image image) {
    _cache[key] = image;
  }
}
