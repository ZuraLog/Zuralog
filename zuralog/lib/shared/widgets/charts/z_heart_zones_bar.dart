/// Zuralog Design System — Heart Zones Bar.
///
/// A horizontal stacked bar that breaks a day's heart-rate effort into four
/// zones — Resting / Fat burn / Cardio / Peak — paired with a per-zone
/// legend of minutes spent in each zone.
///
/// The zone palette is fixed for every user so the visual reads the same
/// across the app. When all zone minutes are zero (or the map is empty)
/// the bar renders a dim placeholder and the legend still shows all four
/// zones with "0 min" values.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// The four heart-rate zones the bar visualises.
enum ZHeartZone { resting, fatBurn, cardio, peak }

/// Horizontal stacked bar showing minutes spent per heart zone.
///
/// Callers pass a [minutes] map keyed by [ZHeartZone]. Any zone missing
/// from the map is treated as zero. The bar is clipped to [radius] and
/// each zone's width is proportional to its minute count. If the map is
/// empty or every zone is zero, the bar is drawn as a dim placeholder
/// using [categoryColor].
class ZHeartZonesBar extends StatelessWidget {
  /// Creates a [ZHeartZonesBar].
  const ZHeartZonesBar({
    super.key,
    required this.minutes,
    required this.categoryColor,
    this.height = 14,
    this.radius = 7,
  });

  /// Minutes spent in each zone today. Missing keys count as zero.
  final Map<ZHeartZone, int> minutes;

  /// Category accent color used for the empty-state placeholder bar.
  /// The zone palette itself is fixed and does not use this color.
  final Color categoryColor;

  /// Bar height in logical pixels.
  final double height;

  /// Corner radius used on the outer clip.
  final double radius;

  // Fixed palette — same for every user and every entry point.
  static const Color _restingColor = Color(0xFF7EC4A1); // muted sage
  static const Color _fatBurnColor = Color(0xFFFFB06A); // warm amber
  static const Color _cardioColor = Color(0xFFFF6D7C); // rose
  static const Color _peakColor = Color(0xFFE63946); // deep red

  static Color _colorFor(ZHeartZone zone) {
    switch (zone) {
      case ZHeartZone.resting:
        return _restingColor;
      case ZHeartZone.fatBurn:
        return _fatBurnColor;
      case ZHeartZone.cardio:
        return _cardioColor;
      case ZHeartZone.peak:
        return _peakColor;
    }
  }

  static String _labelFor(ZHeartZone zone) {
    switch (zone) {
      case ZHeartZone.resting:
        return 'Resting';
      case ZHeartZone.fatBurn:
        return 'Fat burn';
      case ZHeartZone.cardio:
        return 'Cardio';
      case ZHeartZone.peak:
        return 'Peak';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Build an ordered list so the bar always goes Resting → Peak.
    const order = [
      ZHeartZone.resting,
      ZHeartZone.fatBurn,
      ZHeartZone.cardio,
      ZHeartZone.peak,
    ];

    final values = <ZHeartZone, int>{
      for (final z in order) z: (minutes[z] ?? 0).clamp(0, 1 << 30),
    };

    final total = values.values.fold<int>(0, (a, b) => a + b);
    final hasData = total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Bar ───────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: height,
            child: hasData
                ? Row(
                    children: [
                      for (final z in order)
                        if (values[z]! > 0)
                          Expanded(
                            flex: values[z]!,
                            child: Container(color: _colorFor(z)),
                          ),
                    ],
                  )
                : Container(
                    color: categoryColor.withValues(alpha: 0.08),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Legend ────────────────────────────────────────────────────────
        Column(
          children: [
            for (final z in order)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorFor(z),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _labelFor(z),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${values[z]} min',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: values[z]! > 0
                            ? colors.textSecondary
                            : colors.textTertiary,
                        fontWeight: values[z]! > 0
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
