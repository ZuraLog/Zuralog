/// Zuralog — Log Sheet Callback Provider.
///
/// Holds the callback that opens the log grid sheet from AppShell.
/// TodayFeedScreen reads this to wire the FAB onPressed.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callback set by AppShell that opens the log grid sheet.
/// Null until AppShell initialises.
final logSheetCallbackProvider = StateProvider<VoidCallback?>((ref) => null);
