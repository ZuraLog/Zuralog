/// Zuralog — Trends Tab Riverpod Providers.
///
/// All state for the Trends tab is managed here.
///
/// Provider inventory:
/// - [trendsRepositoryProvider]         — singleton repository
/// - [trendsHomeProvider]               — async aggregated Trends Home data
/// - [selectedCategoryFilterProvider]   — active category filter slug
/// - [patternExpandProvider]            — chart + AI data for a pattern card
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/trends/data/trends_repository.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [TrendsRepositoryInterface] wired to the shared [apiClientProvider].
///
/// Always uses the real [TrendsRepository] backed by the Cloud Brain API.
/// Mock repositories are available for unit tests via provider overrides.
final trendsRepositoryProvider = Provider<TrendsRepositoryInterface>((ref) {
  return TrendsRepository(apiClient: ref.read(apiClientProvider));
});

// ── Trends Home ───────────────────────────────────────────────────────────────

/// Async provider for the aggregated Trends Home screen data.
///
/// Never puts the UI into an error state. All failures resolve to an empty
/// [TrendsHomeData] so the screen always reaches the [data:] branch and
/// renders the appropriate empty state instead of a connection error.
///
/// Invalidate with [ref.invalidate(trendsHomeProvider)] after a
/// pull-to-refresh.
final trendsHomeProvider = FutureProvider<TrendsHomeData>((ref) async {
  final repo = ref.read(trendsRepositoryProvider);
  try {
    return await repo.getTrendsHome();
  } catch (_) {
    return const TrendsHomeData(
      correlationHighlights: [],
      timePeriods: [],
      hasEnoughData: false,
    );
  }
});

// ── Category Filter ───────────────────────────────────────────────────────────

/// Active category filter slug. The value `'all'` means no filter is applied
/// and every pattern card is visible.
final selectedCategoryFilterProvider = StateProvider<String>((ref) => 'all');

// ── Pattern Expand ────────────────────────────────────────────────────────────

/// Chart data and AI explanation for a single pattern card identified by its
/// [patternId].
///
/// Not autoDisposed — the data stays alive after the card collapses so a
/// second tap re-expands instantly without a loading spinner.
final patternExpandProvider =
    FutureProvider.family<PatternExpandData, String>((ref, patternId) {
  final repo = ref.read(trendsRepositoryProvider);
  return repo.fetchPatternExpand(patternId);
});
