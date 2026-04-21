/// Related Journal section for the Goal Detail page.
///
/// Filters the user's journal entries by keyword match on the goal's
/// title and shows up to 3 most-recent matches. Hidden when no matches.
///
/// Backend follow-up: a journal_entries.related_goal_ids FK would replace
/// the keyword match. Until then, this is a heuristic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_visuals.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

class GoalRelatedJournal extends ConsumerWidget {
  const GoalRelatedJournal({super.key, required this.goal});

  final Goal goal;

  static const _stopwords = {
    'a', 'the', 'an', 'of', 'and', 'or', 'to', 'in',
    'daily', 'weekly', 'monthly', 'goal', 'target', 'my', 'your',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final visuals = goalVisuals(goal);
    final lighter =
        Color.lerp(Colors.white, visuals.color, 0.6) ?? visuals.color;
    final asyncPage = ref.watch(journalProvider);

    return asyncPage.when(
      data: (page) {
        final tokens = _tokens(goal.title);
        final matches = _filter(page.entries, tokens).take(3).toList();
        if (matches.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: Text(
                'RELATED JOURNAL',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final e in matches)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Entry(
                  entry: e,
                  accent: visuals.color,
                  lighter: lighter,
                ),
              ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static Iterable<String> _tokens(String title) sync* {
    for (final raw in title.toLowerCase().split(RegExp(r'\s+'))) {
      final t = raw.trim();
      if (t.isEmpty || _stopwords.contains(t)) continue;
      yield t;
    }
  }

  static List<JournalEntry> _filter(
    List<JournalEntry> entries,
    Iterable<String> tokens,
  ) {
    final tokenList = tokens.toList();
    if (tokenList.isEmpty) return [];
    return entries.where((e) {
      final body = e.content.toLowerCase();
      return tokenList.any((t) => body.contains(t));
    }).toList();
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.entry,
    required this.accent,
    required this.lighter,
  });
  final JournalEntry entry;
  final Color accent;
  final Color lighter;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              _shortDate(entry.date),
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusButton),
            ),
            child: Text(
              'goal',
              style: AppTextStyles.labelSmall.copyWith(
                color: lighter,
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
