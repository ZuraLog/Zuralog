/// Zuralog — Supplements Log Screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class SupplementsLogScreen extends ConsumerStatefulWidget {
  const SupplementsLogScreen({super.key});
  @override
  ConsumerState<SupplementsLogScreen> createState() => _SupplementsLogScreenState();
}

class _SupplementsLogScreenState extends ConsumerState<SupplementsLogScreen> {
  final Set<String> _takenIds = {};
  List<SupplementEntry>? _localList;
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;
  bool _showAddForm = false;

  bool get _canSave => !_isSaving && _takenIds.isNotEmpty;
  final _addNameCtrl = TextEditingController();
  final _addDoseCtrl = TextEditingController();
  String _addTiming = 'anytime';

  @override
  void dispose() {
    _notesCtrl.dispose();
    _addNameCtrl.dispose();
    _addDoseCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSupplement() async {
    final name = _addNameCtrl.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(todayRepositoryProvider);
    final currentList = _localList ?? (ref.read(supplementsListProvider).valueOrNull ?? []);
    final optimistic = [
      ...currentList,
      SupplementEntry(
        id: 'optimistic-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        dose: _addDoseCtrl.text.trim().isEmpty ? null : _addDoseCtrl.text.trim(),
        timing: _addTiming,
      ),
    ];
    setState(() { _localList = optimistic; _showAddForm = false; });
    _addNameCtrl.clear();
    _addDoseCtrl.clear();
    try {
      final updated = await repo.updateSupplementsList(optimistic);
      setState(() => _localList = updated);
      ref.invalidate(supplementsListProvider);
    } catch (e) {
      debugPrint('SupplementsLogScreen save failed: $e');
      setState(() => _localList = currentList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save supplement. Please try again.')),
        );
      }
    }
  }

  Future<void> _save(List<SupplementEntry> list) async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(todayRepositoryProvider);
      await repo.logSupplements(
        takenIds: _takenIds.toList(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.invalidate(todayLogSummaryProvider);
          ref.invalidate(progressHomeProvider);
          ref.invalidate(goalsProvider);
        });
      }
    } catch (e) {
      debugPrint('SupplementsLogScreen save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) { setState(() => _isSaving = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final supplementsAsync = ref.watch(supplementsListProvider);
    final list = _localList ?? supplementsAsync.valueOrNull ?? [];

    return ZuralogScaffold(
      appBar: AppBar(title: const Text('Supplements & Meds'), leading: const BackButton()),
      body: Column(
        children: [
          Expanded(
            child: supplementsAsync.isLoading && _localList == null
                ? const Center(child: CircularProgressIndicator.adaptive())
                : list.isEmpty && !_showAddForm
                    ? _EmptyState(onAdd: () => setState(() => _showAddForm = true))
                    : ListView(
                        padding: const EdgeInsets.all(AppDimens.spaceMd),
                        children: [
                          if (list.isNotEmpty)
                            Text('Tap to mark as taken today', style: AppTextStyles.caption.copyWith(color: colors.textTertiary)),
                          const SizedBox(height: AppDimens.spaceSm),
                          for (final s in list)
                            _SupplementRow(
                              supplement: s,
                              isTaken: _takenIds.contains(s.id),
                              onToggle: () => setState(() {
                                if (_takenIds.contains(s.id)) { _takenIds.remove(s.id); } else { _takenIds.add(s.id); }
                              }),
                            ),
                          if (_showAddForm)
                            _AddSupplementForm(
                              nameCtrl: _addNameCtrl,
                              doseCtrl: _addDoseCtrl,
                              timing: _addTiming,
                              onTimingChanged: (t) => setState(() => _addTiming = t),
                              onSave: _addSupplement,
                              onCancel: () => setState(() => _showAddForm = false),
                            )
                          else
                            ZButton(
                              label: 'Add supplement or medication',
                              variant: ZButtonVariant.text,
                              icon: Icons.add,
                              onPressed: () => setState(() => _showAddForm = true),
                              isFullWidth: false,
                            ),
                          const SizedBox(height: AppDimens.spaceLg),
                          ZSectionLabel(label: 'Notes', isOptional: true),
                          const SizedBox(height: AppDimens.spaceSm),
                          ZTextArea(
                            controller: _notesCtrl,
                            placeholder: 'Anything to note about today?',
                            maxLength: 500,
                          ),
                        ],
                      ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, AppDimens.spaceSm + bottomPad),
            child: ZButton(
              label: 'Save',
              onPressed: _canSave ? () => _save(list) : null,
              isLoading: _isSaving,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add your supplements and medications to get started.', textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.spaceLg),
            ZButton(
              label: 'Add supplement or medication',
              icon: Icons.add,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplementRow extends StatelessWidget {
  const _SupplementRow({required this.supplement, required this.isTaken, required this.onToggle});
  final SupplementEntry supplement;
  final bool isTaken;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final subtitleParts = [supplement.dose, supplement.timing]
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toList();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(supplement.name),
      subtitle: subtitleParts.isNotEmpty
          ? Text(
              subtitleParts.join(' · '),
              style: AppTextStyles.caption.copyWith(color: colors.textTertiary),
            )
          : null,
      trailing: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTaken ? colors.primary : Colors.transparent,
            border: Border.all(color: isTaken ? colors.primary : colors.border, width: 2),
          ),
          child: isTaken ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
      ),
    );
  }
}

class _AddSupplementForm extends StatelessWidget {
  const _AddSupplementForm({
    required this.nameCtrl,
    required this.doseCtrl,
    required this.timing,
    required this.onTimingChanged,
    required this.onSave,
    required this.onCancel,
  });
  final TextEditingController nameCtrl;
  final TextEditingController doseCtrl;
  final String timing;
  final ValueChanged<String> onTimingChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: nameCtrl, labelText: 'Name *', hintText: 'e.g. Vitamin D'),
            const SizedBox(height: AppDimens.spaceSm),
            AppTextField(controller: doseCtrl, labelText: 'Dose (optional)', hintText: 'e.g. 1000 IU'),
            const SizedBox(height: AppDimens.spaceSm),
            Wrap(
              spacing: AppDimens.spaceSm,
              children: [
                for (final (value, label) in [('morning', 'Morning'), ('evening', 'Evening'), ('anytime', 'Any time')])
                  ZChip(label: label, isActive: timing == value, onTap: () => onTimingChanged(value)),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ZButton(
                  label: 'Cancel',
                  variant: ZButtonVariant.text,
                  onPressed: onCancel,
                  isFullWidth: false,
                  size: ZButtonSize.small,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                ZButton(
                  label: 'Add',
                  onPressed: onSave,
                  isFullWidth: false,
                  size: ZButtonSize.small,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
