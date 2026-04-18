import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class JournalSaveConfirmationSheet extends ConsumerStatefulWidget {
  const JournalSaveConfirmationSheet({
    super.key,
    required this.summary,
    required this.suggestedTags,
    required this.conversationId,
  });

  final String summary;
  final List<String> suggestedTags;
  final String conversationId;

  @override
  ConsumerState<JournalSaveConfirmationSheet> createState() =>
      _JournalSaveConfirmationSheetState();
}

class _JournalSaveConfirmationSheetState
    extends ConsumerState<JournalSaveConfirmationSheet> {
  late final TextEditingController _summaryCtrl;
  late final Set<String> _selectedTags;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController(text: widget.summary);
    _selectedTags = widget.suggestedTags.toSet();
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _summaryCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Entry text cannot be empty.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(progressRepositoryProvider).createJournalEntry(
            date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            content: text,
            tags: _selectedTags.toList(),
            source: 'conversational',
            conversationId: widget.conversationId,
          );
      ref.invalidate(journalProvider);
      if (mounted) {
        Navigator.of(context).pop();
        context.go(RouteNames.progressPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.spaceLg,
        right: AppDimens.spaceLg,
        top: AppDimens.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceLg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review your entry',
              style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            AppTextField(
              controller: _summaryCtrl,
              maxLines: 6,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Wrap(
              spacing: AppDimens.spaceSm,
              children: widget.suggestedTags.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    v ? _selectedTags.add(tag) : _selectedTags.remove(tag);
                  }),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                _error!,
                // colors.accent = Soft Coral, the semantic alert/error token
                style: AppTextStyles.bodySmall.copyWith(color: colors.accent),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: ZButton(
                label: 'Save Entry',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
          ],
        ),
      ),
    );
  }
}
