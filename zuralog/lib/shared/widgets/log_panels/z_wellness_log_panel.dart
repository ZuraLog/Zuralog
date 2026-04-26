/// Zuralog — Wellness Check-in Inline Log Panel.
///
/// AI-first voice/text wellness check-in with 6 states:
///   idle        — entry point: AI path buttons + quick check-in link
///   recording   — microphone active, shows ZAudioVisualizer
///   writing     — text area for typed input
///   parsing     — loading, "Zura is figuring this out..."
///   confirming  — AI result shown with editable face selectors
///   quickCheckin — face tap path (offline-capable)
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/feedback/z_audio_visualizer.dart';
import 'package:zuralog/shared/widgets/inputs/app_text_field.dart';
import 'package:zuralog/shared/widgets/inputs/z_chip_multi_select.dart';
import 'package:zuralog/shared/widgets/inputs/z_chip_single_select.dart';
import 'package:zuralog/shared/widgets/inputs/z_sentiment_selector.dart';
import 'package:zuralog/shared/widgets/overlays/z_log_success_overlay.dart';

// ── Data model ─────────────────────────────────────────────────────────────────

/// Data captured in a single wellness check-in.
///
/// All fields are nullable — only filled-in values are included.
class WellnessLogData {
  const WellnessLogData({
    this.mood,
    this.energy,
    this.stress,
    this.notes,
    this.tags = const [],
    this.aiSummary,
    this.transcript,
  });

  final double? mood;
  final double? energy;
  final double? stress;
  final String? notes;
  final List<String> tags;
  final String? aiSummary;

  /// Raw transcript of what the user said or wrote, only set when the user
  /// opts in via the "Remember my words" toggle.
  final String? transcript;
}

// ── State enum ─────────────────────────────────────────────────────────────────

enum _WellnessState { idle, recording, writing, parsing, confirming, quickCheckin }

// ── Tag options ────────────────────────────────────────────────────────────────

const _kTagOptions = [
  ZChipOption(value: 'work_stress', label: 'Work stress'),
  ZChipOption(value: 'poor_sleep', label: 'Poor sleep'),
  ZChipOption(value: 'exercise', label: 'Exercise'),
  ZChipOption(value: 'good_food', label: 'Good food'),
  ZChipOption(value: 'social', label: 'Social'),
  ZChipOption(value: 'tired', label: 'Tired'),
  ZChipOption(value: 'anxious', label: 'Anxious'),
  ZChipOption(value: 'calm', label: 'Calm'),
  ZChipOption(value: 'motivated', label: 'Motivated'),
  ZChipOption(value: 'under_the_weather', label: 'Under the weather'),
];

// ── ZWellnessLogPanel ──────────────────────────────────────────────────────────

/// Inline log panel for a wellness check-in.
///
/// Supports AI-powered voice and text input paths as well as an offline-capable
/// quick check-in path using face-tap sentiment selectors.
class ZWellnessLogPanel extends ConsumerStatefulWidget {
  const ZWellnessLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  /// Called when the user confirms a check-in. Receives the check-in data.
  final Future<void> Function(WellnessLogData data) onSave;

  /// Called by the parent when the user taps the back button in the sheet header.
  final VoidCallback onBack;

  @override
  ConsumerState<ZWellnessLogPanel> createState() => _ZWellnessLogPanelState();
}

class _ZWellnessLogPanelState extends ConsumerState<ZWellnessLogPanel> {
  // ── State machine ─────────────────────────────────────────────────────────

  _WellnessState _state = _WellnessState.idle;

  // ── Save guard ────────────────────────────────────────────────────────────

  bool _saving = false;

  // ── Connectivity ──────────────────────────────────────────────────────────

  bool _isOnline = true;

  // ── Speech ────────────────────────────────────────────────────────────────

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _transcript = '';
  double _soundLevel = 0.0;

  // ── Write path ────────────────────────────────────────────────────────────

  final TextEditingController _writeController = TextEditingController();

  // ── Confirming state ──────────────────────────────────────────────────────

  int? _moodLevel;
  int? _energyLevel;
  int? _stressLevel;
  List<String> _selectedTags = [];
  String _aiSummary = '';
  bool _saveTranscript = false;
  String _savedTranscript = '';

  // ── Quick check-in state ──────────────────────────────────────────────────

