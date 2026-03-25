/// Zuralog — Trends Tab Riverpod Providers.
///
/// All state for the Trends tab is managed here.
///
/// Provider inventory:
/// - [trendsRepositoryProvider]         — singleton repository
/// - [trendsHomeProvider]               — async aggregated Trends Home data
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
