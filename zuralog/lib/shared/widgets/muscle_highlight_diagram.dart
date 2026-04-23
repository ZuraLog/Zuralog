/// Zuralog Design System — Muscle Highlight Diagram.
///
/// A vector body diagram (front + back) with the target muscle group
/// highlighted in the brand colour. Built on top of etal/bodymap
/// (Apache 2.0) — see assets/images/body_map.svg.
///
/// The SVG ships with every body region as a separately-named path
/// (chest_left_front, thigh_right_back, gluteal_right, etc.). This
/// widget loads the SVG once, caches it per-target-group, and injects
/// a fill override on the paths that correspond to the caller's
/// [MuscleGroup]. Every other path stays neutral gray.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';

/// Mapping from MuscleGroup → list of path IDs to recolour in body_map.svg.
const Map<MuscleGroup, List<String>> _muscleIdMap = {
  MuscleGroup.chest: ['chest_left_front', 'chest_right_front'],
  MuscleGroup.back: [
    'upperback_left',
    'upperback_right',
    'midback_left',
    'midback_right',
    'lowerback_left',
    'lowerback_right',
  ],
  MuscleGroup.shoulders: [
    'shoulder_left_front',
    'shoulder_right_front',
    'shoulder_left_back',
    'shoulder_right_back',
    'deltoid_left_front',
    'deltoid_right_front',
  ],
  MuscleGroup.biceps: ['arm_left_front', 'arm_right_front'],
  MuscleGroup.triceps: ['arm_left_back', 'arm_right_back'],
  MuscleGroup.forearms: [
    'forearm_left_front',
    'forearm_right_front',
    'forearm_left_back',
    'forearm_right_back',
  ],
  MuscleGroup.abs: [
    'abdomen_left_front',
    'abdomen_right_front',
    'midtorso_left_front',
    'midtorso_right_front',
  ],
  MuscleGroup.quads: ['thigh_left_front', 'thigh_right_front'],
  MuscleGroup.hamstrings: ['thigh_left_back', 'thigh_right_back'],
  MuscleGroup.glutes: ['gluteal_left', 'gluteal_right'],
  MuscleGroup.calves: [
    'calf_left_front',
    'calf_right_front',
    'calf_left_back',
    'calf_right_back',
    'lowercalf_left_front',
    'lowercalf_right_front',
    'lowercalf_left_back',
    'lowercalf_right_back',
  ],
  // Cardio / full-body / other: light the whole figure so the diagram still
  // reads as intentional rather than broken.
  MuscleGroup.cardio: [],
  MuscleGroup.fullBody: [],
  MuscleGroup.other: [],
};

/// Muscles groups that should have their entire figure tinted.
const Set<MuscleGroup> _wholeBodyGroups = {
  MuscleGroup.cardio,
  MuscleGroup.fullBody,
};

/// Cache of fully-rendered SVG strings keyed by (muscleGroup, highlight, base).
final Map<String, String> _svgCache = <String, String>{};
String? _rawSvg;

Future<String> _loadRawSvg() async {
  _rawSvg ??= await rootBundle.loadString('assets/images/body_map.svg');
  return _rawSvg!;
}

/// Returns an SVG string with [group] highlighted in [highlight]. All other
/// paths are recoloured to [base] so the diagram reads as a single figure.
Future<String> _buildSvg(
  MuscleGroup group,
  Color highlight,
  Color base,
  Color stroke,
) async {
  final key = '${group.slug}_${highlight.value}_${base.value}_${stroke.value}';
  final cached = _svgCache[key];
  if (cached != null) return cached;

  final raw = await _loadRawSvg();
  final highlightHex = _toHex(highlight);
  final baseHex = _toHex(base);
  final strokeHex = _toHex(stroke);
  final ids = _muscleIdMap[group] ?? const [];
  final tintWhole = _wholeBodyGroups.contains(group);

  // Normalise every path's fill + stroke to the base/stroke colours first.
  var out = raw.replaceAll(RegExp(r'fill:#[0-9a-fA-F]{3,6}'), 'fill:$baseHex');
  out = out.replaceAll(RegExp(r'stroke:#[0-9a-fA-F]{3,6}'), 'stroke:$strokeHex');

  if (tintWhole) {
    // Replace base fills with the highlight colour across the whole body.
    out = out.replaceAll('fill:$baseHex', 'fill:$highlightHex');
  } else {
    // Re-tint only the matching muscle paths. In this SVG each path
    // element lists `style="fill:..."` BEFORE `id="..."`, so we grab the
    // full <path .../> element by id first, then swap its fill.
    for (final id in ids) {
      final pattern = RegExp(
        r'<path\b[^>]*?id="' + RegExp.escape(id) + r'"[^>]*?/>',
        multiLine: true,
        dotAll: true,
      );
      out = out.replaceAllMapped(pattern, (m) {
        return m.group(0)!.replaceFirst(
          RegExp(r'fill:#[0-9a-fA-F]+'),
          'fill:$highlightHex',
        );
      });
    }
  }

  _svgCache[key] = out;
  return out;
}

