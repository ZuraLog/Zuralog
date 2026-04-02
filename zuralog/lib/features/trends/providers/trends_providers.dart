/// Zuralog — Trends Tab Riverpod Providers.
///
/// All state for the Trends tab is managed here.
///
/// Provider inventory:
/// - [trendsRepositoryProvider]         — singleton repository
/// - [trendsHomeProvider]               — async aggregated Trends Home data
/// - [selectedCategoryFilterProvider]   — active category filter slug
/// - [expandedPatternIdsProvider]       — set of pattern IDs currently expanded
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

// ── Expanded Pattern IDs ──────────────────────────────────────────────────────

/// Set of pattern IDs currently expanded. Lives outside the widget tree so
/// expansion state survives scroll recycling.
final expandedPatternIdsProvider = StateProvider<Set<String>>((ref) => const {});

// ── Selected Time Range ──────────────────────────────────────────────────────

/// Active time range for each expanded pattern card, keyed by pattern ID.
///
/// Defaults to `'30d'`. When the user picks a different chip (e.g. 7D, 90D),
/// updating this provider causes [patternExpandProvider] to re-fetch with the
/// new range.
final selectedTimeRangeProvider =
    StateProvider.family<String, String>((ref, patternId) => '30d');

// ── Pattern Expand ────────────────────────────────────────────────────────────

/// Chart data and AI explanation for a single pattern card identified by its
/// [patternId].
///
/// Not autoDisposed — the data stays alive after the card collapses so a
/// second tap re-expands instantly without a loading spinner.
///
/// Watches [selectedTimeRangeProvider] for the given pattern so that
/// changing the time range chip triggers a fresh fetch automatically.
///
/// **Error handling — why errors propagate:**
///
/// Unlike [trendsHomeProvider], which catches all errors and returns
/// safe empty data, this provider lets errors propagate to the caller
/// (FutureProvider error branch). The expanded card renders a user-visible
/// error state rather than silently hiding the failure. This is intentional:
/// the user explicitly asked to see the data (by tapping), so they deserve
/// to know if it failed.
final patternExpandProvider =
    FutureProvider.family<PatternExpandData, String>((ref, patternId) {
  final repo = ref.read(trendsRepositoryProvider);
  final timeRange = ref.watch(selectedTimeRangeProvider(patternId));
  return repo.fetchPatternExpand(patternId, timeRange: timeRange);
});
