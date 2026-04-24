/// Background sync: pushes unsynced muscle logs to the Cloud Brain.
///
/// Registers itself as a [WidgetsBindingObserver] so it retries any
/// pending (unsynced) logs whenever the app returns to the foreground —
/// covering offline saves, expired tokens, and transient network failures.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/body/data/muscle_log_repository.dart';
import 'package:zuralog/features/body/domain/muscle_log.dart';

String _isoDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

class MuscleLogSyncService with WidgetsBindingObserver {
  MuscleLogSyncService({
    required MuscleLogRepository repo,
    required ApiClient client,
  })  : _repo = repo,
        _client = client {
    WidgetsBinding.instance.addObserver(this);
  }

  final MuscleLogRepository _repo;
  final ApiClient _client;

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPending());
    }
  }

  /// Posts [log] to the backend. Marks it synced locally on success.
  /// Silently swallows network errors — [syncPending] will retry later.
  Future<void> syncLog(MuscleLog log) async {
    try {
      await _client.post('/api/v1/muscle-logs', data: {
        'muscle_group': log.muscleGroup.slug,
        'state': log.state.slug,
        'log_date': log.logDate,
        'logged_at_time': log.loggedAtTime,
      });
      await _repo.markSynced(log.logDate, log.muscleGroup);
    } catch (_) {
      // Network failure or 4xx/5xx — will retry on next syncPending() call.
    }
  }

  /// Retries all unsynced logs from today and yesterday.
  Future<void> syncPending() async {
    final today = _isoDate(DateTime.now());
    final yesterday =
        _isoDate(DateTime.now().subtract(const Duration(days: 1)));
    for (final date in [today, yesterday]) {
      for (final log in _repo.getLogsForDate(date).where((l) => !l.synced)) {
        await syncLog(log);
      }
    }
  }
}

final muscleLogSyncServiceProvider = Provider<MuscleLogSyncService>((ref) {
  final service = MuscleLogSyncService(
    repo: ref.watch(muscleLogRepositoryProvider),
    client: ref.watch(apiClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
