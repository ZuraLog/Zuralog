/// Zuralog Edge Agent — Voice Recorder Overlay.
///
/// An inline recording bar that replaces the text field area while
/// recording a voice note. Shows an animated timer, a cancel button,
/// and a send button. Uses the `record` package for audio capture.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Callback for when a voice recording is completed.
///
/// [filePath] is the absolute path to the recorded audio file.
typedef OnRecordingComplete = void Function(String filePath);

/// An inline recording bar for capturing voice notes.
///
/// Starts recording immediately when mounted. The user can cancel
/// or send the recording.
class VoiceRecorder extends StatefulWidget {
  /// Called when the user finishes recording and taps send.
  final OnRecordingComplete onComplete;

  /// Called when the user cancels the recording.
  final VoidCallback onCancel;

  /// Creates a [VoiceRecorder].
  const VoiceRecorder({
    super.key,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      widget.onCancel();
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    setState(() => _isRecording = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      widget.onComplete(path);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _recorder.stop();
    widget.onCancel();
  }

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          // Cancel button
          IconButton(
            onPressed: _cancel,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.accentDark,
            iconSize: AppDimens.iconMd,
            tooltip: 'Cancel recording',
          ),

          const SizedBox(width: AppDimens.spaceSm),

          // Recording indicator + timer
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing red dot
                if (_isRecording)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    onEnd: () {
                      // Restart animation by rebuilding
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.accentDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  _formattedTime,
                  style: AppTextStyles.body.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimens.spaceSm),

          // Send button
          IconButton(
            onPressed: _isRecording ? _stopAndSend : null,
            icon: const Icon(Icons.send_rounded),
            color: AppColors.primary,
            iconSize: AppDimens.iconMd,
            tooltip: 'Send voice note',
          ),
        ],
      ),
    );
  }
}
