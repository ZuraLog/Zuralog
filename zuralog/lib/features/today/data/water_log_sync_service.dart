/// Background sync: pushes unsynced water logs to the Cloud Brain.
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
import 'package:zuralog/features/today/data/water_log_local_repository.dart';
import 'package:zuralog/features/today/domain/water_log.dart';

String _isoDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String _isoWithOffset(DateTime dt) {
  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hh = offset.inHours.abs().toString().padLeft(2, '0');
  final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${dt.toLocal().toIso8601String().split('.').first}$sign$hh:$mm';
}

class WaterLogSyncService with WidgetsBindingObserver {
  WaterLogSyncService({
    required WaterLogLocalRepository localRepo,
    required ApiClient client,
  })  : _localRepo = localRepo,
        _client = client {
    WidgetsBinding.instance.addObserver(this);
  }

  final WaterLogLocalRepository _localRepo;
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
  Future<void> syncLog(WaterLog log) async {
    try {
      await _client.post('/api/v1/ingest', data: {
        'metric_type': 'water_ml',
        'value': log.amountMl,
        'unit': 'mL',
        'source': 'manual',
        'recorded_at': _isoWithOffset(log.recordedAt),
        if (log.vesselKey != null) 'metadata': {'vessel_key': log.vesselKey},
      });
      await _localRepo.markSynced(log.id, log.logDate);
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
      for (final log in _localRepo.getLogsForDate(date).where((l) => !l.synced)) {
        await syncLog(log);
      }
    }
  }
}

final waterLogSyncServiceProvider = Provider<WaterLogSyncService>((ref) {
  final service = WaterLogSyncService(
    localRepo: ref.watch(waterLogLocalRepositoryProvider),
    client: ref.watch(apiClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
