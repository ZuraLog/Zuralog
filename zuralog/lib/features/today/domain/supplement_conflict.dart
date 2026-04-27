class SupplementConflict {
  const SupplementConflict({
    required this.hasConflict,
    this.conflictType,
    this.conflictingName,
    this.message,
  });

  final bool hasConflict;

  /// 'duplicate' — exact name match already in stack.
  /// 'overlap' — different name but same active ingredient detected by AI.
  final String? conflictType;

  /// The name of the supplement in the existing stack that conflicts.
  final String? conflictingName;

  /// Human-readable message describing the conflict (may come from the server).
  final String? message;

  factory SupplementConflict.fromJson(Map<String, dynamic> json) =>
      SupplementConflict(
        hasConflict: json['has_conflict'] as bool,
        conflictType: json['conflict_type'] as String?,
        conflictingName: json['conflicting_name'] as String?,
        message: json['message'] as String?,
      );

  static const SupplementConflict none = SupplementConflict(hasConflict: false);
}
