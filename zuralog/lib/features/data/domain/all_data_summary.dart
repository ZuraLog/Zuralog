import 'package:flutter/foundation.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show HealthCategory;
import 'package:zuralog/features/data/domain/mandala_data.dart';
import 'package:zuralog/features/data/domain/metric_descriptions.dart';

/// Inline span of body text. When [metricId] is non-null, the renderer should
/// paint this span in that metric's category-tinted inline color and treat it
/// as a tap target opening that metric's microscope sheet.
@immutable
class AllDataSummarySpan {
  const AllDataSummarySpan({required this.text, this.metricId});
  final String text;
  final String? metricId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllDataSummarySpan &&
          other.text == text &&
          other.metricId == metricId;

  @override
  int get hashCode => Object.hash(text, metricId);
}

/// One row in the expanded breakdown: category stripe + name + elaboration + delta.
@immutable
class AllDataSummarySection {
  const AllDataSummarySection({
    required this.category,
    required this.primaryMetricId,
    required this.name,
    required this.elaboration,
    required this.deltaLabel,
  });

  final HealthCategory category;
  final String primaryMetricId;
  final String name;
  final String elaboration;
  final String deltaLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllDataSummarySection &&
          other.category == category &&
          other.primaryMetricId == primaryMetricId &&
          other.name == name &&
          other.elaboration == elaboration &&
          other.deltaLabel == deltaLabel;

  @override
  int get hashCode =>
      Object.hash(category, primaryMetricId, name, elaboration, deltaLabel);
}

/// Whole-screen AI summary — what the compact card and the expanded breakdown
/// both render from.
@immutable
class AllDataSummary {
  const AllDataSummary({
    required this.headline,
    required this.body,
    required this.sections,
    required this.referenceCount,
  });

  /// Lora-serif headline shown in the expanded breakdown.
  final String headline;

  /// 3-sentence body shown on the compact card. Spans with non-null
  /// metricIds are color-highlighted and tappable.
  final List<AllDataSummarySpan> body;

  /// Up to 5 section rows in the expanded breakdown.
  final List<AllDataSummarySection> sections;

  /// Total number of metric readings considered (for the meta line
  /// "Based on N readings · 6 categories").
  final int referenceCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllDataSummary &&
          other.headline == headline &&
          listEquals(other.body, body) &&
          listEquals(other.sections, sections) &&
          other.referenceCount == referenceCount;

  @override
  int get hashCode => Object.hash(
        headline,
        Object.hashAll(body),
        Object.hashAll(sections),
        referenceCount,
      );
}

/// Generates an [AllDataSummary] deterministically from raw [MandalaData].
///
/// The output is stable for a given input — same readings produce the same
/// summary text. This lets the screen memoise per (date × time-toggle).
///
/// A future iteration can replace [generate] with a backend call returning
/// the same [AllDataSummary] struct; the UI layer doesn't change.
class AllDataSummaryGenerator {
  const AllDataSummaryGenerator._();

  /// Compute the summary. Pure: no I/O, no provider reads, no side effects.
  static AllDataSummary generate(MandalaData data) {
    // Flatten every spoke that actually has both a value and a baseline.
    final ranked = <_RankedSpoke>[];
    for (final wedge in data.wedges) {
      for (final spoke in wedge.spokes) {
        final ratio = computeSpokeRatio(
          todayValue: spoke.todayValue,
          baseline: spoke.baseline30d,
          inverted: spoke.inverted,
        );
        if (ratio == null) continue;
        // Convert clamped ratio to a plain percent deviation around 0%.
        final deviation = (ratio - 1.0) * 100.0;
        ranked.add(_RankedSpoke(
          wedge: wedge,
          spoke: spoke,
          deviationPct: deviation,
        ));
      }
    }

    if (ranked.isEmpty) {
      return const AllDataSummary(
        headline:
            'Not enough data yet — connect a tracker to fill in your picture.',
        body: <AllDataSummarySpan>[],
        sections: <AllDataSummarySection>[],
        referenceCount: 0,
      );
    }

    // Top by absolute deviation overall.
    final byMagnitude = [...ranked]
      ..sort((a, b) => b.deviationPct.abs().compareTo(a.deviationPct.abs()));

    final positives = ranked.where((r) => r.deviationPct > 0).toList()
      ..sort((a, b) => b.deviationPct.compareTo(a.deviationPct));
    final negatives = ranked.where((r) => r.deviationPct < 0).toList()
      ..sort((a, b) => a.deviationPct.compareTo(b.deviationPct));

    // Pick the top 2 positive + top 1 negative for the body.
    final referenced = <_RankedSpoke>[];
    if (positives.isNotEmpty) referenced.add(positives[0]);
    if (positives.length >= 2) referenced.add(positives[1]);
    if (negatives.isNotEmpty) referenced.add(negatives[0]);
    while (referenced.length > 3) {
      referenced.removeLast();
    }

    final headline = _classifyHeadline(positives.length, negatives.length);
    final body = _composeBody(referenced);
    final sections = byMagnitude
        .take(5)
        .map((r) => AllDataSummarySection(
              category: r.wedge.category,
              primaryMetricId: r.spoke.metricId,
              name: _sectionName(r),
              elaboration: _sectionElaboration(r),
              deltaLabel: _formatDelta(r.deviationPct),
            ))
        .toList(growable: false);

    return AllDataSummary(
      headline: headline,
      body: body,
      sections: sections,
      referenceCount: ranked.length,
    );
  }

