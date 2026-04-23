/// Zuralog — Catch-up Providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/catchup/data/catchup_repository.dart';

/// Singleton repository for catch-up status.
final catchupRepositoryProvider = Provider<CatchupRepository>((ref) {
  return CatchupRepository(apiClient: ref.watch(apiClientProvider));
});

/// Fetches the user's current catch-up status. Auto-invalidated by caller
/// after a PATCH that mutates status (dismiss / complete).
final catchupStatusProvider = FutureProvider.autoDispose<CatchupStatus>((ref) {
  return ref.watch(catchupRepositoryProvider).fetchStatus();
});
