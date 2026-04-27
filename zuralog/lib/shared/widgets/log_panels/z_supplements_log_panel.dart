/// ZuraLog — Supplements Daily Check-off Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Supplements tile.
/// Auto-saves each supplement tap locally-first with background sync.
/// Follows the same pattern as ZWaterLogPanel.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/today/data/supplement_log_local_repository.dart';
import 'package:zuralog/features/today/data/supplement_log_sync_service.dart';
import 'package:zuralog/features/today/domain/supplement_taken_log.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/feedback/z_alert_dialog.dart';
import 'package:zuralog/shared/widgets/feedback/z_toast.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_number_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_labeled_text_field.dart';
import 'package:zuralog/shared/widgets/overlays/z_log_success_overlay.dart';

const _kTimingOrder = ['morning', 'afternoon', 'evening', 'anytime'];
const _kTimingLabels = {
  'morning': 'Morning',
  'afternoon': 'Afternoon',
  'evening': 'Evening',
  'anytime': 'Anytime',
};

class ZSupplementsLogPanel extends ConsumerStatefulWidget {
  const ZSupplementsLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  ConsumerState<ZSupplementsLogPanel> createState() =>
      _ZSupplementsLogPanelState();
}

class _ZSupplementsLogPanelState
    extends ConsumerState<ZSupplementsLogPanel> {
  final Map<String, String> _sessionTaken = {};
  Map<String, String> _serverTaken = {};
  bool _initialised = false;

  // One-off form state
  bool _showOneOffForm = false;
  final _oneOffNameController = TextEditingController();
  final _oneOffAmountController = TextEditingController();
  String? _oneOffUnit;

  @override
  void initState() {
    super.initState();
    // Eagerly initialize the sync service so its WidgetsBindingObserver is
    // registered before the first frame. Safe to call here because
    // WidgetsBinding.instance.addObserver is available during initState.
    try {
      ref.read(supplementLogSyncServiceProvider);
    } catch (e) {
      debugPrint('[ZSupplementsLogPanel] sync service unavailable: $e');
    }
  }

  @override
  void dispose() {
    _oneOffNameController.dispose();
    _oneOffAmountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed _serverTaken from the already-resolved future (if ready).
    if (!_initialised) {
      final value = ref.read(supplementsTodayLogProvider).valueOrNull;
      if (value != null) {
        _serverTaken = {for (final e in value) e.supplementId: e.logId};
        _initialised = true;
      }
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isTaken(String supplementId) =>
      _sessionTaken.containsKey(supplementId) ||
      _serverTaken.containsKey(supplementId);

  Future<void> _handleTap(SupplementEntry supplement) async {
    if (_isTaken(supplement.id)) {
      await _handleUncheck(supplement);
    } else {
      await _handleCheckin(supplement);
    }
  }

  Future<void> _handleCheckin(SupplementEntry supplement) async {
    HapticFeedback.lightImpact();
    final localId = const Uuid().v4();
    final log = SupplementTakenLog(
      id: localId,
      supplementId: supplement.id,
      logDate: _today(),
      recordedAt: DateTime.now(),
    );
    // Optimistic update first so the UI responds instantly.
    setState(() => _sessionTaken[supplement.id] = localId);
    // Persist locally (best-effort; sync will retry on failure).
    try {
      final localRepo = ref.read(supplementLogLocalRepositoryProvider);
      await localRepo.saveLog(log);
    } catch (_) {
      // Local storage unavailable (e.g. test environment) — UI state is
      // already updated; sync service will still attempt cloud save.
    }

    try {
      final syncService = ref.read(supplementLogSyncServiceProvider);
      unawaited(syncService.syncLog(log).then((_) {
        if (mounted) setState(() {});
      }));
    } catch (_) {
      // Sync service unavailable (e.g. test environment) — skip background sync.
    }

    if (mounted) {
      ZToast.success(
        context,
        '${supplement.name} logged',
        action: 'Undo',
        onAction: () => _undoCheckin(supplement, localId, log),
        displayDuration: const Duration(seconds: 4),
      );
    }

    final supplements = ref.read(supplementsListProvider).valueOrNull ?? [];
    final totalCount = supplements.length;
    final takenCount = supplements.where((s) => _isTaken(s.id)).length;
    if (takenCount >= totalCount && totalCount > 0 && mounted) {
      // Brief pause so the check animation settles before showing the
      // success overlay. We use a post-frame callback instead of a timer
      // so that test teardown doesn't flag a pending timer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ZLogSuccessOverlay.show(context);
        widget.onSave();
      });
    }
  }

  Future<void> _undoCheckin(
    SupplementEntry supplement,
    String localId,
    SupplementTakenLog log,
  ) async {
    final localRepo = ref.read(supplementLogLocalRepositoryProvider);
    // Read the synced log ID from local storage BEFORE removing — syncLog may
    // have completed and stored the server-assigned ID there already.
    final syncedEntry = localRepo
        .getLogsForDate(log.logDate)
        .where((l) => l.id == localId)
        .firstOrNull;
    await localRepo.removeLog(localId, log.logDate);
    final serverLogId = _serverTaken[supplement.id] ?? syncedEntry?.logId;
    if (serverLogId != null) {
      try {
        final repo = ref.read(todayRepositoryProvider);
        await repo.deleteSupplementLogEntry(serverLogId);
      } catch (_) {}
    }
    setState(() {
      _sessionTaken.remove(supplement.id);
      _serverTaken.remove(supplement.id);
    });
    _invalidateProviders();
  }

  Future<void> _handleUncheck(SupplementEntry supplement) async {
    final confirmed = await ZAlertDialog.show(
      context,
      title: 'Remove log entry?',
      body:
          'This will delete your ${supplement.name} record for today. This action cannot be undone.',
      confirmLabel: 'Remove entry',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (confirmed != true) return;

    final localId = _sessionTaken[supplement.id];
    if (localId != null) {
      final localRepo = ref.read(supplementLogLocalRepositoryProvider);
      await localRepo.removeLog(localId, _today());
    }
    final serverLogId = _serverTaken[supplement.id];
    if (serverLogId != null) {
      try {
        final repo = ref.read(todayRepositoryProvider);
        await repo.deleteSupplementLogEntry(serverLogId);
      } catch (_) {}
    }
    setState(() {
      _sessionTaken.remove(supplement.id);
      _serverTaken.remove(supplement.id);
    });
    _invalidateProviders();
  }

  void _invalidateProviders() {
    _initialised = false;
    ref.invalidate(supplementsTodayLogProvider);
    ref.invalidate(supplementsSyncStatusProvider);
    ref.invalidate(todayLogSummaryProvider);
    ref.invalidate(progressHomeProvider);
    ref.invalidate(goalsProvider);
  }

  Future<void> _logOneOff() async {
    final name = _oneOffNameController.text.trim();
    if (name.isEmpty) return;
    HapticFeedback.lightImpact();
    final localId = const Uuid().v4();
    final log = SupplementTakenLog(
      id: localId,
      supplementId: 'adhoc_$localId',
      logDate: _today(),
      recordedAt: DateTime.now(),
      adHocName: name,
      adHocDoseAmount: double.tryParse(_oneOffAmountController.text.trim()),
      adHocDoseUnit: _oneOffUnit,
    );
    final localRepo = ref.read(supplementLogLocalRepositoryProvider);
    try {
      await localRepo.saveLog(log);
    } catch (e) {
      if (mounted) ZToast.error(context, 'Could not save — please try again.');
      return;
    }
    try {
      final syncService = ref.read(supplementLogSyncServiceProvider);
      unawaited(syncService.syncLog(log).then((_) {
        if (mounted) setState(() {});
      }));
    } catch (e) {
      debugPrint('[ZSupplementsLogPanel] sync service unavailable: $e');
    }
    setState(() {
      _showOneOffForm = false;
      _oneOffNameController.clear();
      _oneOffAmountController.clear();
      _oneOffUnit = null;
    });
    if (mounted) {
      ZToast.success(
        context,
        '$name logged for today',
        displayDuration: const Duration(seconds: 4),
      );
    }
    _invalidateProviders();
  }

  Map<String?, List<SupplementEntry>> _groupByTiming(
      List<SupplementEntry> supplements) {
    final grouped = <String?, List<SupplementEntry>>{};
    for (final s in supplements) {
      (grouped[s.timing] ??= []).add(s);
    }
    return grouped;
  }

  List<MapEntry<String?, List<SupplementEntry>>> _sortedGroups(
      Map<String?, List<SupplementEntry>> grouped) {
    final entries = grouped.entries.toList();
    entries.sort((a, b) {
      final ai = _kTimingOrder.indexOf(a.key ?? 'anytime');
      final bi = _kTimingOrder.indexOf(b.key ?? 'anytime');
      return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final supplementsAsync = ref.watch(supplementsListProvider);
    final syncStatusAsync = ref.watch(supplementsSyncStatusProvider);

    ref.listen(supplementsTodayLogProvider, (_, next) {
      if (!_initialised) {
        next.whenData((entries) {
          setState(() {
            _serverTaken = {for (final e in entries) e.supplementId: e.logId};
            _initialised = true;
          });
        });
      }
    });

    final syncStatus =
        syncStatusAsync.valueOrNull ?? SupplementSyncStatus.none;

    return supplementsAsync.when(
      loading: () => const _LoadingState(),
      error: (e, _) => const _ErrorState(),
      data: (supplements) {
        if (supplements.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHeader(
                takenCount: 0,
                totalCount: 0,
                syncStatus: syncStatus,
                onBack: widget.onBack,
              ),
              const Expanded(child: _EmptyState()),
            ],
          );
        }
        final takenCount =
            supplements.where((s) => _isTaken(s.id)).length;
        final grouped = _groupByTiming(supplements);
        final sortedGroups = _sortedGroups(grouped);
        return _PanelContent(
          supplements: supplements,
          sortedGroups: sortedGroups,
          takenCount: takenCount,
          syncStatus: syncStatus,
          isTaken: _isTaken,
          onTap: _handleTap,
          onBack: widget.onBack,
          oneOffSection: _OneOffSection(
            showForm: _showOneOffForm,
            nameController: _oneOffNameController,
            amountController: _oneOffAmountController,
            selectedUnit: _oneOffUnit,
            onToggle: () => setState(() => _showOneOffForm = !_showOneOffForm),
            onUnitSelect: (u) => setState(() => _oneOffUnit = u),
            onLog: _logOneOff,
          ),
        );
      },
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.supplements,
    required this.sortedGroups,
    required this.takenCount,
    required this.syncStatus,
    required this.isTaken,
    required this.onTap,
    required this.onBack,
    required this.oneOffSection,
  });

  final List<SupplementEntry> supplements;
  final List<MapEntry<String?, List<SupplementEntry>>> sortedGroups;
  final int takenCount;
  final SupplementSyncStatus syncStatus;
  final bool Function(String) isTaken;
  final void Function(SupplementEntry) onTap;
  final VoidCallback onBack;
  final Widget oneOffSection;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelHeader(
          takenCount: takenCount,
          totalCount: supplements.length,
          syncStatus: syncStatus,
          onBack: onBack,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd),
            children: [
              for (final group in sortedGroups) ...[
                if (group.key != null) ...[
                  Text(
                    _kTimingLabels[group.key] ?? group.key!,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                ],
                ...group.value.map(
                  (s) => _SupplementRow(
                    supplement: s,
                    taken: isTaken(s.id),
                    onTap: () => onTap(s),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],
              oneOffSection,
              const _PanelFooter(),
              const SizedBox(height: AppDimens.spaceLg),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.takenCount,
    required this.totalCount,
    required this.syncStatus,
    required this.onBack,
  });

  final int takenCount;
  final int totalCount;
  final SupplementSyncStatus syncStatus;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$takenCount of $totalCount taken today',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                _SyncIcon(syncStatus: syncStatus),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.insights_rounded,
              size: 18,
              color: colors.textSecondary,
            ),
            onPressed: () => context.push(RouteNames.supplementInsightsPath),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _SyncIcon extends StatelessWidget {
  const _SyncIcon({required this.syncStatus});

  final SupplementSyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    if (syncStatus == SupplementSyncStatus.none) {
      return const SizedBox.shrink();
    }
    if (syncStatus == SupplementSyncStatus.pending) {
      return Icon(
        Icons.cloud_upload_outlined,
        size: 14,
        color: colors.textSecondary.withValues(alpha: 0.35),
      );
    }
    return Icon(
      Icons.cloud_done_outlined,
      size: 14,
      color: const Color(0xFF64D2FF).withValues(alpha: 0.55),
    );
  }
}

class _SupplementRow extends StatelessWidget {
  const _SupplementRow({
    required this.supplement,
    required this.taken,
    required this.onTap,
  });

  final SupplementEntry supplement;
  final bool taken;
  final VoidCallback onTap;

  String? get _doseLabel {
    if (supplement.doseAmount != null && supplement.doseUnit != null) {
      final amount = supplement.doseAmount!.toStringAsFixed(
        supplement.doseAmount! % 1 == 0 ? 0 : 1,
      );
      final parts = <String>['$amount ${supplement.doseUnit}'];
      if (supplement.form != null) parts.add(supplement.form!);
      return parts.join(' · ');
    }
    if (supplement.dose != null) return supplement.dose;
    if (supplement.form != null) return supplement.form;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.spaceXs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: taken
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
          border: taken
              ? Border.all(
                  color: colors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              taken
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 22,
              color: taken
                  ? colors.primary
                  : colors.textSecondary
                      .withValues(alpha: 0.4),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplement.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight:
                          taken ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (_doseLabel != null)
                    Text(
                      _doseLabel!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelFooter extends StatelessWidget {
  const _PanelFooter();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          color: colors.border.withValues(alpha: 0.3),
          height: 1,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        GestureDetector(
          onTap: () => GoRouter.of(context)
              .pushNamed(RouteNames.supplementsStack),
          child: Text(
            'Manage my stack →',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _OneOffSection extends StatelessWidget {
  const _OneOffSection({
    required this.showForm,
    required this.nameController,
    required this.amountController,
    required this.selectedUnit,
    required this.onToggle,
    required this.onUnitSelect,
    required this.onLog,
  });

  final bool showForm;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final String? selectedUnit;
  final VoidCallback onToggle;
  final void Function(String) onUnitSelect;
  final VoidCallback onLog;

  static const _kUnitOptions = ['mg', 'mcg', 'IU', 'g', 'ml', 'other'];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
            child: Text(
              '+ Log something extra today',
              style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        if (showForm) ...[
          const SizedBox(height: AppDimens.spaceSm),
          ZLabeledTextField(
            label: 'Name',
            controller: nameController,
            hint: 'e.g. Iron',
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ZLabeledNumberField(
            label: 'Amount',
            controller: amountController,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _OneOffUnitGrid(
            options: _kUnitOptions,
            selected: selectedUnit,
            onSelect: onUnitSelect,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _LogTodayButton(
            nameController: nameController,
            onLog: onLog,
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
      ],
    );
  }
}

class _OneOffUnitGrid extends StatelessWidget {
  const _OneOffUnitGrid({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String? selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < options.length; i += 2) {
      rows.add(Row(children: [
        Expanded(
          child: _UnitCell(
            label: options[i],
            selected: options[i] == selected,
            onTap: () => onSelect(options[i]),
          ),
        ),
        const SizedBox(width: AppDimens.spaceXs),
        if (i + 1 < options.length)
          Expanded(
            child: _UnitCell(
              label: options[i + 1],
              selected: options[i + 1] == selected,
              onTap: () => onSelect(options[i + 1]),
            ),
          )
        else
          const Expanded(child: SizedBox.shrink()),
      ]));
      if (i + 2 < options.length) rows.add(const SizedBox(height: AppDimens.spaceXs));
    }
    return Column(children: rows);
  }
}

class _UnitCell extends StatelessWidget {
  const _UnitCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.4)
                : colors.border.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? colors.primary : colors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _LogTodayButton extends StatefulWidget {
  const _LogTodayButton({
    required this.nameController,
    required this.onLog,
  });

  final TextEditingController nameController;
  final VoidCallback onLog;

  @override
  State<_LogTodayButton> createState() => _LogTodayButtonState();
}

class _LogTodayButtonState extends State<_LogTodayButton> {
  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(_LogTodayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nameController != widget.nameController) {
      oldWidget.nameController.removeListener(_rebuild);
      widget.nameController.addListener(_rebuild);
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.nameController.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZButton(
      label: 'Log today',
      onPressed: widget.nameController.text.trim().isNotEmpty ? widget.onLog : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 56,
              color: colors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'No stack yet',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Add your supplements and meds to log them with a single tap each morning.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            ElevatedButton(
              onPressed: () => GoRouter.of(context)
                  .pushNamed(RouteNames.supplementsStack),
              child: const Text('Set up my stack'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Text(
        'Could not load supplements.',
        style: AppTextStyles.bodyMedium
            .copyWith(color: colors.textSecondary),
      ),
    );
  }
}
