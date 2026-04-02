/// Zuralog Design System — Pattern Typography Component.
///
/// Renders text filled with the topographic pattern texture using
/// [ShaderMask] + [ImageShader], matching the website's CSS
/// `background-clip: text` technique.
///
/// Only use on display-size text (24 pt+) where the letterforms are
/// large enough to reveal the texture detail.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart'
    show ZPatternVariant, effectivePatternVariant;

/// Renders text filled with the topographic pattern texture.
///
/// Uses [ShaderMask] with [BlendMode.srcATop] so only the opaque pixels
/// (the text letterforms) are filled with the pattern image.
///
/// When [animate] is true the pattern drifts slowly on a diagonal
/// (20-second loop, same cadence as [ZPatternOverlay]). Respects
/// the system reduced-motion preference.
///
/// ## Usage
///
/// ```dart
/// ZPatternText(
///   text: 'Zuralog Health',
///   style: AppTextStyles.displayLarge,
///   variant: ZPatternVariant.sage,
///   animate: true,
/// )
/// ```
class ZPatternText extends StatefulWidget {
  const ZPatternText({
    super.key,
    required this.text,
    required this.style,
    this.variant = ZPatternVariant.sage,
    this.animate = true,
    this.textAlign,
  });

  /// The text to render with a pattern fill.
  final String text;

  /// The text style — size, weight, letter spacing, etc.
  /// The color is overridden internally (set to white so the shader
  /// mask can fill it).
  final TextStyle style;

  /// Which pre-colored pattern PNG to use.
  final ZPatternVariant variant;

  /// When true the pattern drifts diagonally over a 20-second loop.
  /// Respects the system reduced-motion preference.
  final bool animate;

  /// Optional text alignment.
  final TextAlign? textAlign;

  @override
  State<ZPatternText> createState() => _ZPatternTextState();
}

class _ZPatternTextState extends State<ZPatternText>
    with SingleTickerProviderStateMixin {
  // ── Static image cache (shared across all instances) ──────────────────
  static final Map<String, ui.Image> _imageCache = {};
  static final Map<String, Future<ui.Image>> _pendingLoads = {};

  ui.Image? _image;
  AnimationController? _controller;
  String? _lastLoadedPath;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ZPatternText old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) {
      if (widget.animate) {
        _maybeStartAnimation();
      } else {
        _disposeAnimation();
      }
    }
    // Variant changes are caught via didChangeDependencies which also runs
    // after didUpdateWidget — nothing extra needed here.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Resolve the correct variant for the current brightness.
    final isLight = Theme.of(context).brightness == Brightness.light;
    final resolvedVariant = effectivePatternVariant(widget.variant, isLight);

    // Reload only when the resolved asset path actually changed.
    if (resolvedVariant.assetPath != _lastLoadedPath) {
      _loadImage(resolvedVariant);
    }

    if (widget.animate && _controller == null) {
      _maybeStartAnimation();
    }
  }

  // ── Image loading ─────────────────────────────────────────────────────

  Future<void> _loadImage(ZPatternVariant variant) async {
    final path = variant.assetPath;
    _lastLoadedPath = path;

    // Already cached.
    if (_imageCache.containsKey(path)) {
      if (mounted) setState(() => _image = _imageCache[path]);
      _maybeStartAnimation();
      return;
    }

    // Already loading — wait for the same future.
    if (_pendingLoads.containsKey(path)) {
      final image = await _pendingLoads[path]!;
      if (mounted) setState(() => _image = image);
      _maybeStartAnimation();
      return;
    }

    // Start a new load.
    _pendingLoads[path] = _decodeImage(path);
    final image = await _pendingLoads[path]!;
    _imageCache[path] = image;
    _pendingLoads.remove(path);

    if (mounted) {
      setState(() => _image = image);
      _maybeStartAnimation();
    }
  }

  Future<ui.Image> _decodeImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // ── Animation ─────────────────────────────────────────────────────────

  void _maybeStartAnimation() {
    // Controller is created in initState — nothing extra needed.
  }

  void _disposeAnimation() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeAnimation();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  /// Maximum diagonal drift in logical pixels.
  static const double _driftRange = 60.0;

  Float64List _buildMatrix(Rect bounds) {
    if (_image == null) return Matrix4.identity().storage;

    // Scale the image so its shorter dimension covers the text bounds,
    // then tile via ImageShader.TileMode.repeated handles any overflow.
    final scaleX = bounds.width / _image!.width;
    final scaleY = bounds.height / _image!.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    // Drift offset when animating.
    double dx = 0;
    double dy = 0;
    if (_controller != null) {
      final t = _controller!.value; // 0 → 1
      dx = (t - 0.5) * _driftRange;
      dy = (t - 0.5) * _driftRange;
    }

    final matrix = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    return matrix.storage;
  }

  @override
  Widget build(BuildContext context) {
    // While the image is loading, show the text in a muted color so
    // layout is stable and nothing flashes.
    if (_image == null) {
      return Text(
        widget.text,
        style: widget.style.copyWith(color: Colors.white24),
        textAlign: widget.textAlign,
      );
    }

    final child = Text(
      widget.text,
      style: widget.style.copyWith(color: Colors.white),
      textAlign: widget.textAlign,
    );

    Widget shaderMask = ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (Rect bounds) {
        return ImageShader(
          _image!,
          TileMode.repeated,
          TileMode.repeated,
          _buildMatrix(bounds),
        );
      },
      child: child,
    );

    // When animating, rebuild on every tick.
    if (_controller != null) {
      shaderMask = AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            return ImageShader(
              _image!,
              TileMode.repeated,
              TileMode.repeated,
              _buildMatrix(bounds),
            );
          },
          child: child,
        ),
      );
    }

    return shaderMask;
  }
}
