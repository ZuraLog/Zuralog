/// Background sync: pushes unsynced weight logs to the Cloud Brain.
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
import 'package:zuralog/features/today/data/weight_log_local_repository.dart';
import 'package:zuralog/features/today/domain/weight_log.dart';

String _isoDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String _isoWithOffset(DateTime dt) {
  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hh = offset.inHours.abs().toString().padLeft(2, '0');
  final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${dt.toLocal().toIso8601String().split('.').first}$sign$hh:$mm';
}

class WeightLogSyncService with WidgetsBindingObserver {
  WeightLogSyncService({
    required WeightLogLocalRepository localRepo,
    required ApiClient client,
  })  : _localRepo = localRepo,
        _client = client {
    WidgetsBinding.instance.addObserver(this);
  }

  final WeightLogLocalRepository _localRepo;
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
  Future<void> syncLog(WeightLog log) async {
    try {
      await _client.post('/api/v1/ingest', data: {
        'metric_type': 'weight_kg',
        'value': log.valueKg,
        'unit': 'kg',
        'source': 'manual',
        'recorded_at': _isoWithOffset(log.recordedAt),
        'metadata': {
          'time_of_day': log.timeOfDay,
          if (log.bodyFatPct != null) 'body_fat_pct': log.bodyFatPct,
        },
      });
      await _localRepo.markSynced(log.id, log.logDate);
    } catch (_) {
      // Network failure or 4xx/5xx — will retry on next syncPending() call.
    }
  }

  /// Retries all unsynced logs from the last 7 days.
  ///
  /// Weight is logged less frequently than water (typically once a day),
  /// so we scan a wider window to catch offline saves from earlier in the week.
  Future<void> syncPending() async {
    final today = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final date = _isoDate(today.subtract(Duration(days: i)));
      for (final log in _localRepo.getLogsForDate(date).where((l) => !l.synced)) {
        await syncLog(log);
      }
    }
  }
}

final weightLogSyncServiceProvider = Provider<WeightLogSyncService>((ref) {
  final service = WeightLogSyncService(
    localRepo: ref.watch(weightLogLocalRepositoryProvider),
    client: ref.watch(apiClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
