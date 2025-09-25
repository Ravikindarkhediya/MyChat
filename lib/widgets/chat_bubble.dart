import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../controller/chat_controller.dart';
import '../models/message_model.dart';
import '../models/enums.dart';
import '../services/chat_services/voice_message_widget.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final ChatController chatController;
  final bool showTime;
  final bool showStatus;


  const ChatBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.chatController,
    this.showTime = false,
    this.showStatus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: showTime ? 8 : 4,
        left: isMe ? 60 : 16,
        right: isMe ? 16 : 60,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message bubble
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) _buildAvatar(),
              Flexible(
                child: _buildMessageBubble(context),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),

          // Time and status
          if (showTime || showStatus)
            Container(
              margin: EdgeInsets.only(
                top: 4,
                left: isMe ? 0 : 50,
                right: isMe ? 8 : 0,
              ),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (showTime) _buildTimeStamp(),
                  if (showStatus && isMe) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatus(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioMessage() {
    return FutureBuilder<String>(
      future: chatController.getAudioFilePath(message),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final duration = message.metadata['duration'] ?? '0:00';
          return VoiceMessageWidget(
            audioPath: snapshot.data!,
            duration: duration,
            isMe: isMe,
          );
        }
        return Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          backgroundImage: message.senderPhotoUrl != null && message.senderPhotoUrl!.isNotEmpty
              ? NetworkImage(message.senderPhotoUrl!)
              : null,
          child: message.senderPhotoUrl == null || message.senderPhotoUrl!.isEmpty
              ? Text(
            message.senderName!.isNotEmpty
                ? message.senderName![0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: Radius.circular(isMe ? 20 : 8),
        bottomRight: Radius.circular(isMe ? 8 : 20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isMe
                  ? [
                Colors.blue.withOpacity(0.3),
                Colors.purple.withOpacity(0.2),
              ]
                  : [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 8),
              bottomRight: Radius.circular(isMe ? 8 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender name (for group chats)
              if (!isMe && message.senderName!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),

              // Message content
              _buildMessageContent(),

              // Message metadata (edited indicator, etc.)
              if (message.isEdited)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  child: Text(
                    'edited',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.text:
        return _buildTextMessage();
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.video:
        return _buildVideoMessage();
      case MessageType.audio:
        return _buildAudioMessage(); // ✅ Updated FutureBuilder logic
      case MessageType.file:
        return _buildFileMessage();
      case MessageType.location:
        return _buildLocationMessage();
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    return SelectableText(
      message.content,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: Colors.white.withOpacity(0.95),
        height: 1.3,
      ),
    );
  }

  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 250,
              maxHeight: 300,
            ),
            child: Image.network(
              message.content,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white.withOpacity(0.6),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (message.metadata['caption'] != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: Text(
              message.metadata['caption'] as String,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoMessage() {
    return Container(
      width: 250,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.play_circle_fill_rounded,
            size: 50,
            color: Colors.white.withOpacity(0.8),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                message.metadata['duration'] ?? 'Video',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFileMessage() {
    final fileName = message.metadata['fileName'] ?? 'Document';
    final fileSize = message.metadata['fileSize'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.description_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize.isNotEmpty)
                  Text(
                    fileSize,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMessage() {
    return Container(
      width: 250,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.green.withOpacity(0.2),
              child: const Center(
                child: Icon(
                  Icons.location_on_rounded,
                  size: 40,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStamp() {
    final formatter = DateFormat('h:mm a');
    final timeString = formatter.format(message.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        timeString,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildMessageStatus() {
    IconData icon;
    Color color;

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.schedule_rounded;
        color = Colors.grey;
        break;
      case MessageStatus.sent:
        icon = Icons.check_rounded;
        color = Colors.white70;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        color = Colors.white70;
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = Colors.blue;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.red;
        break;
      default:
        icon = Icons.check_rounded;
        color = Colors.white70;
    }

    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }
}