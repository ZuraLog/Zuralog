/// Zuralog — Symptom Log Screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

const _kBodyAreas = ['Head', 'Stomach', 'Back', 'Chest', 'Throat', 'Joints', 'Muscles', 'Skin', 'General'];
const _kSymptomTypes = ['Pain', 'Ache', 'Nausea', 'Fatigue', 'Bloating', 'Soreness', 'Dizziness', 'Other'];
const _kSeverityLabels = ['Mild', 'Moderate', 'Bad', 'Severe'];
const _kSeverityValues = ['mild', 'moderate', 'bad', 'severe'];
const _kTimingChips = ['Just now', 'This morning', 'Yesterday', 'A few days ago'];

class SymptomLogScreen extends ConsumerStatefulWidget {
  const SymptomLogScreen({super.key});
  @override
  ConsumerState<SymptomLogScreen> createState() => _SymptomLogScreenState();
}

class _SymptomLogScreenState extends ConsumerState<SymptomLogScreen> {
  final Set<String> _bodyAreas = {};
  String? _symptomType;
  int? _severityIndex;
  String? _timing;
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  bool get _canSave => _bodyAreas.isNotEmpty && _severityIndex != null && !_isSaving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(todayRepositoryProvider);
      await repo.logSymptom(
        bodyAreas: _bodyAreas.toList(),
        severity: _kSeverityValues[_severityIndex!],
        symptomType: _symptomType?.toLowerCase(),
        timing: _timing,
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
      debugPrint('SymptomLogScreen save failed: $e');
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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ZuralogScaffold(
      appBar: AppBar(title: const Text('Log Symptom'), leading: const BackButton()),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              children: [
                const ZSectionLabel(label: 'Where / what?'),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: _kBodyAreas.map((a) => ZChip(
                    label: a,
                    isActive: _bodyAreas.contains(a),
                    onTap: () => setState(() {
                      if (_bodyAreas.contains(a)) { _bodyAreas.remove(a); } else { _bodyAreas.add(a); }
                    }),
                  )).toList(),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                ZSectionLabel(label: 'Symptom type', isOptional: true),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: _kSymptomTypes.map((t) => ZChip(
                    label: t,
                    isActive: _symptomType == t,
                    onTap: () => setState(() => _symptomType = _symptomType == t ? null : t),
                  )).toList(),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                const ZSectionLabel(label: 'Severity'),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: List.generate(_kSeverityLabels.length, (i) => ZChip(
                    label: _kSeverityLabels[i],
                    isActive: _severityIndex == i,
                    onTap: () => setState(() => _severityIndex = i),
                  )),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                ZSectionLabel(label: 'When did it start?', isOptional: true),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: _kTimingChips.map((t) => ZChip(
                    label: t,
                    isActive: _timing == t,
                    onTap: () => setState(() => _timing = _timing == t ? null : t),
                  )).toList(),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                ZSectionLabel(label: 'Describe it', isOptional: true),
                const SizedBox(height: AppDimens.spaceSm),
                ZTextArea(
                  controller: _notesCtrl,
                  placeholder: 'Anything to note?',
                  maxLength: 500,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, AppDimens.spaceSm + bottomPad),
            child: ZButton(
              label: 'Save Symptom',
              onPressed: _canSave ? _save : null,
              isLoading: _isSaving,
            ),
          ),
        ],
      ),
    );
  }
}
