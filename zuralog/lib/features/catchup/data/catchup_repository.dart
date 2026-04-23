/// Zuralog — Catch-up Status Repository.
///
/// Thin wrapper around GET /api/v1/users/me/catchup_status. Used by the
/// catch-up intro sheet to decide whether to offer the flow to an
/// existing user.
library;

import 'package:zuralog/core/network/api_client.dart';

/// Server response for catch-up status lookups.
class CatchupStatus {
  const CatchupStatus({
    required this.status,
    required this.shouldReoffer,
  });

  /// One of: 'not_shown', 'in_progress', 'completed', 'dismissed'.
  final String status;

  /// True only when [status] == 'dismissed' and >7 days have passed.
  final bool shouldReoffer;

  bool get shouldShowIntro => status == 'not_shown' || shouldReoffer;

  factory CatchupStatus.fromJson(Map<String, dynamic> json) {
    return CatchupStatus(
      status: (json['status'] as String?) ?? 'not_shown',
      shouldReoffer: (json['should_reoffer'] as bool?) ?? false,
    );
  }
}

class CatchupRepository {
  CatchupRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<CatchupStatus> fetchStatus() async {
    final response = await _apiClient.get('/api/v1/users/me/catchup_status');
    return CatchupStatus.fromJson(response.data as Map<String, dynamic>);
  }
}
