import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String audioPath;
  final int duration;
  final bool isMe;
  final VoidCallback? onPlaybackComplete;

  const VoiceMessageWidget({
    Key? key,
    required this.audioPath,
    required this.duration,
    required this.isMe,
    this.onPlaybackComplete,
  }) : super(key: key);

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _totalDuration = Duration(seconds: widget.duration);
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          _isPlaying = playerState.playing;
          _isLoading = playerState.processingState == ProcessingState.loading;
        });

        if (_isPlaying) {
          _waveController.repeat();
        } else {
          _waveController.stop();
        }

        if (playerState.processingState == ProcessingState.completed) {
          widget.onPlaybackComplete?.call();
        }
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentPosition >= _totalDuration) {
          await _audioPlayer.seek(Duration.zero);
        }

        if (_audioPlayer.audioSource == null) {
          await _audioPlayer.setFilePath(widget.audioPath);
        }

        await _audioPlayer.play();
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.blue.withOpacity(0.8)
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _isLoading ? null : _togglePlayback,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white : Colors.blue,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isMe ? Colors.blue : Colors.white,
                  ),
                ),
              )
                  : Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? Colors.blue : Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Waveform visualization
          Expanded(
            child: Container(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(20, (index) {
                  return AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      final progress = _totalDuration.inMilliseconds > 0
                          ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                          : 0.0;
                      final isActive = (index / 20) <= progress;

                      return Container(
                        width: 2,
                        height: _isPlaying
                            ? (10 + (10 * (index % 3)) * _waveController.value)
                            : (8 + (index % 4) * 3).toDouble(),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (widget.isMe ? Colors.white : Colors.blue)
                              : (widget.isMe ? Colors.white54 : Colors.grey),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_isPlaying ? _currentPosition : _totalDuration),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: widget.isMe ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}