/// Journal Screen — date-grouped list of daily well-being journal entries.
///
/// Supports pull-to-refresh, empty state, and opens [JournalEntrySheet] for
/// both creating and editing entries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/journal_entry_sheet.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _moodEmoji(int mood) {
  if (mood <= 2) return '😞';
  if (mood <= 4) return '😕';
  if (mood <= 6) return '😐';
  if (mood <= 8) return '😊';
  return '😄';
}

Color _levelColor(int value) {
  if (value <= 3) return AppColors.statusError;
  if (value <= 6) return AppColors.categoryNutrition;
  return AppColors.categoryActivity;
}

String _monthLabel(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate);
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return isoDate;
  }
}

String _shortDate(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    // DateTime.weekday: 1=Mon … 7=Sun
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, $monthName ${dt.day}';
  } catch (_) {
    return isoDate;
  }
}

/// Groups entries by their "Month YYYY" header string.
List<_JournalSection> _groupByMonth(List<JournalEntry> entries) {
  final Map<String, List<JournalEntry>> groups = {};
  for (final entry in entries) {
    final key = _monthLabel(entry.date);
    groups.putIfAbsent(key, () => []).add(entry);
  }
  return groups.entries
      .map((e) => _JournalSection(header: e.key, entries: e.value))
      .toList();
}

class _JournalSection {
  _JournalSection({required this.header, required this.entries});
  final String header;
  final List<JournalEntry> entries;
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Journal screen — date-grouped list of daily check-in entries.
class JournalScreen extends ConsumerWidget {
  /// Creates the [JournalScreen].
  const JournalScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(journalProvider);
    await ref.read(journalProvider.future).catchError(
          (_) => const JournalPage(entries: [], hasMore: false),
        );
  }

  void _openNewEntry(BuildContext context, WidgetRef ref) {
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const JournalEntrySheet(),
    );
  }

  void _openEditEntry(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
  ) {
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntrySheet(initialEntry: entry),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalAsync = ref.watch(journalProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimaryDark,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: Text('Journal', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_rounded,
              color: AppColors.textPrimaryDark,
            ),
            onPressed: () => _openNewEntry(context, ref),
          ),
        ],
      ),
      body: journalAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardBackgroundDark,
          onRefresh: () => _refresh(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.statusError,
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        'Failed to load journal',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        err.toString(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        data: (page) {
          if (page.entries.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.cardBackgroundDark,
              onRefresh: () => _refresh(ref),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.book_outlined,
                          size: 56,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        Text(
                          'No entries yet',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        Text(
                          'Capture how you feel each day.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceLg),
                        FilledButton(
                          onPressed: () => _openNewEntry(context, ref),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.primaryButtonText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
                            ),
                          ),
                          child: const Text('Log your first day'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final sections = _groupByMonth(page.entries);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.cardBackgroundDark,
            onRefresh: () => _refresh(ref),
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: AppDimens.spaceMd,
                right: AppDimens.spaceMd,
                bottom: AppDimens.bottomClearance(context),
              ),
              itemCount: _sectionItemCount(sections),
              itemBuilder: (context, index) {
                final resolved = _resolveIndex(sections, index);
                if (resolved == null) return const SizedBox.shrink();

                if (resolved.isHeader) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimens.spaceLg,
                      bottom: AppDimens.spaceSm,
                    ),
                    child: Text(
                      resolved.header!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  );
                }

                final entry = resolved.entry!;
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppDimens.spaceSm),
                  child: _EntryCard(
                    entry: entry,
                    onTap: () => _openEditEntry(context, ref, entry),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  int _sectionItemCount(List<_JournalSection> sections) {
    int count = 0;
    for (final s in sections) {
      count += 1 + s.entries.length; // header + entries
    }
    return count;
  }

  _ResolvedItem? _resolveIndex(
    List<_JournalSection> sections,
    int index,
  ) {
    int offset = 0;
    for (final section in sections) {
      if (index == offset) {
        return _ResolvedItem.header(section.header);
      }
      offset++;
      final entryIndex = index - offset;
      if (entryIndex < section.entries.length) {
        return _ResolvedItem.entry(section.entries[entryIndex]);
      }
      offset += section.entries.length;
    }
    return null;
  }
}

class _ResolvedItem {
  _ResolvedItem.header(this.header)
      : isHeader = true,
        entry = null;
  _ResolvedItem.entry(this.entry)
      : isHeader = false,
        header = null;

  final bool isHeader;
  final String? header;
  final JournalEntry? entry;
}

// ── Entry Card ────────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: date + mood ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    _shortDate(entry.date),
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ),
                Text(
                  '${_moodEmoji(entry.mood)} ${entry.mood}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // ── Energy + stress dots ──────────────────────────────────────
            Row(
              children: [
                _MiniIndicator(
                  label: 'Energy',
                  value: entry.energy,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                _MiniIndicator(
                  label: 'Stress',
                  value: entry.stress,
                ),
              ],
            ),

            // ── Tags ──────────────────────────────────────────────────────
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Wrap(
                spacing: AppDimens.spaceXs,
                runSpacing: AppDimens.spaceXs,
                children: entry.tags
                    .map(
                      (tag) => Chip(
                        label: Text(
                          tag,
                          style: AppTextStyles.labelXs.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        backgroundColor: AppColors.surfaceDark,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
            ],

            // ── Notes preview ─────────────────────────────────────────────
            if (entry.notes.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                entry.notes,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniIndicator extends StatelessWidget {
  const _MiniIndicator({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _levelColor(value),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          '$label $value',
          style: AppTextStyles.labelXs.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
