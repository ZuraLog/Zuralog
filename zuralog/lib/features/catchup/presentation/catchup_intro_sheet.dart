/// Zuralog — Catch-up Intro Sheet.
///
/// Shown once on app open for existing users whose profile predates the
/// extended-profile questions. Offers a short catch-up flow ("Let's do it")
/// or a graceful dismiss ("Maybe later").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/catchup/presentation/catchup_flow_screen.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Show the catch-up intro sheet as a modal bottom sheet.
/// Returns once the user picks an option.
Future<void> showCatchupIntroSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Route up to the root navigator — go_router wraps routes with
    // shell navigators that showModalBottomSheet can't always resolve
    // against from within the Today tab.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CatchupIntroSheet(),
  );
}

class _CatchupIntroSheet extends ConsumerWidget {
  const _CatchupIntroSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppDimens.spaceLg),
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Let's get to know you better",
              style: AppTextStyles.titleLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              "I just learned a few new ways to be actually useful to you. "
              "Got 30 seconds for five quick questions?",
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            PrimaryButton(
              label: "Let's do it",
              onPressed: () {
                // Pop the sheet first, then push the flow from the parent
                // navigator. Don't touch ref after pop — the sheet widget
                // is disposed the moment we leave this callback.
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(
                  builder: (_) => const CatchupFlowScreen(),
                ));
              },
            ),
            const SizedBox(height: AppDimens.spaceSm),
            SecondaryButton(
              label: 'Maybe later',
              onPressed: () async {
                // PATCH first (ref is alive), then pop the sheet.
                try {
                  await ref
                      .read(userProfileProvider.notifier)
                      .update(profileCatchupStatus: 'dismissed');
                } catch (_) {
                  // Non-fatal — sheet closes regardless.
                }
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
