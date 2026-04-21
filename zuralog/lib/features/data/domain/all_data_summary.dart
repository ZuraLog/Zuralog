import 'package:flutter/foundation.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show HealthCategory;

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
