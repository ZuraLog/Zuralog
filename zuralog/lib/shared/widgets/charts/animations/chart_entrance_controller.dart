library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Mixin that drives a 0.0 → 1.0 entrance animation for chart widgets.
///
/// Mix into a [State] that also mixes in [SingleTickerProviderStateMixin].
/// Override [entranceKey] to return an identity-compared object (typically
/// the chart config). When the key changes, the entrance replays.
mixin ChartEntranceController<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _curvedEntrance;
  Object? _lastKey;

  /// Return an identity-compared key. When this changes, the entrance replays.
  Object get entranceKey;

  /// Current entrance progress (0.0 to 1.0).
  double get animationProgress => _curvedEntrance.value;

  /// Whether the entrance animation has completed.
  bool get entranceComplete => _entranceCtrl.isCompleted;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _curvedEntrance = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    )..addListener(() => setState(() {}));
    SchedulerBinding.instance.addPostFrameCallback((_) => _maybePlay());
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  void _maybePlay() {
    final key = entranceKey;
    if (identical(key, _lastKey)) return;
    _lastKey = key;

    if (MediaQuery.of(context).disableAnimations) {
      _entranceCtrl.value = 1.0;
    } else {
      _entranceCtrl
        ..reset()
        ..forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }
}
