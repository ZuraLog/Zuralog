/// All Data — Health Matrix (placeholder stub).
///
/// The long-form magazine layout was removed here in preparation for
/// the Health Matrix rebuild. The next commit lands the full matrix
/// implementation; this stub exists only to keep the route compiling
/// during the in-progress rewrite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── AllDataScreen ────────────────────────────────────────────────────────────

/// All Data root screen. Being rebuilt as the Health Matrix.
class AllDataScreen extends ConsumerWidget {
  /// Creates the [AllDataScreen].
  const AllDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    return ZuralogScaffold(
      appBar: const ZuralogAppBar(
        title: 'All Data',
        showProfileAvatar: false,
      ),
      body: Center(
        child: Text(
          'Coming up — health matrix',
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
