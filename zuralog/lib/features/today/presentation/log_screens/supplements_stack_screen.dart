/// Zuralog — Supplement Stack Management Screen.
///
/// Full-screen route for managing the user's permanent supplement and
/// medication stack. Supports add, edit, reorder, and swipe-to-delete.
library;

import 'dart:async' show Timer;
import 'dart:convert' show base64Encode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/today/domain/supplement_conflict.dart';
import 'package:zuralog/features/today/domain/timing_suggestion.dart';
import 'package:zuralog/features/today/domain/supplement_scan_result.dart';
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
        setState(() {
          _localList = saved;
          _seeded = false;
        });
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
        setState(() {
          _localList = saved;
          _seeded = false;
        });
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
        setState(() {
          _localList = saved;
          _seeded = false;
        });
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
              existingSupplements: _localList ?? [],
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

class _AddEditForm extends ConsumerStatefulWidget {
  const _AddEditForm({
    this.existing,
    required this.onSave,
    required this.onCancel,
    required this.existingSupplements,
  });

  final SupplementEntry? existing;
  final Future<void> Function(SupplementEntry entry) onSave;
  final VoidCallback onCancel;
  final List<SupplementEntry> existingSupplements;

  @override
  ConsumerState<_AddEditForm> createState() => _AddEditFormState();
}

