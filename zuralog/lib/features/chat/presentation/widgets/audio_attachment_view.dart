/// Zuralog Edge Agent — Audio Attachment View.
///
/// Renders a voice note attachment as a compact play/pause button
/// with a progress bar and duration label. Uses `audioplayers` for
/// playback from either a local file or a signed URL.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/domain/attachment.dart';

/// Renders a voice note attachment with play/pause and progress.
class AudioAttachmentView extends StatefulWidget {
  /// The audio attachment to play.
  final ChatAttachment attachment;

  /// Creates an [AudioAttachmentView].
  const AudioAttachmentView({super.key, required this.attachment});

  @override
  State<AudioAttachmentView> createState() => _AudioAttachmentViewState();
}

class _AudioAttachmentViewState extends State<AudioAttachmentView> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      final localPath = widget.attachment.localPath;
      final signedUrl = widget.attachment.signedUrl;

      if (localPath != null) {
        await _player.play(DeviceFileSource(localPath));
      } else if (signedUrl != null && signedUrl.isNotEmpty) {
        await _player.play(UrlSource(signedUrl));
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final displayDuration = _duration > Duration.zero
        ? _duration
        : Duration(seconds: widget.attachment.durationSeconds ?? 0);

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),

          // Progress bar + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        AppColors.textSecondary.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPlaying
                      ? _formatDuration(_position)
                      : _formatDuration(displayDuration),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
