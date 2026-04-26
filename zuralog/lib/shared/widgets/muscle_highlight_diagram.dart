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

/// Physically removes `<g ...id="groupId"...>...</g>` from the SVG string,
/// correctly handling nested `<g>` elements (e.g. the `facefeatures` subgroup
/// inside `group_front`) via depth-tracking.
///
/// Used to show front-only or back-only views without relying on ClipRect
/// geometry math — the rendered SVG just contains one figure.
String _dropGroup(String svg, String groupId) {
  final openMatch = RegExp(
    r'<g[^>]*\bid="' + RegExp.escape(groupId) + r'"[^>]*>',
  ).firstMatch(svg);
  if (openMatch == null) return svg;

  final start = openMatch.start;
  var i = openMatch.end;
  var depth = 1;
  while (i < svg.length && depth > 0) {
    final nextOpen = svg.indexOf('<g', i);
    final nextClose = svg.indexOf('</g>', i);
    if (nextClose == -1) break;
    if (nextOpen != -1 && nextOpen < nextClose) {
      depth += 1;
      i = nextOpen + 2;
    } else {
      depth -= 1;
      i = nextClose + '</g>'.length;
    }
  }
  return svg.substring(0, start) + svg.substring(i);
}

/// Rewrites the root `<svg ...>` tag to use [newViewBox] (a "minX minY w h"
/// string) and corresponding width/height attributes. Needed when we drop
/// one half of the figure — otherwise `fit: contain` scales the full
/// 748×711 canvas into the container and the surviving figure ends up
/// hugging one edge at half-size.
String _rewriteViewBox(String svg, String newViewBox, String width, String height) {
  var out = svg.replaceFirst(
    RegExp(r'viewBox="[^"]*"'),
    'viewBox="$newViewBox"',
  );
  out = out.replaceFirst(RegExp(r'width="[^"]*"'), 'width="$width"');
  out = out.replaceFirst(RegExp(r'height="[^"]*"'), 'height="$height"');
  return out;
}

// Source canvas is 748.8 × 711.6, with the front figure on the left half
// (x=0-374) and the back figure on the right half (x=374-748). These are
// the two cropped viewBoxes we re-use for front-only / back-only renders.
const String _frontViewBox = '0 0 374.4 711.6';
const String _backViewBox = '374.4 0 374.4 711.6';
const String _halfWidth = '374.4';
const String _fullHeight = '711.6';

/// Returns an SVG string with [group] highlighted in [highlight]. All other
/// paths are recoloured to [base] so the diagram reads as a single figure.
Future<String> _buildSvg(
  MuscleGroup group,
  Color highlight,
  Color base,
  Color stroke, {
  bool onlyFront = false,
  bool onlyBack = false,
}) async {
  final key = '${group.slug}_${highlight.value}_${base.value}_${stroke.value}'
      '_${onlyFront ? 1 : 0}_${onlyBack ? 1 : 0}';
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

  // Physically drop the unused half AND shrink the viewBox to the
  // surviving half's bounds. Dropping alone isn't enough — `fit: contain`
  // still scales the original 748-wide canvas into the container, which
  // made the remaining figure render at half-size tucked against one
  // edge. Cropping the viewBox makes the surviving figure actually fill
  // the column.
  if (onlyFront) {
    out = _dropGroup(out, 'group_back');
    out = _rewriteViewBox(out, _frontViewBox, _halfWidth, _fullHeight);
  }
  if (onlyBack) {
    out = _dropGroup(out, 'group_front');
    out = _rewriteViewBox(out, _backViewBox, _halfWidth, _fullHeight);
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
  bool strokeless, {
  bool onlyFront = false,
  bool onlyBack = false,
}) async {
  // Order-independent hash of the zones map so two equivalent inputs
  // (same muscle→colour pairs in any order) share a single cache entry,
  // and arbitrary slugs can't collide via delimiter tricks.
  final zonesHash = Object.hashAllUnordered(
    zones.entries.map((e) => Object.hash(e.key, e.value.value)),
  );
  final key = 'zones_${zonesHash}_'
      '${base.value}_${stroke.value}_${strokeless ? 1 : 0}'
      '_${onlyFront ? 1 : 0}_${onlyBack ? 1 : 0}';
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

  // Physically drop the unused half AND shrink the viewBox to the
  // surviving half's bounds (see notes in `_buildSvg`).
  if (onlyFront) {
    out = _dropGroup(out, 'group_back');
    out = _rewriteViewBox(out, _frontViewBox, _halfWidth, _fullHeight);
  }
  if (onlyBack) {
    out = _dropGroup(out, 'group_front');
    out = _rewriteViewBox(out, _backViewBox, _halfWidth, _fullHeight);
  }

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
        ? _buildSvgZones(
            zones!,
            base,
            stroke,
            strokeless,
            onlyFront: onlyFront,
            onlyBack: onlyBack,
          )
        : _buildSvg(
            muscleGroup!,
            highlightColor ?? colors.primary,
            base,
            stroke,
            onlyFront: onlyFront,
            onlyBack: onlyBack,
          );

    return FutureBuilder<String>(
      future: svgFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          // Callers supply external size constraints (fixed-height tiles,
          // 44×44 thumbnails, the hero figure). SizedBox.expand would throw
          // in an unconstrained parent; shrink is the safe placeholder.
          return const SizedBox.shrink();
        }
        // The SVG string already has the unused half dropped when
        // onlyFront / onlyBack is set, so no clip math is needed here.
        return SvgPicture.string(snap.data!, fit: fit);
      },
    );
  }
}
