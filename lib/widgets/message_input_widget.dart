import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_services/voice_recording_service.dart';
import 'glass.dart';

class MessageInputWidget extends StatefulWidget {
  final Function(String) onSendTextMessage;
  final Function(String, int) onSendVoiceMessage;
  final VoidCallback onCameraPressed;

  const MessageInputWidget({
    Key? key,
    required this.onSendTextMessage,
    required this.onSendVoiceMessage,
    required this.onCameraPressed,
  }) : super(key: key);

  @override
  State<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends State<MessageInputWidget>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final VoiceRecordingService _voiceService = VoiceRecordingService();

  bool _isTyping = false;
  bool _isRecording = false;
  bool _isEmojiVisible = false;
  late AnimationController _recordingAnimationController;
  late AnimationController _micAnimationController;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);

    _recordingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _voiceService.recordingDurationStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onTextChanged() {
    setState(() {
      _isTyping = _messageController.text.trim().isNotEmpty;
    });
  }

  Future<void> _handleVoiceRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final path = await _voiceService.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
      });
      _recordingAnimationController.repeat();
      _micAnimationController.forward();
    }
  }

  Future<void> _stopRecording() async {
    final path = await _voiceService.stopRecording();
    if (path != null && _voiceService.recordingDuration > 0) {
      widget.onSendVoiceMessage(path, _voiceService.recordingDuration);
    }

    setState(() {
      _isRecording = false;
    });
    _recordingAnimationController.stop();
    _micAnimationController.reverse();
  }

  Future<void> _cancelRecording() async {
    await _voiceService.cancelRecording();
    setState(() {
      _isRecording = false;
    });
    _recordingAnimationController.stop();
    _micAnimationController.reverse();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendTextMessage(message);
      _messageController.clear();
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isHighlighted = false,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isHighlighted
              ? Colors.blue
              : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color ?? (isHighlighted ? Colors.white : Colors.white70),
          size: 20,
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Recording indicator
        if (_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _recordingAnimationController,
                  builder: (context, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(
                          0.5 + 0.5 * _recordingAnimationController.value,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  'Recording... ${_formatDuration(_voiceService.recordingDuration)}',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _cancelRecording,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Main input container
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            borderRadius: 25,
            opacity: 0.2,
            child: Row(
              children: [
                // Emoji button
                if (!_isRecording)
                  _buildActionButton(
                    icon: Icons.emoji_emotions_outlined,
                    onPressed: () {
                      _focusNode.unfocus();
                      setState(() => _isEmojiVisible = !_isEmojiVisible);
                    },
                  ),

                // Text input field (hidden during recording)
                if (!_isRecording)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          fillColor: Colors.transparent,
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),

                // Recording waveform visualization
                if (_isRecording)
                  Expanded(
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(15, (index) {
                          return AnimatedBuilder(
                            animation: _recordingAnimationController,
                            builder: (context, child) {
                              final height = 8.0 +
                                  (16.0 * ((index % 3) + 1) *
                                      _recordingAnimationController.value);
                              return Container(
                                width: 2,
                                height: height,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  ),

                // Camera button (hidden during recording)
                if (!_isRecording)
                  _buildActionButton(
                    icon: Icons.camera_alt_rounded,
                    onPressed: widget.onCameraPressed,
                  ),

                // Send/Voice button
                GestureDetector(
                  onTap: _isRecording
                      ? _handleVoiceRecording
                      : (_isTyping ? _sendMessage : _handleVoiceRecording),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red
                          : (_isTyping ? Colors.blue : Colors.white.withOpacity(0.1)),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedBuilder(
                      animation: _micAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isRecording
                              ? 1.0 + 0.1 * _micAnimationController.value
                              : 1.0,
                          child: Icon(
                            _isRecording
                                ? Icons.stop
                                : (_isTyping ? Icons.send_rounded : Icons.mic_rounded),
                            color: _isRecording || _isTyping ? Colors.white : Colors.white70,
                            size: 20,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Emoji picker (implement as needed)
        if (_isEmojiVisible && !_isRecording)
          Container(
            height: 250,
            color: Colors.black26,
            child: const Center(
              child: Text(
                'Emoji Picker\n(Implement with emoji_picker_flutter package)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _recordingAnimationController.dispose();
    _micAnimationController.dispose();
    super.dispose();
  }
}