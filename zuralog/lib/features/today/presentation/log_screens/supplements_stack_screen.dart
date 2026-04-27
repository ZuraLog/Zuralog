/// Zuralog — Supplement Stack Management Screen.
///
/// Full-screen route for managing the user's permanent supplement and
/// medication stack. Supports add, edit, reorder, and swipe-to-delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Option constants ──────────────────────────────────────────────────────────

const _kUnitOptions = ['mg', 'mcg', 'IU', 'g', 'ml', 'other'];
const _kFormOptions = ['Tablet', 'Capsule', 'Softgel', 'Powder', 'Liquid', 'Other'];
const _kTimingOptions = ['Morning', 'With lunch', 'Evening', 'With meal', 'Anytime'];
const _kTimingValues = ['morning', 'with_lunch', 'evening', 'with_meal', 'anytime'];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-screen route for managing the user's supplement and medication stack.
class SupplementsStackScreen extends ConsumerStatefulWidget {
  const SupplementsStackScreen({
    super.key,
    this.openAddFormOnStart = false,
  });

  /// When `true`, the Add form is opened immediately after the first build.
  final bool openAddFormOnStart;

  @override
  ConsumerState<SupplementsStackScreen> createState() =>
      _SupplementsStackScreenState();
}

class _SupplementsStackScreenState
    extends ConsumerState<SupplementsStackScreen> {
  // Whether the add/edit form is visible
  bool _showForm = false;
  // If non-null, we're editing; otherwise adding
  SupplementEntry? _editingEntry;
  // Local mutable copy of the list for reordering
  List<SupplementEntry>? _localList;
  // Guards one-time seeding of _localList from server data
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAddFormOnStart) {
      // Open form after first frame so we have a BuildContext
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showForm = true);
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _openAddForm() {
    setState(() {
      _editingEntry = null;
      _showForm = true;
    });
  }

  void _openEditForm(SupplementEntry entry) {
    setState(() {
      _editingEntry = entry;
      _showForm = true;
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingEntry = null;
    });
  }

  Future<void> _saveEntry(SupplementEntry entry) async {
    final current = List<SupplementEntry>.from(_localList ?? []);
    final List<SupplementEntry> updated;
    if (_editingEntry != null) {
      // Replace existing entry
      updated = current
          .map((e) => e.id == _editingEntry!.id ? entry : e)
          .toList();
    } else {
      // Add new entry
      updated = [...current, entry];
    }
    try {
      final repo = ref.read(todayRepositoryProvider);
      final saved = await repo.updateSupplementsList(updated);
      if (mounted) {
        setState(() => _localList = saved);
        ref.invalidate(supplementsListProvider);
        _closeForm();
      }
    } catch (e) {
      debugPrint('SupplementsStackScreen save failed: $e');
      if (mounted) {
        ZToast.error(context, 'Could not save. Please try again.');
      }
    }
  }

  Future<void> _confirmDelete(SupplementEntry entry) async {
    final confirmed = await ZAlertDialog.show(
      context,
      title: 'Remove supplement?',
      body: '"${entry.name}" will be removed from your stack.',
      confirmLabel: 'Remove',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      await _deleteEntry(entry);
    }
  }

  Future<void> _deleteEntry(SupplementEntry entry) async {
    final current = List<SupplementEntry>.from(_localList ?? []);
    final updated = current.where((e) => e.id != entry.id).toList();
    try {
      final repo = ref.read(todayRepositoryProvider);
      final saved = await repo.updateSupplementsList(updated);
      if (mounted) {
        setState(() => _localList = saved);
        ref.invalidate(supplementsListProvider);
      }
    } catch (e) {
      debugPrint('SupplementsStackScreen delete failed: $e');
      if (mounted) {
        ZToast.error(context, 'Could not remove. Please try again.');
      }
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex, List<SupplementEntry> list) async {
    final updated = List<SupplementEntry>.from(list);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _localList = updated);
    try {
      final repo = ref.read(todayRepositoryProvider);
      final saved = await repo.updateSupplementsList(updated);
      if (mounted) {
        setState(() => _localList = saved);
        ref.invalidate(supplementsListProvider);
      }
    } catch (e) {
      debugPrint('SupplementsStackScreen reorder failed: $e');
      if (mounted) {
        ZToast.error(context, 'Could not save order. Please try again.');
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final supplementsAsync = ref.watch(supplementsListProvider);

    return supplementsAsync.when(
      loading: () => ZuralogScaffold(
        appBar: AppBar(
          title: const Text('My Supplement Stack'),
          leading: const BackButton(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ZuralogScaffold(
        appBar: AppBar(
          title: const Text('My Supplement Stack'),
          leading: const BackButton(),
        ),
        body: const Center(child: Text('Could not load supplements.')),
      ),
      data: (serverList) {
        // Seed local list on first data arrival — safe inside build because
        // no setState is called; we just set the field directly before the
        // first frame is painted.
        if (!_seeded) {
          _seeded = true;
          _localList = List.from(serverList);
        }
        final list = _localList ?? serverList;

        if (_showForm) {
          return ZuralogScaffold(
            appBar: AppBar(
              title: Text(_editingEntry == null ? 'Add Supplement' : 'Edit Supplement'),
              leading: BackButton(onPressed: _closeForm),
            ),
            body: _AddEditForm(
              existing: _editingEntry,
              onSave: _saveEntry,
              onCancel: _closeForm,
            ),
          );
        }

        return ZuralogScaffold(
          appBar: AppBar(
            title: const Text('My Supplement Stack'),
            leading: const BackButton(),
          ),
          body: _StackBody(
            supplements: list,
            onAdd: _openAddForm,
            onEdit: _openEditForm,
            onDelete: _confirmDelete,
            onReorder: (oldIndex, newIndex) => _reorder(oldIndex, newIndex, list),
          ),
        );
      },
    );
  }
}

// ── Stack Body ────────────────────────────────────────────────────────────────

class _StackBody extends StatelessWidget {
  const _StackBody({
    required this.supplements,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<SupplementEntry> supplements;
  final VoidCallback onAdd;
  final ValueChanged<SupplementEntry> onEdit;
  final ValueChanged<SupplementEntry> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: supplements.isEmpty
              ? _EmptyState(onAdd: onAdd)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(
                    top: AppDimens.spaceMd,
                    bottom: AppDimens.spaceMd,
                  ),
                  itemCount: supplements.length,
                  onReorder: onReorder,
                  itemBuilder: (context, index) {
                    final entry = supplements[index];
                    return _SupplementRow(
                      key: ValueKey(entry.id),
                      index: index,
                      entry: entry,
                      onEdit: () => onEdit(entry),
                      onDelete: () => onDelete(entry),
                    );
                  },
                ),
        ),
        // Add button pinned at bottom
        Container(
          color: colors.surface,
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceSm + bottomPad,
          ),
          child: ZButton(
            label: 'Add supplement or med',
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 48,
              color: colors.textSecondary,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'No supplements yet',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Add the supplements and meds you take regularly.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supplement Row ────────────────────────────────────────────────────────────

class _SupplementRow extends StatelessWidget {
  const _SupplementRow({
    super.key,
    required this.index,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final SupplementEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _subtitle() {
    final parts = <String>[];
    if (entry.doseAmount != null) {
      final amount = entry.doseAmount! % 1 == 0
          ? entry.doseAmount!.toInt().toString()
          : entry.doseAmount!.toString();
      final unit = entry.doseUnit ?? '';
      parts.add('$amount$unit'.trim());
    }
    if (entry.form != null) parts.add(entry.form!);
    if (entry.timing != null) {
      // Convert internal value to display label
      final idx = _kTimingValues.indexOf(entry.timing!);
      final label = idx >= 0 ? _kTimingOptions[idx] : entry.timing!;
      parts.add(label);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final subtitle = _subtitle();

    return Dismissible(
      key: ValueKey('dismissible_${entry.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion ourselves via the confirm dialog
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.spaceLg),
        color: colors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        onTap: onEdit,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        title: Text(
          entry.name,
          style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              )
            : null,
        trailing: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Add / Edit Form ────────────────────────────────────────────────────────────

class _AddEditForm extends StatefulWidget {
  const _AddEditForm({
    this.existing,
    required this.onSave,
    required this.onCancel,
  });

  final SupplementEntry? existing;
  final Future<void> Function(SupplementEntry entry) onSave;
  final VoidCallback onCancel;

  @override
  State<_AddEditForm> createState() => _AddEditFormState();
}

class _AddEditFormState extends State<_AddEditForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  String? _selectedUnit;
  String? _selectedForm;
  String? _selectedTiming;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
      text: e?.doseAmount != null
          ? (e!.doseAmount! % 1 == 0
              ? e.doseAmount!.toInt().toString()
              : e.doseAmount!.toString())
          : '',
    );
    _selectedUnit = e?.doseUnit;
    _selectedForm = e?.form;
    _selectedTiming = e != null
        ? (() {
            final idx = _kTimingValues.indexOf(e.timing ?? '');
            return idx >= 0 ? _kTimingOptions[idx] : null;
          })()
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && !_isSaving;

  Future<void> _submit() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    final timingIdx = _selectedTiming != null
        ? _kTimingOptions.indexOf(_selectedTiming!)
        : -1;
    final timingValue = timingIdx >= 0 ? _kTimingValues[timingIdx] : null;

    final amountRaw = double.tryParse(_amountCtrl.text.trim());

    final entry = SupplementEntry(
      id: widget.existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      doseAmount: amountRaw,
      doseUnit: _selectedUnit,
      form: _selectedForm,
      timing: timingValue,
    );

    try {
      await widget.onSave(entry);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field
                ZLabeledTextField(
                  label: 'Name',
                  controller: _nameCtrl,
                  hint: 'e.g. Vitamin D, Magnesium',
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppDimens.spaceLg),

                // Amount field
                ZLabeledNumberField(
                  label: 'Amount',
                  controller: _amountCtrl,
                  allowDecimal: true,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppDimens.spaceLg),

                // Unit grid
                _OptionGrid(
                  sectionLabel: 'Unit',
                  options: _kUnitOptions,
                  selected: _selectedUnit,
                  onSelect: (v) => setState(
                      () => _selectedUnit = v == _selectedUnit ? null : v),
                ),
                const SizedBox(height: AppDimens.spaceLg),

                // Form grid
                _OptionGrid(
                  sectionLabel: 'Form',
                  options: _kFormOptions,
                  selected: _selectedForm,
                  onSelect: (v) => setState(
                      () => _selectedForm = v == _selectedForm ? null : v),
                ),
                const SizedBox(height: AppDimens.spaceLg),

                // Timing grid
                _OptionGrid(
                  sectionLabel: 'Timing',
                  options: _kTimingOptions,
                  selected: _selectedTiming,
                  onSelect: (v) => setState(
                      () => _selectedTiming = v == _selectedTiming ? null : v),
                ),
                const SizedBox(height: AppDimens.spaceLg),
              ],
            ),
          ),
        ),
        // Save / Cancel buttons
        Container(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceSm + bottomPad,
          ),
          child: Column(
            children: [
              ZButton(
                label: widget.existing == null ? 'Add to stack' : 'Save changes',
                onPressed: _canSave ? _submit : null,
                isLoading: _isSaving,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              ZButton(
                label: 'Cancel',
                variant: ZButtonVariant.text,
                onPressed: widget.onCancel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Option Grid ───────────────────────────────────────────────────────────────

/// 2-column option grid. If count is odd, last item spans full width.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.sectionLabel,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String sectionLabel;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Build rows: pair items; last item spans full width if count is odd
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      final isLastOddItem = i + 1 >= options.length;
      if (isLastOddItem) {
        // Full-width last item
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              top: i > 0 ? AppDimens.spaceXs : 0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: _OptionChip(
                label: options[i],
                isSelected: selected == options[i],
                onTap: () => onSelect(options[i]),
              ),
            ),
          ),
        );
      } else {
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              top: i > 0 ? AppDimens.spaceXs : 0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _OptionChip(
                    label: options[i],
                    isSelected: selected == options[i],
                    onTap: () => onSelect(options[i]),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Expanded(
                  child: _OptionChip(
                    label: options[i + 1],
                    isSelected: selected == options[i + 1],
                    onTap: () => onSelect(options[i + 1]),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionLabel,
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        ...rows,
      ],
    );
  }
}

// ── Option Chip ───────────────────────────────────────────────────────────────

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? colors.textOnSage : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
