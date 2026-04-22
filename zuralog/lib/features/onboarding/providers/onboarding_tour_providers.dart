// State for the onboarding product tour.
//
// Persists which pillars the user selects during the tour so Phase 3
// (personalization) can pre-populate the goals step.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pillars the user taps during the intent-select screen.
/// Defaults to all four main pillars so the tour shows everything.
final selectedTourPillarsProvider =
    StateProvider<List<String>>((ref) => ['heart', 'sleep', 'workout', 'nutrients']);
