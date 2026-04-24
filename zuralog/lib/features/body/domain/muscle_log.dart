library;

import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

class MuscleLog {
  const MuscleLog({
    required this.muscleGroup,
    required this.state,
    required this.logDate,
    required this.loggedAtTime,
    this.synced = false,
  });

  final MuscleGroup muscleGroup;
  final MuscleState state;

  /// ISO date string: 'YYYY-MM-DD'
  final String logDate;

  /// 24-hour time string: 'HH:mm'
  final String loggedAtTime;

  final bool synced;

  Map<String, dynamic> toJson() => {
        'muscleGroup': muscleGroup.slug,
        'state': state.slug,
        'logDate': logDate,
        'loggedAtTime': loggedAtTime,
        'synced': synced,
      };

  factory MuscleLog.fromJson(Map<String, dynamic> json) => MuscleLog(
        muscleGroup: MuscleGroup.fromString(json['muscleGroup'] as String),
        state: MuscleState.fromSlug(json['state'] as String),
        logDate: json['logDate'] as String,
        loggedAtTime: json['loggedAtTime'] as String,
        synced: (json['synced'] as bool?) ?? false,
      );

  MuscleLog copyWith({
    MuscleGroup? muscleGroup,
    MuscleState? state,
    String? logDate,
    String? loggedAtTime,
    bool? synced,
  }) =>
      MuscleLog(
        muscleGroup: muscleGroup ?? this.muscleGroup,
        state: state ?? this.state,
        logDate: logDate ?? this.logDate,
        loggedAtTime: loggedAtTime ?? this.loggedAtTime,
        synced: synced ?? this.synced,
      );
}
