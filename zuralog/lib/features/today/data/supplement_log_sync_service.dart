/// Background sync: pushes unsynced supplement taken logs to the Cloud Brain.
///
/// Registers itself as a [WidgetsBindingObserver] so it retries any pending
/// (unsynced) logs whenever the app returns to the foreground — covering offline
/// saves, expired tokens, and transient network failures.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/today/data/supplement_log_local_repository.dart';
import 'package:zuralog/features/today/domain/supplement_taken_log.dart';

String _isoDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String _isoWithOffset(DateTime dt) {
  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hh = offset.inHours.abs().toString().padLeft(2, '0');
  final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${dt.toLocal().toIso8601String().split('.').first}$sign$hh:$mm';
}

class SupplementLogSyncService with WidgetsBindingObserver {
  SupplementLogSyncService({
    required SupplementLogLocalRepository localRepo,
    required ApiClient client,
  })  : _localRepo = localRepo,
        _client = client {
    WidgetsBinding.instance.addObserver(this);
  }

  final SupplementLogLocalRepository _localRepo;
  final ApiClient _client;

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPending());
    }
  }

  /// Posts [log] to the backend. Marks it synced locally on success,
  /// storing the server-assigned log row UUID so the UI can undo the tap.
  /// Silently swallows network errors — [syncPending] will retry later.
  ///
  /// Ad-hoc logs (one-off supplements not in the user's stack) send their
  /// name and dose inline as metadata instead of a supplement_id reference.
  Future<void> syncLog(SupplementTakenLog log) async {
    try {
      final metadata = log.isAdHoc
          ? {
              'supplement_id': null,
              'supplement_name': log.adHocName,
              if (log.adHocDoseAmount != null) 'dose_amount': log.adHocDoseAmount,
              if (log.adHocDoseUnit != null) 'dose_unit': log.adHocDoseUnit,
            }
          : {'supplement_id': log.supplementId};

      final response = await _client.post('/api/v1/ingest', data: {
        'metric_type': 'supplement_taken',
        'value': 1.0,
        'unit': 'count',
        'source': 'manual',
        'recorded_at': _isoWithOffset(log.recordedAt),
        'metadata': metadata,
      });
      final serverLogId = response.data['event_id'] as String;
      await _localRepo.markSynced(log.id, log.logDate,
          serverLogId: serverLogId);
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
      for (final log
          in _localRepo.getLogsForDate(date).where((l) => !l.synced)) {
        await syncLog(log);
      }
    }
  }
}

final supplementLogSyncServiceProvider = Provider<SupplementLogSyncService>((ref) {
  final service = SupplementLogSyncService(
    localRepo: ref.watch(supplementLogLocalRepositoryProvider),
    client: ref.watch(apiClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