class _AddEditFormState extends ConsumerState<_AddEditForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  String? _selectedUnit;
  String? _selectedForm;
  String? _selectedTiming;
  bool _isSaving = false;

  TimingSuggestion? _timingSuggestion;
  bool _isLoadingTip = false;

  SupplementConflict? _conflict;
  bool _conflictAcknowledged = false;
  Timer? _conflictDebounce;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _nameCtrl.addListener(_onNameChanged);
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
    _conflictDebounce?.cancel();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _conflictAcknowledged = false;
      _conflict = null;
    });
    _conflictDebounce?.cancel();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    _conflictDebounce = Timer(
      const Duration(milliseconds: 800),
      () => _checkConflict(name),
    );
  }

  Future<void> _checkConflict(String name) async {
    final others = widget.existingSupplements
        .where((e) => e.id != (widget.existing?.id ?? ''))
        .toList();
    if (others.isEmpty) return;

    // Client-side exact match — no API call needed
    final lowerName = name.toLowerCase().trim();
    final exactMatch = others.firstWhere(
      (e) => e.name.toLowerCase().trim() == lowerName,
      orElse: () => const SupplementEntry(id: '', name: ''),
    );
    if (exactMatch.id.isNotEmpty) {
      if (mounted) {
        setState(() {
          _conflict = SupplementConflict(
            hasConflict: true,
            conflictType: 'duplicate',
            conflictingName: exactMatch.name,
            message: null,
          );
        });
      }
      return;
    }

    // API call for semantic overlap
    if (!mounted) return;
    try {
      final result = await ref.read(todayRepositoryProvider).checkSupplementConflicts(
            name: name,
            existingNames: others.map((e) => e.name).toList(),
            excludeId: widget.existing?.id,
          );
      if (mounted) {
        setState(() => _conflict = result);
      }
    } catch (_) {
      // Silently ignore — conflict check is advisory, not blocking
    }
  }

  Future<void> _fetchTimingTip(String timingLabel) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final idx = _kTimingOptions.indexOf(timingLabel);
    final timingValue =
        idx >= 0 ? _kTimingValues[idx] : timingLabel.toLowerCase();

    if (!mounted) return;
    setState(() {
      _isLoadingTip = true;
      _timingSuggestion = null;
    });

    try {
      final suggestion = await ref
          .read(todayRepositoryProvider)
          .getTimingSuggestion(
            supplementName: name,
            timing: timingValue,
          );
      if (mounted) {
        setState(() {
          _timingSuggestion = suggestion;
          _isLoadingTip = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTip = false);
    }
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && !_isSaving;

  Future<void> _openScanSheet() async {
    final result = await _ScanLabelSheet.show(context);
    if (result == null || !mounted) return;
    setState(() {
      if (result.name != null) _nameCtrl.text = result.name!;
      if (result.doseAmount != null) {
        _amountCtrl.text = result.doseAmount! % 1 == 0
            ? result.doseAmount!.toStringAsFixed(0)
            : result.doseAmount!.toStringAsFixed(1);
      }
      if (result.doseUnit != null) _selectedUnit = result.doseUnit;
      if (result.form != null) {
        final scannedForm = result.form!;
        _selectedForm = _kFormOptions.firstWhere(
          (f) => f.toLowerCase() == scannedForm.toLowerCase(),
          orElse: () => scannedForm,
        );
      }
    });
  }

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
                // Scan label button
                GestureDetector(
                  onTap: _openScanSheet,
                  child: Builder(
                    builder: (context) {
                      final colors = AppColorsOf(context);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceSm,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
                          border: Border.all(
                              color: colors.border.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppDimens.spaceXs),
                            Text(
                              'Scan label',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                // Name field
                ZLabeledTextField(
                  label: 'Name',
                  controller: _nameCtrl,
                  hint: 'e.g. Vitamin D, Magnesium',
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                ),
                if (_conflict != null && _conflict!.hasConflict && !_conflictAcknowledged) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  _ConflictWarningCard(
                    conflict: _conflict!,
                    onAdjustDose: () {
                      setState(() => _conflictAcknowledged = true);
                      _amountCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _amountCtrl.text.length),
                      );
                      FocusScope.of(context).nextFocus();
                    },
                    onAddAnyway: () => setState(() => _conflictAcknowledged = true),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                ],
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
                  onSelect: (v) {
                    final newVal = _selectedTiming == v ? null : v;
                    setState(() {
                      _selectedTiming = newVal;
                      if (newVal == null) _timingSuggestion = null;
                    });
                    if (newVal != null) _fetchTimingTip(newVal);
                  },
                ),
                // Loading bar while tip is being fetched
                if (_isLoadingTip) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  const LinearProgressIndicator(),
                ],
                // Tip card
                if (_timingSuggestion != null &&
                    _timingSuggestion!.hasTip &&
                    !_isLoadingTip) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  ZAlertBanner(
                    variant: ZAlertVariant.info,
                    message: _timingSuggestion!.tip!,
                    onDismiss: () => setState(() => _timingSuggestion = null),
                  ),
                ],
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

// ── Scan Label Sheet ──────────────────────────────────────────────────────────

class _ScanLabelSheet extends ConsumerStatefulWidget {
  const _ScanLabelSheet();

  static Future<SupplementScanResult?> show(BuildContext context) {
    return showModalBottomSheet<SupplementScanResult>(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ScanLabelSheet(),
    );
  }

  @override
  ConsumerState<_ScanLabelSheet> createState() => _ScanLabelSheetState();
}

class _ScanLabelSheetState extends ConsumerState<_ScanLabelSheet> {
  bool _showBarcodeScanner = false;
  bool _isLoading = false;
  String? _error;
  bool _scanned = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (xFile == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bytes = await xFile.readAsBytes();
      final base64 = base64Encode(bytes);
      final result = await ref.read(todayRepositoryProvider).scanSupplementLabel(
            imageBase64: base64,
          );
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not read label. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_scanned) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _scanned = true;
    setState(() {
      _showBarcodeScanner = false;
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(todayRepositoryProvider).scanSupplementLabel(
            barcode: code,
          );
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanned = false;
          _error = 'Could not look up barcode. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: EdgeInsets.only(
        left: AppDimens.spaceMd,
        right: AppDimens.spaceMd,
        top: AppDimens.spaceMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceLg,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceOverlay,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.shapeXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Scan label',
            style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(AppDimens.spaceLg),
              child: CircularProgressIndicator.adaptive(),
            )
          else if (_showBarcodeScanner)
            _BarcodeScannerView(
              onDetect: _handleBarcode,
              onClose: () => setState(() => _showBarcodeScanner = false),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _ScanOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _ScanOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Photos',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _ScanOption(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Barcode',
                    onTap: () => setState(() => _showBarcodeScanner = true),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: colors.error),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Scan Option ───────────────────────────────────────────────────────────────

class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.textSecondary),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barcode Scanner View ──────────────────────────────────────────────────────

class _BarcodeScannerView extends StatefulWidget {
  const _BarcodeScannerView({required this.onDetect, required this.onClose});

  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onClose;

  @override
  State<_BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<_BarcodeScannerView> {
  late final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        color: Colors.black,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: widget.onDetect),
          Positioned(
            top: AppDimens.spaceSm,
            right: AppDimens.spaceSm,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.all(AppDimens.spaceXs),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
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

// ── Conflict Warning Card ─────────────────────────────────────────────────────

class _ConflictWarningCard extends StatelessWidget {
  const _ConflictWarningCard({
    required this.conflict,
    required this.onAdjustDose,
    required this.onAddAnyway,
  });

  final SupplementConflict conflict;
  final VoidCallback onAdjustDose;
  final VoidCallback onAddAnyway;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isDuplicate = conflict.conflictType == 'duplicate';
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: colors.warning),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                isDuplicate ? 'Already in your stack' : 'Possible overlap',
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            conflict.message ??
                (isDuplicate
                    ? 'You already have "${conflict.conflictingName}" in your stack.'
                    : '"${conflict.conflictingName}" in your stack may contain the same ingredient.'),
            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              TextButton(
                onPressed: onAdjustDose,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Adjust dose',
                  style: AppTextStyles.labelMedium.copyWith(color: colors.warning),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              TextButton(
                onPressed: onAddAnyway,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Add anyway',
                  style: AppTextStyles.labelMedium.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
