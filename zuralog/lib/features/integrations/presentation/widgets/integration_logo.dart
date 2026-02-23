/// Zuralog — Integration Logo Widget.
///
/// Renders a branded logo for a third-party integration.
///
/// Resolution order for each integration [id]:
///   1. A recognised brand icon from [simple_icons] (Strava, Garmin, Fitbit)
///      or [font_awesome_flutter] (Apple).
///   2. The [SimpleIcons.google] icon tinted with Google blue for
///      Google Health Connect.
///   3. An asset image if [logoAsset] is provided and the file loads.
///   4. A coloured circle with two-letter initials as the final fallback
///      (used for WHOOP and any future unknown integrations).
///
/// This design avoids bundling image assets in the app package entirely,
/// keeping the install size small while still showing recognisable brand icons.
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:simple_icons/simple_icons.dart';

import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Brand colour map ──────────────────────────────────────────────────────────

/// Maps each integration [id] to its canonical brand colour.
///
/// Used to tint the vector icon so it matches the real-world brand even
/// when rendered in a monochrome icon font.
const Map<String, Color> _kBrandColors = {
  'strava': Color(0xFFFC4C02),               // Strava orange
  'garmin': Color(0xFF1A73E8),               // Garmin blue
  'fitbit': Color(0xFF00B0B9),               // Fitbit teal
  'apple_health': Color(0xFF000000),         // Apple black (inverted on dark)
  'google_health_connect': Color(0xFF4285F4), // Google blue
};

// ── Icon resolver ─────────────────────────────────────────────────────────────

/// Describes a resolved brand icon for display.
class _BrandIcon {
  const _BrandIcon({required this.data, this.isFontAwesome = false});

  /// The icon glyph.
  final IconData data;

  /// Whether this icon requires [FaIcon] instead of the Material [Icon] widget.
  final bool isFontAwesome;
}

/// Returns a [_BrandIcon] for a known integration [id], or `null` when no
/// icon is available in the bundled font packs.
_BrandIcon? _brandIconForId(String id) {
  switch (id) {
    case 'strava':
      return const _BrandIcon(data: SimpleIcons.strava);
    case 'garmin':
      return const _BrandIcon(data: SimpleIcons.garmin);
    case 'fitbit':
      return const _BrandIcon(data: SimpleIcons.fitbit);
    case 'apple_health':
      return const _BrandIcon(
        data: FontAwesomeIcons.apple,
        isFontAwesome: true,
      );
    case 'google_health_connect':
      return const _BrandIcon(data: SimpleIcons.google);
    default:
      return null;
  }
}

// ── IntegrationLogo ───────────────────────────────────────────────────────────

/// Displays the logo for a third-party integration.
///
/// Tries icon fonts first (no bundled assets needed), then an optional
/// [logoAsset] image path, then a coloured initials circle fallback.
///
/// Parameters:
///   id: The integration identifier (e.g. `'strava'`, `'apple_health'`).
///   name: The integration display name — used for the initials fallback.
///   logoAsset: Optional asset path (rarely needed; icon fonts are preferred).
///   size: Diameter of the rendered logo area in logical pixels (default 40).
class IntegrationLogo extends StatelessWidget {
  /// Creates an [IntegrationLogo].
  const IntegrationLogo({
    super.key,
    required this.id,
    required this.name,
    this.logoAsset,
    this.size = 40,
  });

  /// The integration identifier used to resolve the brand icon and colour.
  final String id;

  /// Integration display name used to derive initials for the fallback.
  final String name;

  /// Optional asset path — only used when no icon font entry exists for [id].
  ///
  /// When `null` (or when the asset fails to load) the initials circle is
  /// rendered instead.
  final String? logoAsset;

  /// Width and height of the rendered logo area in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = _brandIconForId(id);

    // ── 1. Brand icon from font pack ─────────────────────────────────────────
    if (brand != null) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      final Color rawColor = _kBrandColors[id] ?? const Color(0xFF888888);
      // Invert the Apple icon so it stays visible on dark surfaces.
      final Color iconColor =
          (id == 'apple_health' && isDark) ? Colors.white : rawColor;

      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: brand.isFontAwesome
              ? FaIcon(brand.data, color: iconColor, size: size * 0.65)
              : Icon(brand.data, color: iconColor, size: size * 0.65),
        ),
      );
    }

    // ── 2. Asset image (if provided) ─────────────────────────────────────────
    final asset = logoAsset;
    if (asset != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _InitialsFallback(name: name, size: size),
        ),
      );
    }

    // ── 3. Initials circle fallback ──────────────────────────────────────────
    return _InitialsFallback(name: name, size: size);
  }
}

// ── Initials Fallback ─────────────────────────────────────────────────────────

/// Fallback widget rendered when no brand icon or asset image is available.
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
  Color _colorForName(String name) {
    const colors = [
      Color(0xFFE07A5F),
      Color(0xFF3D405B),
      Color(0xFF81B29A),
      Color(0xFFF2CC8F),
      Color(0xFF5B8DB8),
      Color(0xFF9B59B6),
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
