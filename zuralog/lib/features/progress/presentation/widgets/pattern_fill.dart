/// Wraps [child] in a ShaderMask that applies the brand topographic pattern.
///
/// Asynchronously loads the brand pattern PNG asset. Falls back to a sage
/// gradient if the asset is unavailable.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuralog/core/theme/app_colors.dart';

class PatternFill extends StatefulWidget {
  const PatternFill({super.key, required this.child, this.opacity = 0.85});
  final Widget child;
  final double opacity;

  @override
  State<PatternFill> createState() => _PatternFillState();
}

class _PatternFillState extends State<PatternFill> {
  ui.Image? _patternImage;

  @override
  void initState() {
    super.initState();
    _loadPattern();
  }

  Future<void> _loadPattern() async {
    try {
      final data = await rootBundle.load('assets/images/brand_pattern.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _patternImage = frame.image);
    } catch (_) {
      // Asset not found — gradient fallback is used automatically
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_patternImage != null) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return ShaderMask(
        shaderCallback: (bounds) {
          // Scale the shader matrix by 1/dpr so the pattern renders at the
          // same physical size regardless of screen density.
          return ImageShader(
            _patternImage!,
            TileMode.repeated,
            TileMode.repeated,
            (Matrix4.identity()..scaleByDouble(1.0 / dpr, 1.0 / dpr, 1.0, 1.0)).storage,
          );
        },
        blendMode: BlendMode.srcIn,
        child: Opacity(opacity: widget.opacity, child: widget.child),
      );
    }
    // TODO(brand-pattern): remove gradient fallback once asset loading is guaranteed
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.progressSage,
          AppColors.progressSage.withValues(alpha: 0.7),
          AppColors.progressSage,
        ],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Opacity(opacity: widget.opacity, child: widget.child),
    );
  }
}