String _toHex(Color c) =>
    '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';

/// Multi-zone variant: every muscle id in [zones] gets re-tinted to its
/// mapped colour. Every other path uses [base]. When [strokeless] is true,
/// all stroke-widths are zeroed so adjacent same-colour zones merge.
Future<String> _buildSvgZones(
  Map<MuscleGroup, Color> zones,
  Color base,
  Color stroke,
  bool strokeless,
) async {
  final zonesKey = zones.entries
      .map((e) => '${e.key.slug}:${e.value.value}')
      .toList(growable: false)
    ..sort();
  final key = 'zones_${zonesKey.join(',')}_'
      '${base.value}_${stroke.value}_${strokeless ? 1 : 0}';
  final cached = _svgCache[key];
  if (cached != null) return cached;

  final raw = await _loadRawSvg();
  final baseHex = _toHex(base);
  final strokeHex = _toHex(stroke);

  var out = raw.replaceAll(RegExp(r'fill:#[0-9a-fA-F]{3,6}'), 'fill:$baseHex');
  out = out.replaceAll(RegExp(r'stroke:#[0-9a-fA-F]{3,6}'), 'stroke:$strokeHex');
  if (strokeless) {
    out = out.replaceAll(RegExp(r'stroke-width:[0-9.]+'), 'stroke-width:0');
  }

  zones.forEach((group, color) {
    final ids = _muscleIdMap[group] ?? const [];
    final hex = _toHex(color);
    for (final id in ids) {
      final pattern = RegExp(
        r'<path\b[^>]*?id="' + RegExp.escape(id) + r'"[^>]*?/>',
        multiLine: true,
        dotAll: true,
      );
      out = out.replaceAllMapped(pattern, (m) {
        return m.group(0)!.replaceFirst(
          RegExp(r'fill:#[0-9a-fA-F]+'),
          'fill:$hex',
        );
      });
    }
  });

  _svgCache[key] = out;
  return out;
}

/// Renders the body diagram with [muscleGroup] highlighted.
///
/// Pass [onlyFront] = true to show just the front-view half (right half of
/// the source SVG), which reads better at small tile sizes.
class MuscleHighlightDiagram extends StatelessWidget {
  /// Highlights a single [muscleGroup] — the legacy API. Unchanged callers
  /// keep working.
  const MuscleHighlightDiagram({
    super.key,
    required MuscleGroup this.muscleGroup,
    this.highlightColor,
    this.baseColor,
    this.strokeColor,
    this.onlyFront = false,
    this.onlyBack = false,
    this.strokeless = false,
    this.fit = BoxFit.contain,
  }) : zones = null;

  /// Multi-zone variant — colours each muscle in [zones] independently.
  const MuscleHighlightDiagram.zones({
    super.key,
    required Map<MuscleGroup, Color> this.zones,
    this.baseColor,
    this.strokeColor,
    this.onlyFront = false,
    this.onlyBack = false,
    this.strokeless = true,
    this.fit = BoxFit.contain,
  })  : muscleGroup = null,
        highlightColor = null;

  final MuscleGroup? muscleGroup;
  final Map<MuscleGroup, Color>? zones;
  final Color? highlightColor;
  final Color? baseColor;
  final Color? strokeColor;
  final bool onlyFront;
  final bool onlyBack;
  final bool strokeless;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final base = baseColor ?? colors.surfaceRaised;
    final stroke = strokeColor ?? colors.textSecondary.withValues(alpha: 0.35);

    final Future<String> svgFuture = zones != null
        ? _buildSvgZones(zones!, base, stroke, strokeless)
        : _buildSvg(
            muscleGroup!,
            highlightColor ?? colors.primary,
            base,
            stroke,
          );

    return FutureBuilder<String>(
      future: svgFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final svg = SvgPicture.string(snap.data!, fit: fit);
        if (!onlyFront && !onlyBack) return svg;
        return ClipRect(
          child: Align(
            alignment:
                onlyFront ? Alignment.centerRight : Alignment.centerLeft,
            widthFactor: 0.5,
            child: svg,
          ),
        );
      },
    );
  }
}
