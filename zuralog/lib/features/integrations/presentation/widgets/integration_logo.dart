/// Zuralog — Integration Logo Widget.
///
/// Renders a branded logo for a third-party integration using [Image.asset].
/// Falls back gracefully to a coloured circle with text initials when the
/// asset cannot be loaded (e.g., during tests or before assets are bundled).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_text_styles.dart';

/// Displays the logo for a third-party integration.
///
/// Attempts to load [logoAsset] via [Image.asset]. If the asset is missing
/// or fails to decode, renders a coloured circle containing the first two
/// characters of [name] as initials — ensuring the UI is always coherent.
///
/// Parameters:
///   logoAsset: The asset path to the integration logo image.
///   name: The integration name; used to derive initials for the fallback.
///   size: The width and height of the logo area (default: 40).
class IntegrationLogo extends StatelessWidget {
  /// Creates an [IntegrationLogo].
  const IntegrationLogo({
    super.key,
    required this.logoAsset,
    required this.name,
    this.size = 40,
  });

  /// Asset path for the integration logo (SVG or PNG).
  final String logoAsset;

  /// Service name used to derive the fallback initials.
  final String name;

  /// Width and height of the rendered logo area in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback: coloured circle with initials.
          return _InitialsFallback(name: name, size: size);
        },
      ),
    );
  }
}

/// Fallback widget rendered when an integration logo asset cannot be loaded.
///
/// Shows a coloured circle with the first two letters of [name].
class _InitialsFallback extends StatelessWidget {
  /// Creates an [_InitialsFallback] for [name] at the given [size].
  const _InitialsFallback({required this.name, required this.size});

  /// Integration name used to derive the two-letter initials.
  final String name;

  /// Diameter of the circle in logical pixels.
  final double size;

  /// Derives a deterministic colour from the integration name.
  ///
  /// Each unique [name] string gets a stable hue so the same integration
  /// always renders in the same colour without hard-coding values.
  Color _colorForName(String name) {
    const colors = [
      Color(0xFFE07A5F), // coral
      Color(0xFF3D405B), // slate
      Color(0xFF81B29A), // sage
      Color(0xFFF2CC8F), // sand
      Color(0xFF5B8DB8), // blue
      Color(0xFF9B59B6), // purple
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  /// Returns the first 1–2 characters of [name] as upper-case initials.
  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorForName(name),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: (size * 0.35).clamp(10, 18),
        ),
      ),
    );
  }
}
