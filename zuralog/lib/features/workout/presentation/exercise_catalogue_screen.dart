library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/shared/widgets/widgets.dart';

class ExerciseCatalogueScreen extends ConsumerStatefulWidget {
  const ExerciseCatalogueScreen({super.key});

  @override
  ConsumerState<ExerciseCatalogueScreen> createState() =>
      _ExerciseCatalogueScreenState();
}

class _ExerciseCatalogueScreenState
    extends ConsumerState<ExerciseCatalogueScreen> {
  @override
  Widget build(BuildContext context) {
    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Add Exercises'),
        leading: const BackButton(),
      ),
      body: const Center(child: Text('Filled in by Task 7.')),
    );
  }
}
