/// Journal Diary Screen — full-screen free-text journal entry.
///
/// Presents a large text field, a horizontal scrollable row of preset tag
/// chips, and a "Save Entry" button. On save the entry is persisted via
/// [progressRepositoryProvider] and the [journalProvider] cache is
/// invalidated so the list screen refreshes automatically.
///
/// Accepts an optional [existingEntry] to pre-populate the form for editing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── JournalDiaryScreen ────────────────────────────────────────────────────────

/// Full-screen diary entry for the Progress > Journal section.
class JournalDiaryScreen extends ConsumerStatefulWidget {
  /// Creates the [JournalDiaryScreen].
  ///
  /// Pass [existingEntry] to open the screen in edit mode with the entry
  /// pre-populated. When null, the screen creates a new entry.
  const JournalDiaryScreen({super.key, this.existingEntry});

  /// The entry to edit. When null, a new entry is created on save.
  final JournalEntry? existingEntry;

  @override
  ConsumerState<JournalDiaryScreen> createState() => _JournalDiaryScreenState();
}

class _JournalDiaryScreenState extends ConsumerState<JournalDiaryScreen> {
  final _contentCtrl = TextEditingController();
  final _contentFocus = FocusNode();
  final _selectedTags = <String>{};
  bool _saving = false;
  // ignore: unused_field — reserved for Task 6 SavingMorph wiring.
  bool _savedOnce = false; // ignore: prefer_final_fields

  static const _presetTags = [
    'Rest day',
    'Gym',
    'Stressful',
    'Traveled',
    'Good mood',
    'Poor sleep',
    'Sick',
    'Social',
    'Productive',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _contentCtrl.text = widget.existingEntry!.content;
      _selectedTags.addAll(widget.existingEntry!.tags);
    }
    _contentFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (widget.existingEntry != null) {
        await ref.read(progressRepositoryProvider).updateJournalEntry(
              entryId: widget.existingEntry!.id,
              content: text,
              tags: _selectedTags.toList(),
            );
      } else {
        await ref.read(progressRepositoryProvider).createJournalEntry(
              date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
              content: text,
              tags: _selectedTags.toList(),
              source: 'diary',
            );
      }
      ref.invalidate(journalProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save entry. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isEditing = widget.existingEntry != null;

    final bottomPad = MediaQuery.paddingOf(context).bottom + 80;

    return ZuralogScaffold(
      appBar: ZuralogAppBar(title: isEditing ? 'Edit Entry' : 'Journal'),
      addBottomNavPadding: true,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          bottomPad,
        ),
        child: Column(
          children: [
            // ── Text field ─────────────────────────────────────────────────
            // Chromeless writing surface — the diary field fills the entire screen top
            // to bottom; a visible outline here would be visual noise. Phase 6 Plan 6
            // reviewed and kept this exception.
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _contentFocus.hasFocus ? 0.06 : 0.0,
                        child: const ZPatternOverlay(
                          variant: ZPatternVariant.amber,
                          opacity: 1.0,
                          animate: true,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _contentCtrl,
                    focusNode: _contentFocus,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.lora(
                      textStyle: AppTextStyles.bodyLarge.copyWith(
                        color: colors.textPrimary,
                        height: 1.55,
                      ),
                    ),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: GoogleFonts.lora(
                        textStyle: AppTextStyles.bodyLarge.copyWith(
                          color: colors.textTertiary,
                          height: 1.55,
                        ),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _WordCountPill(controller: _contentCtrl),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            // ── Tag chips ──────────────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presetTags.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppDimens.spaceSm),
                itemBuilder: (_, i) {
                  final tag = _presetTags[i];
                  final selected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    }),
                  );
                },
              ),
            ),

            const SizedBox(height: AppDimens.spaceMd),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ZButton(
                label: 'Save Entry',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _WordCountPill ──────────────────────────────────────────────────────────

class _WordCountPill extends StatefulWidget {
  const _WordCountPill({required this.controller});
  final TextEditingController controller;

  @override
  State<_WordCountPill> createState() => _WordCountPillState();
}

class _WordCountPillState extends State<_WordCountPill> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _count = _compute(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final next = _compute(widget.controller.text);
    if (next != _count) setState(() => _count = next);
  }

  static int _compute(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Text(
      '$_count words',
      style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary),
    );
  }
}
