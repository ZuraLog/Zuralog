/// All Data — long-form magazine spread across every health category.
///
/// Placeholder stub. The full magazine body lands in the follow-up
/// commit. This file is intentionally lightweight so the route + pill
/// button can ship without pulling in the rest of the work.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/shared/widgets/widgets.dart';

/// The All Data screen — renders every metric across every category in
/// one long, editorial scroll.
class AllDataScreen extends StatelessWidget {
  /// Creates the [AllDataScreen].
  const AllDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ZuralogScaffold(
      appBar: ZuralogAppBar(title: 'All Data'),
      body: Center(child: Text('Coming soon')),
    );
  }
}
