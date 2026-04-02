/// Zuralog — Coach Usage Model.
///
/// Represents the current per-model usage limits for the authenticated user,
/// as returned by GET /api/v1/coach/usage.
library;

import 'package:flutter/foundation.dart';

/// Per-model usage state for the Coach AI.
@immutable
class CoachUsage {
  const CoachUsage({
    required this.flashUsed,
    required this.flashLimit,
    required this.zuraUsed,
    required this.zuraLimit,
    required this.burstUsed,
    required this.burstLimit,
    required this.flashResetSeconds,
    required this.zuraResetSeconds,
    required this.burstResetSeconds,
    required this.tier,
  });

  final int flashUsed;
  final int flashLimit;
  final int zuraUsed;
  final int zuraLimit;
  final int burstUsed;
  final int burstLimit;
  final int flashResetSeconds;
  final int zuraResetSeconds;
  final int burstResetSeconds;
  final String tier;

  /// True when both model buckets are fully used up.
  bool get isFullyExhausted => flashUsed >= flashLimit && zuraUsed >= zuraLimit;

  factory CoachUsage.fromJson(Map<String, dynamic> json) {
    return CoachUsage(
      flashUsed: json['flash_used'] as int? ?? 0,
      flashLimit: json['flash_limit'] as int? ?? 0,
      zuraUsed: json['zura_used'] as int? ?? 0,
      zuraLimit: json['zura_limit'] as int? ?? 0,
      burstUsed: json['burst_used'] as int? ?? 0,
      burstLimit: json['burst_limit'] as int? ?? 0,
      flashResetSeconds: json['flash_reset_seconds'] as int? ?? 0,
      zuraResetSeconds: json['zura_reset_seconds'] as int? ?? 0,
      burstResetSeconds: json['burst_reset_seconds'] as int? ?? 0,
      tier: json['tier'] as String? ?? 'free',
    );
  }
}
