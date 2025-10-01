import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../controller/chat_controller.dart';
import '../models/message_model.dart';
import '../models/enums.dart';
import '../services/chat_services/chat_services.dart';
import 'full_screen_image.dart';
import '../view/full_screen_image_view.dart';
import 'glass.dart';

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
              Flexible(child: _buildMessageBubble(context)),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
          // Time and status
          if (showTime || showStatus)
            Container(
              margin: EdgeInsets.only(left: isMe ? 0 : 50, right: isMe ? 8 : 0, top: 4),
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

  Widget _buildAvatar() {
    final photoUrl = message.senderPhotoUrl;
    final name = message.senderName;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 2),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,

        child: hasPhoto
            ? null
            : Text(
                (name != null && name.isNotEmpty)
                    ? name.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox?;
        Offset position;
        if (box != null) {
          position = box.localToGlobal(box.size.center(Offset.zero));
        } else {
          position = const Offset(200, 300); // fallback
        }
        _showMessageMenu(context, position);
      },
      child: ClipRRect(
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
                    ? [Colors.blue.withOpacity(0.3), Colors.purple.withOpacity(0.2)]
                    : [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
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
                if (!isMe && (message.senderName?.isNotEmpty ?? false))
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                _buildMessageContent(),
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
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.white.withOpacity(0.95),
            height: 1.3,
          ),
        );
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.location:
        return _buildLocationMessage();
      default:
        return Text(message.content);
    }
  }

  Widget _buildImageMessage() {
    // ✅ mediaUrl field check करें, content नहीं
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return Container(
        height: 150,
        width: 150,
        decoration: BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(16)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.white54),
            SizedBox(height: 8),
            Text('Image not available',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    final mediaUrl = message.mediaUrl!;
    final double w = 150, h = 150;

    // HTTP URL check
    if (mediaUrl.startsWith('http')) {
      return GestureDetector(
        onTap: () => Get.to(() => FullScreenImageView(imageUrl: mediaUrl)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: mediaUrl,
            placeholder: (context, url) => Container(
              width: w, height: h,
              decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(16)
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              width: w, height: h,
              decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(16)
              ),
              child: const Icon(Icons.error, color: Colors.red),
            ),
            width: w, height: h,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    // Base64 data URL check
    else if (mediaUrl.startsWith('data:image')) {
      try {
        final base64Data = mediaUrl.split(',').last;
        final bytes = base64Decode(base64Data);

        return GestureDetector(
          onTap: () => Get.to(() => FullScreenImage(base64Data: base64Data)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              width: w,
              height: h,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('❌ Error displaying base64 image: $error');
                return Container(
                  width: w, height: h,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(16)
                  ),
                  child: const Icon(Icons.error, color: Colors.red),
                );
              },
            ),
          ),
        );
      } catch (e) {
        print('❌ Error decoding base64: $e');
        return Container(
          width: w, height: h,
          decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(16)
          ),
          child: const Icon(Icons.broken_image, color: Colors.red),
        );
      }
    }
    // Fallback
    else {
      return Container(
        width: w, height: h,
        decoration: BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(16)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.white54),
            SizedBox(height: 8),
            Text('Unsupported format',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }
  }

  Widget _buildLocationMessage() => Container();

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
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.7)),
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
    return Icon(icon, size: 14, color: color);
  }

  Future<void> _showMessageMenu(BuildContext context, Offset globalPosition) async {
    final size = MediaQuery.of(context).size;
    final isText = message.type == MessageType.text;

    // Layout for a compact glass menu
    const menuWidth = 220.0;
    final int itemCount = (isText ? 1 : 0) + (isMe ? 2 : 0) + 1; // copy + (edit, delete_all) + delete_me
    final menuHeight = 50.0 * itemCount;

    double left = globalPosition.dx - menuWidth / 2;
    double top = globalPosition.dy - menuHeight - 12;
    left = left.clamp(8.0, size.width - menuWidth - 8.0);
    top = top.clamp(80.0, size.height - menuHeight - 80.0);

    final selected = await showDialog<String>(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: true,
      builder: (ctx) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              type: MaterialType.transparency,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                borderRadius: 16,
                opacity: 0.18,
                child: ConstrainedBox(
                  constraints: const BoxConstraints.tightFor(width: menuWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isText)
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop('copy'),
                          child: _menuRow(icon: Icons.copy, label: 'Copy'),
                        ),
                      if (isMe)
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop('edit'),
                          child: _menuRow(icon: Icons.edit, label: 'Edit'),
                        ),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop('delete_me'),
                        child: _menuRow(icon: Icons.delete_outline, label: 'Delete for me'),
                      ),
                      if (isMe)
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop('delete_all'),
                          child: _menuRow(icon: Icons.delete_forever_outlined, label: 'Delete for everyone', danger: true),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    switch (selected) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.content));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
        break;
      case 'edit':
        if (isMe) await _editMessage(context);
        break;
      case 'delete_me':
        await _deleteMessage(context, forEveryone: false);
        break;
      case 'delete_all':
        if (isMe) await _deleteMessage(context, forEveryone: true);
        break;
      default:
        break;
    }
  }

  Widget _menuRow({required IconData icon, required String label, bool danger = false}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: danger ? Colors.redAccent : Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: danger ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(BuildContext context, {bool forEveryone = false}) async {
    final controller = TextEditingController(text: message.content);

    final updated = await showDialog<String>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                opacity: 0.18,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit message',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        type: MaterialType.transparency,
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Update message',
                            hintStyle: GoogleFonts.poppins(color: Colors.white70),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(ctx, controller.text.trim()),
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                Colors.blueAccent.withOpacity(0.7)),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );


    if (updated != null && updated.trim().isNotEmpty) {
      final chatService = ChatService();
      await chatService.updateMessage(
        chatId: message.chatId,
        messageId: message.id,
        newContent: updated.trim(),
        currentUserId: chatController.currentUserId.value,
      );
    }
  }


  Future<void> _deleteMessage(BuildContext context, {required bool forEveryone}) async {
    // Confirm for everyone
    if (forEveryone) {
      final ok = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black26,
        builder: (ctx) => Material(
          type: MaterialType.transparency,
          child: Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 18,
              opacity: 0.18,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delete for everyone?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text('This will remove the message for all participants.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (ok != true) return;
    }

    final chatService = ChatService();
    await chatService.deleteMessage(
      chatId: message.chatId,
      messageId: message.id,
      currentUserId: chatController.currentUserId.value,
      deleteForEveryone: forEveryone,
    );
  }
}
