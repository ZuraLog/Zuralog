/// Journal Screen — date-grouped list of daily well-being journal entries.
///
/// Supports pull-to-refresh, empty state, and opens [JournalEntryRouter] for
/// both creating and editing entries.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/journal_diary_screen.dart';
import 'package:zuralog/features/progress/presentation/journal_entry_router.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/widgets/feedback/z_premium_gate_sheet.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/widgets.dart' show ZSearchBar;
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

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
class JournalScreen extends ConsumerStatefulWidget {
  /// Creates the [JournalScreen].
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(journalProvider);
    await ref.read(journalProvider.future).catchError(
          (Object e, StackTrace _) => const JournalPage(entries: [], hasMore: false),
        );
  }

  void _openNewEntry() {
    ref.read(hapticServiceProvider).light();

    // Free users: gate at 5 journal entries per month.
    // When journal data is still loading, default to the limit (fail-closed).
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      final page = ref.read(journalProvider).valueOrNull;
      final now = DateTime.now();
      final entriesThisMonth = page == null
          ? 5 // fail-closed: gate during loading/error
          : page.entries.where((e) {
              final dt = DateTime.tryParse(e.date);
              return dt != null &&
                  dt.year == now.year &&
                  dt.month == now.month;
            }).length;
      if (entriesThisMonth >= 5) {
        ZPremiumGateSheet.show(
          context,
          headline: 'Journal without limits',
          body: 'Upgrade to Pro for unlimited journal entries each month.',
          icon: Icons.edit_note_rounded,
        );
        return;
      }
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => const JournalEntryRouter(),
    );
  }

  void _openEditEntry(JournalEntry entry) {
    ref.read(hapticServiceProvider).light();
    if (entry.source == 'conversational') {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _EntryDetailSheet(entry: entry),
      );
    } else {
      showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => JournalDiaryScreen(existingEntry: entry),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final journalAsync = ref.watch(journalProvider);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Journal',
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_rounded,
              color: colors.textPrimary,
            ),
            onPressed: _openNewEntry,
          ),
        ],
      ),
      body: journalAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: colors.cardBackground,
          onRefresh: _refresh,
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
                        style: AppTextStyles.titleMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        'Something went wrong. Pull down to try again.',
                        style: AppTextStyles.bodySmall.copyWith(
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
              backgroundColor: colors.cardBackground,
              onRefresh: _refresh,
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
                            style: AppTextStyles.titleMedium.copyWith(
                              color: colors.textPrimary,
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
                          onPressed: _openNewEntry,
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

          // Filter entries based on search query.
          final filteredEntries = page.entries.where((e) {
            if (_searchQuery.isEmpty) return true;
            final contentMatch =
                e.content.toLowerCase().contains(_searchQuery);
            final tagMatch =
                e.tags.any((t) => t.toLowerCase().contains(_searchQuery));
            return contentMatch || tagMatch;
          }).toList();

          final sections = _groupByMonth(filteredEntries);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: colors.cardBackground,
            onRefresh: _refresh,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm,
                  ),
                  child: ZSearchBar(
                    controller: _searchController,
                    placeholder: 'Search journal entries...',
                    onChanged: (query) =>
                        setState(() => _searchQuery = query.toLowerCase()),
                    onClear: () => setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                  ),
                ),
                // Entry list or empty search results
                Expanded(
                  child: filteredEntries.isEmpty && _searchQuery.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              Text(
                                'No results',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spaceSm),
                              Text(
                                'Try a different search term.',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            left: AppDimens.spaceMd,
                            right: AppDimens.spaceMd,
                            bottom: AppDimens.bottomClearance(context),
                          ),
                          itemCount: _sectionItemCount(sections),
                          itemBuilder: (context, index) {
                            final resolved =
                                _resolveIndex(sections, index);
                            if (resolved == null) {
                              return const SizedBox.shrink();
                            }

                            if (resolved.isHeader) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: AppDimens.spaceLg,
                                  bottom: AppDimens.spaceSm,
                                ),
                                child: Text(
                                  resolved.header!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textTertiary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              );
                            }

                            final entry = resolved.entry!;
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppDimens.spaceSm),
                              child: _EntryCard(
                                entry: entry,
                                onTap: () => _openEditEntry(entry),
                              ),
                            );
                          },
                        ),
                ),
              ],
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

// ── Entry Detail Sheet ────────────────────────────────────────────────────────

/// Read-only bottom sheet shown when tapping a conversational entry.
class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.date,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              entry.content,
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Wrap(
                spacing: AppDimens.spaceSm,
                children: entry.tags
                    .map((t) => Chip(label: Text(t)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Entry Card ────────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  IconData _sourceIcon(String source) {
    if (source == 'conversational') return Icons.chat_bubble_outline;
    return Icons.edit_note;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: date + source icon ───────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    _shortDate(entry.date),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _sourceIcon(entry.source),
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),

            // ── Content preview ───────────────────────────────────────────
            if (entry.content.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                entry.content,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

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
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        backgroundColor: colors.surface,
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
          ],
        ),
      ),
    );
  }
}