  // ── Headline classifier ────────────────────────────────────────────────

  static String _classifyHeadline(int positiveCount, int negativeCount) {
    if (positiveCount >= 3 && negativeCount == 0) {
      return 'A genuinely strong day, top to bottom.';
    }
    if (positiveCount >= 2 && negativeCount <= 1) {
      return 'A strong, well-recovered day with one quiet question.';
    }
    if (negativeCount >= 3 && positiveCount <= 1) {
      return "A slower day for you — your body's asking for a reset.";
    }
    if (positiveCount > 0 || negativeCount > 0) {
      return 'An uneven day — some highs, some quiets.';
    }
    return 'A calm, on-baseline day across the board.';
  }

  // ── Body composer ──────────────────────────────────────────────────────

  static List<AllDataSummarySpan> _composeBody(List<_RankedSpoke> picked) {
    if (picked.isEmpty) return const <AllDataSummarySpan>[];

    final out = <AllDataSummarySpan>[];

    // Sentence 1 — opening framing
    out.add(const AllDataSummarySpan(
        text: 'Today is one of your stronger days. '));

    // Sentence 2 — biggest positive (or any reading if none positive)
    final firstPositive = picked.firstWhere(
      (r) => r.deviationPct > 0,
      orElse: () => picked.first,
    );
    out.add(const AllDataSummarySpan(text: 'Your '));
    out.add(AllDataSummarySpan(
      text: firstPositive.spoke.displayName.toLowerCase(),
      metricId: firstPositive.spoke.metricId,
    ));
    out.add(AllDataSummarySpan(
      text:
          ' is ${_formatDeltaPct(firstPositive.deviationPct)} '
          '${firstPositive.deviationPct > 0 ? 'above' : 'below'} your normal',
    ));

    // Optional second positive
    final remainingPositives = picked
        .where((r) => r != firstPositive && r.deviationPct > 0)
        .toList();
    if (remainingPositives.isNotEmpty) {
      out.add(const AllDataSummarySpan(text: ', and your '));
      out.add(AllDataSummarySpan(
        text: remainingPositives.first.spoke.displayName.toLowerCase(),
        metricId: remainingPositives.first.spoke.metricId,
      ));
      out.add(const AllDataSummarySpan(text: ' is up too'));
    }
    out.add(const AllDataSummarySpan(text: '. '));

    // Sentence 3 — biggest negative as "one small note", if any
    final negativesPicked = picked.where((r) => r.deviationPct < 0).toList();
    if (negativesPicked.isNotEmpty) {
      final firstNegative = negativesPicked.first;
      out.add(const AllDataSummarySpan(text: 'One small note — your '));
      out.add(AllDataSummarySpan(
        text: firstNegative.spoke.displayName.toLowerCase(),
        metricId: firstNegative.spoke.metricId,
      ));
      out.add(AllDataSummarySpan(
        text:
            ' is ${_formatDeltaPct(firstNegative.deviationPct)} below your normal — worth a glance.',
      ));
    }

    return out;
  }

  // ── Section composers ──────────────────────────────────────────────────

  static String _sectionName(_RankedSpoke r) {
    final name = r.spoke.displayName;
    if (r.deviationPct > 15) return '$name had a strong day';
    if (r.deviationPct > 0) return '$name nudged above your normal';
    if (r.deviationPct < -15) return '$name is unusually low';
    return '$name dipped below your normal';
  }

  static String _sectionElaboration(_RankedSpoke r) {
    final desc = MetricDescriptions.lookup(r.spoke.metricId);
    final pct = r.deviationPct.abs().round();
    final dir = r.deviationPct > 0 ? 'above' : 'below';
    return '$desc Today is $pct% $dir your 30-day normal.';
  }

  static String _formatDelta(double pct) {
    final rounded = pct.abs().round();
    final arrow = pct > 0 ? '↑' : (pct < 0 ? '↓' : '·');
    return '$arrow $rounded%';
  }

  static String _formatDeltaPct(double pct) {
    return '${pct.abs().round()}%';
  }
}

/// Internal — a spoke with its deviation already computed.
class _RankedSpoke {
  const _RankedSpoke({
    required this.wedge,
    required this.spoke,
    required this.deviationPct,
  });
  final MandalaWedge wedge;
  final MandalaSpoke spoke;
  final double deviationPct;
}