  int? _quickMood;
  int? _quickEnergy;
  int? _quickStress;
  bool _tagsExpanded = false;
  List<String> _quickTags = [];
  final TextEditingController _notesController = TextEditingController();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _initSpeech();
  }

  @override
  void dispose() {
    if (_speech.isListening) _speech.stop();
    _writeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Converts a 1–5 face level to a backend value (2.0, 4.0, 6.0, 8.0, 10.0).
  double _levelToValue(int level) => level * 2.0;

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _isOnline = result.firstOrNull != ConnectivityResult.none);
  }

  // ── Speech ────────────────────────────────────────────────────────────────

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable) return;
    setState(() {
      _state = _WellnessState.recording;
      _transcript = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (mounted) setState(() => _transcript = result.recognizedWords);
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() => _soundLevel = ((level + 2) / 12).clamp(0.0, 1.0));
        }
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 5),
    );
  }

  Future<void> _stopRecording() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _soundLevel = 0.0);
    if (_transcript.trim().isNotEmpty) {
      _savedTranscript = _transcript.trim();
      await _parseTranscript(_savedTranscript);
    } else {
      setState(() => _state = _WellnessState.idle);
    }
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  Future<void> _parseTranscript(String text) async {
    setState(() => _state = _WellnessState.parsing);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(todayRepositoryProvider);
      final result = await repo.parseWellnessTranscript(text);
      if (!mounted) return;
      setState(() {
        _moodLevel = (result.mood / 2).round().clamp(1, 5);
        _energyLevel = (result.energy / 2).round().clamp(1, 5);
        _stressLevel = (result.stress / 2).round().clamp(1, 5);
        _selectedTags = result.tags;
        _aiSummary = result.summary;
        _state = _WellnessState.confirming;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _WellnessState.idle);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not parse your check-in. Please try again.'),
        ),
      );
    }
  }

  // ── Save helpers ──────────────────────────────────────────────────────────

  Future<void> _saveConfirmed({bool continueWithZura = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final data = WellnessLogData(
        mood: _moodLevel != null ? _levelToValue(_moodLevel!) : null,
        energy: _energyLevel != null ? _levelToValue(_energyLevel!) : null,
        stress: _stressLevel != null ? _levelToValue(_stressLevel!) : null,
        tags: _selectedTags,
        aiSummary: _aiSummary.isNotEmpty ? _aiSummary : null,
        transcript: _saveTranscript && _savedTranscript.isNotEmpty
            ? _savedTranscript
            : null,
      );
      HapticFeedback.mediumImpact();
      await widget.onSave(data);
      if (!mounted) return;
      ZLogSuccessOverlay.show(context);
      if (continueWithZura) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) context.goNamed(RouteNames.coach);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveQuickCheckin({bool continueWithZura = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final data = WellnessLogData(
        mood: _quickMood != null ? _levelToValue(_quickMood!) : null,
        energy: _quickEnergy != null ? _levelToValue(_quickEnergy!) : null,
        stress: _quickStress != null ? _levelToValue(_quickStress!) : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        tags: _quickTags,
      );
      HapticFeedback.mediumImpact();
      await widget.onSave(data);
      if (!mounted) return;
      ZLogSuccessOverlay.show(context);
      if (continueWithZura) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) context.goNamed(RouteNames.coach);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (_state) {
          _WellnessState.idle => _buildIdle(),
          _WellnessState.recording => _buildRecording(),
          _WellnessState.writing => _buildWriting(),
          _WellnessState.parsing => _buildParsing(),
          _WellnessState.confirming => _buildConfirming(),
          _WellnessState.quickCheckin => _buildQuickCheckin(),
        },
      ),
    );
  }

  // ── State views ───────────────────────────────────────────────────────────

  Widget _buildIdle() {
    final colors = AppColorsOf(context);

    if (!_isOnline) {
      return Column(
        key: const ValueKey('idle'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AI features need a connection.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(
            label: 'Quick check-in',
            onPressed: () => setState(() => _state = _WellnessState.quickCheckin),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'How are you feeling right now?',
          style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        Row(
          children: [
            Expanded(
              child: ZButton(
                label: 'Speak',
                icon: Icons.mic_rounded,
                onPressed: _startRecording,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: ZButton(
                label: 'Write',
                variant: ZButtonVariant.secondary,
                icon: Icons.edit_rounded,
                onPressed: () =>
                    setState(() => _state = _WellnessState.writing),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Center(
          child: TextButton(
            onPressed: () =>
                setState(() => _state = _WellnessState.quickCheckin),
            child: Text(
              'Quick check-in',
              style: AppTextStyles.labelMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecording() {
    final colors = AppColorsOf(context);

    return Column(
      key: const ValueKey('recording'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppDimens.spaceLg),
        Center(child: ZAudioVisualizer(level: _soundLevel)),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          'Listening... tap Done when finished.',
          style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ZButton(label: 'Done', onPressed: _stopRecording),
      ],
    );
  }

  Widget _buildWriting() {
    return Column(
      key: const ValueKey('writing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _writeController,
          hintText: "Just write how you're feeling...",
          maxLines: null,
          maxLength: 2000,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        ZButton(
          label: 'Done',
          onPressed: () {
            _savedTranscript = _writeController.text.trim();
            if (_savedTranscript.isNotEmpty) {
              _parseTranscript(_savedTranscript);
            } else {
              setState(() => _state = _WellnessState.idle);
            }
          },
        ),
      ],
    );
  }

  Widget _buildParsing() {
    final colors = AppColorsOf(context);

    return Padding(
      key: const ValueKey('parsing'),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Zura is figuring this out...',
            style:
                AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirming() {
    final colors = AppColorsOf(context);

    return Column(
      key: const ValueKey('confirming'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // AI summary card
        if (_aiSummary.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.categoryWellness.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.categoryWellness.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusInput),
            ),
            child: Text(
              _aiSummary,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],

        // Sentiment rows
        _buildSentimentRow(
          'Mood',
          _moodLevel,
          false,
          (v) => setState(() => _moodLevel = v),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _buildSentimentRow(
          'Energy',
          _energyLevel,
          false,
          (v) => setState(() => _energyLevel = v),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _buildSentimentRow(
          'Stress',
          _stressLevel,
          true,
          (v) => setState(() => _stressLevel = v),
        ),

        const SizedBox(height: AppDimens.spaceLg),

        // Tags
        Text(
          'What influenced this?',
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        ZChipMultiSelect<String>(
          options: _kTagOptions,
          values: _selectedTags,
          onChanged: (tags) => setState(() => _selectedTags = tags),
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // Save transcript toggle
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remember my words',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Zura gives better support when it remembers what you said.',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _saveTranscript,
              onChanged: (v) => setState(() => _saveTranscript = v),
              activeThumbColor: AppColors.categoryWellness,
            ),
          ],
        ),

        const SizedBox(height: AppDimens.spaceLg),

        ZButton(
          label: 'Save check-in',
          onPressed: !_saving ? _saveConfirmed : null,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        ZButton(
          label: 'Talk to Zura about this',
          variant: ZButtonVariant.secondary,
          onPressed: !_saving ? () => _saveConfirmed(continueWithZura: true) : null,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _state = _WellnessState.idle;
              _moodLevel = null;
              _energyLevel = null;
              _stressLevel = null;
              _selectedTags = [];
              _aiSummary = '';
              _savedTranscript = '';
              _saveTranscript = false;
            }),
            child: Text(
              'Start over',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColorsOf(context).textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickCheckin() {
    final colors = AppColorsOf(context);
    final canSave =
        _quickMood != null || _quickEnergy != null || _quickStress != null;

    return Column(
      key: const ValueKey('quickCheckin'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSentimentRow(
          'Mood',
          _quickMood,
          false,
          (v) => setState(() => _quickMood = v),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _buildSentimentRow(
          'Energy',
          _quickEnergy,
          false,
          (v) => setState(() => _quickEnergy = v),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _buildSentimentRow(
          'Stress',
          _quickStress,
          true,
          (v) => setState(() => _quickStress = v),
        ),

        const SizedBox(height: AppDimens.spaceLg),

        if (!_tagsExpanded)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('What influenced this?'),
            onPressed: () => setState(() => _tagsExpanded = true),
          )
        else ...[
          Text(
            'What influenced this?',
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ZChipMultiSelect<String>(
            options: _kTagOptions,
            values: _quickTags,
            onChanged: (tags) => setState(() => _quickTags = tags),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],

        AppTextField(
          controller: _notesController,
          hintText: 'Anything else on your mind?',
          maxLength: 500,
        ),

        const SizedBox(height: AppDimens.spaceLg),

        ZButton(
          label: 'Save check-in',
          onPressed: (canSave && !_saving) ? _saveQuickCheckin : null,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        ZButton(
          label: 'Talk to Zura about this',
          variant: ZButtonVariant.secondary,
          onPressed: (canSave && !_saving)
              ? () => _saveQuickCheckin(continueWithZura: true)
              : null,
        ),
      ],
    );
  }

  // ── Sentiment row ─────────────────────────────────────────────────────────

  Widget _buildSentimentRow(
    String label,
    int? level,
    bool reversed,
    ValueChanged<int> onChanged,
  ) {
    final colors = AppColorsOf(context);

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ZSentimentSelector(
            selectedLevel: level,
            onChanged: onChanged,
            reversed: reversed,
          ),
        ),
      ],
    );
  }
}
