/// Zuralog — Score History Provider.
///
/// Fetches historical health scores for the Data tab ScoreTrendHero.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/data/domain/score_history_models.dart';

// ── Selected Range State ──────────────────────────────────────────────────────

/// Currently selected range tab in the ScoreTrendHero.
final scoreHistoryRangeProvider =
    StateProvider<ScoreHistoryRange>((ref) => ScoreHistoryRange.thirtyDays);

// ── Score History Data ────────────────────────────────────────────────────────

/// Fetches the health score history for the selected range.
///
/// Automatically re-fetches when [scoreHistoryRangeProvider] changes.
final scoreHistoryProvider =
    FutureProvider<ScoreHistoryData>((ref) async {
  final range = ref.watch(scoreHistoryRangeProvider);
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/api/v1/health-score/history',
      queryParameters: {'range': range.apiParam},
    );
    return ScoreHistoryData.fromJson(
      response.data as Map<String, dynamic>,
    );
  } catch (_) {
    // Return empty data on error — the hero degrades gracefully.
    return ScoreHistoryData.empty;
  }
});
