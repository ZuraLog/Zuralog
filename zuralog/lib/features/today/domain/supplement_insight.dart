class SupplementInsightItem {
  const SupplementInsightItem({
    required this.metricType,
    required this.metricLabel,
    required this.direction,
    required this.correlation,
    required this.insightText,
  });

  final String metricType;
  final String metricLabel;
  final String direction; // 'positive' | 'negative' | 'neutral'
  final double correlation;
  final String insightText;

  factory SupplementInsightItem.fromJson(Map<String, dynamic> json) =>
      SupplementInsightItem(
        metricType: json['metric_type'] as String,
        metricLabel: json['metric_label'] as String,
        direction: json['direction'] as String,
        correlation: (json['correlation'] as num).toDouble(),
        insightText: json['insight_text'] as String,
      );
}

class SupplementInsightsResult {
  const SupplementInsightsResult({
    required this.insights,
    required this.dataDays,
    required this.hasEnoughData,
  });

  final List<SupplementInsightItem> insights;
  final int dataDays;
  final bool hasEnoughData;

  factory SupplementInsightsResult.fromJson(Map<String, dynamic> json) =>
      SupplementInsightsResult(
        insights: (json['insights'] as List<dynamic>)
            .map((e) => SupplementInsightItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        dataDays: json['data_days'] as int,
        hasEnoughData: json['has_enough_data'] as bool,
      );

  static const SupplementInsightsResult empty = SupplementInsightsResult(
    insights: [],
    dataDays: 0,
    hasEnoughData: false,
  );
}
