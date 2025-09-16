import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatListItem extends StatelessWidget {
  final String chatId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final int unreadCount;
  final DateTime? lastMessageTime;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final UserModel? user; // For direct messages
  final ChatSummary? chatSummary; // For group chats

  const ChatListItem({
    Key? key,
    required this.chatId,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.unreadCount = 0,
    this.lastMessageTime,
    this.isOnline = false,
    this.isPinned = false,
    this.isMuted = false,
    this.onTap,
    this.onLongPress,
    this.user,
    this.chatSummary,
  }) : super(key: key);

  factory ChatListItem.fromUser({
    required UserModel user,
    required int unreadCount,
    required VoidCallback onTap,
    bool isOnline = false,
  }) {
    return ChatListItem(
      chatId: user.uid,
      title: user.name,
      subtitle: user.status ?? 'Tap to start chatting',
      imageUrl: user.photoUrl,
      unreadCount: unreadCount,
      isOnline: isOnline,
      onTap: onTap,
      user: user,
    );
  }

  factory ChatListItem.fromChatSummary({
    required ChatSummary chatSummary,
    required String currentUserId,
    required VoidCallback onTap,
  }) {
    return ChatListItem(
      chatId: chatSummary.chatId,
      title: chatSummary.getChatTitle(currentUserId),
      subtitle: chatSummary.getLastMessagePreview(currentUserId),
      unreadCount: chatSummary.getUnreadCount(currentUserId),
      lastMessageTime: chatSummary.lastMessageTime,
      onTap: onTap,
      chatSummary: chatSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Colors based on theme
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final timeColor = isDark ? Colors.grey[500] : Colors.grey[500];
    final unreadColor = theme.primaryColor;
    
    return Container(
      color: isPinned 
          ? (isDark ? Colors.grey[850] : Colors.grey[100])
          : Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar with online status
                _buildAvatar(theme),
                
                const SizedBox(width: 16),
                
                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          // Title
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: unreadCount > 0 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Time
                          if (lastMessageTime != null) ...[
                            Text(
                              _formatTime(lastMessageTime!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: timeColor,
                                fontWeight: unreadCount > 0 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                              ),
                            ),
                            if (isPinned) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.push_pin,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                            ],
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Subtitle row
                      Row(
                        children: [
                          // Muted icon
                          if (isMuted) ...[
                            Icon(
                              Icons.volume_off,
                              size: 14,
                              color: subtitleColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          
                          // Subtitle
                          Expanded(
                            child: Text(
                              subtitle ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: unreadCount > 0 
                                    ? titleColor 
                                    : subtitleColor,
                                fontWeight: unreadCount > 0 
                                    ? FontWeight.w500 
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Unread count or status
                          if (unreadCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: unreadColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else if (isOnline) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Stack(
      children: [
        // Avatar image
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: theme.primaryColor.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildAvatarPlaceholder(theme),
                  )
                : _buildAvatarPlaceholder(theme),
          ),
        ),
        
        // Online status indicator
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(ThemeData theme) {
    return Container(
      color: theme.primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(time);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}
