library;

enum MuscleGroup {
  chest(slug: 'chest', label: 'Chest'),
  back(slug: 'back', label: 'Back'),
  shoulders(slug: 'shoulders', label: 'Shoulders'),
  biceps(slug: 'biceps', label: 'Biceps'),
  triceps(slug: 'triceps', label: 'Triceps'),
  forearms(slug: 'forearms', label: 'Forearms'),
  abs(slug: 'abs', label: 'Abs'),
  quads(slug: 'quads', label: 'Quads'),
  hamstrings(slug: 'hamstrings', label: 'Hamstrings'),
  glutes(slug: 'glutes', label: 'Glutes'),
  calves(slug: 'calves', label: 'Calves'),
  cardio(slug: 'cardio', label: 'Cardio'),
  fullBody(slug: 'full_body', label: 'Full Body'),
  other(slug: 'other', label: 'Other');

  const MuscleGroup({required this.slug, required this.label});

  final String slug;
  final String label;

  static MuscleGroup fromString(String input) {
    for (final group in MuscleGroup.values) {
      if (group.slug == input) return group;
    }
    return MuscleGroup.other;
  }
}

enum Equipment {
  barbell(slug: 'barbell', label: 'Barbell'),
  dumbbell(slug: 'dumbbell', label: 'Dumbbell'),
  cable(slug: 'cable', label: 'Cable'),
  bodyweight(slug: 'bodyweight', label: 'Bodyweight'),
  kettlebell(slug: 'kettlebell', label: 'Kettlebell'),
  machine(slug: 'machine', label: 'Machine'),
  resistanceBand(slug: 'resistance_band', label: 'Resistance Band'),
  ezBar(slug: 'ez_bar', label: 'EZ Bar'),
  other(slug: 'other', label: 'Other');

  const Equipment({required this.slug, required this.label});

  final String slug;
  final String label;

  static Equipment fromString(String input) {
    for (final e in Equipment.values) {
      if (e.slug == input) return e;
    }
    return Equipment.other;
  }
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.instructions,
  });

  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final Equipment equipment;
  final String instructions;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        muscleGroup: MuscleGroup.fromString(json['muscleGroup'] as String? ?? ''),
        equipment: Equipment.fromString(json['equipment'] as String? ?? ''),
        instructions: json['instructions'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Exercise && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
