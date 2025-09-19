import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'enums.dart';

final _logger = Logger();

@immutable
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String content;
  final String? senderName;
  final String? senderPhotoUrl;
  final DateTime timestamp;
  final bool isRead;
  final MessageStatus status;
  final bool isEdited;
  final String? mediaUrl;
  final MessageType type;
  final Map<String, dynamic> metadata;
  final List<String>? deletedFor; // User IDs who have deleted this message
  final String? replyToMessageId; // For reply messages
  final List<String>? readBy; // User IDs who have read this message

   MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.senderName,
    this.senderPhotoUrl,
    DateTime? timestamp,
    this.isRead = false,
    this.status = MessageStatus.sent,
    this.isEdited = false,
    this.mediaUrl,
    this.type = MessageType.text,
    Map<String, dynamic>? metadata,
    this.deletedFor,
    this.replyToMessageId,
    this.readBy,
  }) : 
        timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? {};

  /// Creates a MessageModel from a Firestore document
  /// 
  /// Throws [FormatException] if the document data is invalid
  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    try {
      if (!doc.exists) {
        throw FormatException('Document does not exist');
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw FormatException('Document data is null');
      }
      
      return MessageModel._fromMap({
        ...data,
        'id': doc.id,
      });
    } catch (e, stackTrace) {
      _logger.e('Error creating MessageModel from document', 
        error: e, 
        stackTrace: stackTrace
      );
      rethrow;
    }
  }
  
  /// Creates a MessageModel from a map of data
  /// 
  /// Throws [FormatException] if the data is invalid
  factory MessageModel.fromMap(Map<String, dynamic> data) {
    try {
      return MessageModel._fromMap(data);
    } catch (e, stackTrace) {
      _logger.e('Error creating MessageModel from map', 
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  // Private constructor for internal use
  factory MessageModel._fromMap(Map<String, dynamic> data) {
    // Validate required fields
    final requiredFields = ['id', 'chatId', 'senderId', 'receiverId', 'content'];
    for (final field in requiredFields) {
      if (data[field] == null) {
        throw FormatException('Missing required field: $field');
      }
    }

    // Parse status with improved error handling
    MessageStatus status;
    try {
      final statusStr = data['status']?.toString();
      if (statusStr != null) {
        final statusMatch = MessageStatus.values.firstWhere(
          (e) => e.toString() == 'MessageStatus.$statusStr' || 
                 e.toString() == statusStr,
          orElse: () => MessageStatus.sent,
        );
        status = statusMatch;
      } else {
        status = MessageStatus.sent;
      }
    } catch (e, stackTrace) {
      _logger.w('Error parsing message status, defaulting to sent', 
        error: e,
        stackTrace: stackTrace,
      );
      status = MessageStatus.sent;
    }
    
    // Parse message type
    MessageType type;
    try {
      type = MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type']}' || e.toString() == data['type'],
        orElse: () => MessageType.text,
      );
    } catch (e) {
      type = MessageType.text;
    }
    
    // Parse timestamp with fallback
    DateTime parseTimestamp() {
      try {
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) {
          return timestamp.toDate();
        } else if (timestamp is DateTime) {
          return timestamp;
        } else if (timestamp is String) {
          return DateTime.parse(timestamp).toLocal();
        } else if (timestamp is int) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
        }
        return DateTime.now();
      } catch (e, stackTrace) {
        _logger.w('Error parsing timestamp, using current time',
          error: e,
          stackTrace: stackTrace,
        );
        return DateTime.now();
      }
    }

    return MessageModel(
      id: data['id'] as String,
      chatId: data['chatId'] as String,
      senderId: data['senderId'] as String,
      receiverId: data['receiverId'] as String,
      content: data['content'] as String,
      senderName: data['senderName'] as String?,
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      timestamp: parseTimestamp(),
      isRead: data['isRead'] == true,
      status: status,
      isEdited: data['isEdited'] == true,
      mediaUrl: data['mediaUrl'] as String?,
      type: type,
      metadata: data['metadata'] is Map 
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : {},
      deletedFor: data['deletedFor'] is List
          ? List<String>.from(data['deletedFor'] as List)
          : null,
      replyToMessageId: data['replyToMessageId'] as String?,
      readBy: data['readBy'] is List
          ? List<String>.from(data['readBy'] as List)
          : null,
    );
  }

  /// Converts the message to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.toString().split('.').last,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'timestamp': timestamp,
      'isRead': isRead,
      'status': status.toString().split('.').last,
      'isEdited': isEdited,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      if (deletedFor != null) 'deletedFor': deletedFor,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (readBy != null) 'readBy': readBy,
    };
  }

  /// Creates a copy of the message with updated fields
  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? content,
    String? senderName,
    String? senderPhotoUrl,
    DateTime? timestamp,
    bool? isRead,
    MessageStatus? status,
    bool? isEdited,
    String? mediaUrl,
    MessageType? type,
    Map<String, dynamic>? metadata,
    List<String>? deletedFor,
    String? replyToMessageId,
    List<String>? readBy,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      deletedFor: deletedFor ?? this.deletedFor,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      readBy: readBy ?? this.readBy,
    );
  }

  /// Checks if the message is sent by the current user
  bool isSentByMe(String currentUserId) => senderId == currentUserId;

  /// Checks if the message is deleted for the given user
  bool isDeletedForUser(String userId) => 
      deletedFor?.contains(userId) ?? false;

  /// Checks if the message is read by the given user
  bool isReadBy(String userId) => 
      readBy?.contains(userId) ?? false;

  /// Checks if the message contains media
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  /// Gets the status icon for the message
  String get statusIcon {
    switch (status) {
      case MessageStatus.sending:
        return '🕒'; // Clock icon
      case MessageStatus.sent:
        return '✓'; // Single check
      case MessageStatus.delivered:
        return '✓✓'; // Double check
      case MessageStatus.read:
        return '✓✓✓'; // Double check with blue color (handled in UI)
      case MessageStatus.failed:
        return '!'; // Exclamation mark
      case MessageStatus.deleted:
        return '🗑️'; // Trash icon for deleted messages
    }
  }

  /// Gets the formatted time (HH:mm)
  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Gets a formatted date string (Today/Yesterday/Date)
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return 'Today, $formattedTime';
    } else if (messageDate == yesterday) {
      return 'Yesterday, $formattedTime';
    } else {
      return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}, $formattedTime';
    }
  }

  // Message type checks
  bool get isTextMessage => type == MessageType.text && content.isNotEmpty;
  bool get isImage => type == MessageType.image && hasMedia;
  bool get isVideo => type == MessageType.video && hasMedia;
  bool get isAudio => type == MessageType.audio && hasMedia;
  bool get isLocation => type == MessageType.location && hasMedia;
  bool get isContact => type == MessageType.contact && hasMedia;
  bool get isSticker => type == MessageType.sticker && hasMedia;
  bool get isGif => type == MessageType.gif && hasMedia;
  bool get isVoiceNote => type == MessageType.voiceNote && hasMedia;
}

/// Model for chat summary (shows in chat list)
@immutable
class ChatSummary {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final String? lastMessageSenderName;
  final String? lastMessageSenderPhotoUrl;
  final MessageType lastMessageType;
  final Map<String, int> unreadCounts;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

   ChatSummary({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.lastMessageSenderPhotoUrl,
    this.lastMessageType = MessageType.text,
    Map<String, int>? unreadCounts,
    DateTime? updatedAt,
    this.metadata,
  }) : unreadCounts = unreadCounts ?? {},
        updatedAt = updatedAt ?? DateTime.now();

  /// Creates a ChatSummary from a map of data
  factory ChatSummary.fromMap(Map<String, dynamic> map) {
    final unreadCounts = <String, int>{};

    // Extract unread counts
    map.forEach((key, value) {
      if (key.startsWith('unreadCount_')) {
        final userId = key.replaceFirst('unreadCount_', '');
        unreadCounts[userId] = (value as num).toInt();
      }
    });
    
    // Parse message type
    MessageType messageType;
    try {
      messageType = MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['lastMessageType']}' || 
               e.toString() == map['lastMessageType'],
        orElse: () => MessageType.text,
      );
    } catch (e) {
      messageType = MessageType.text;
    }

    return ChatSummary(
      chatId: map['chatId'] ?? map['id'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? 
                     (map['updatedAt'] as Timestamp?)?.toDate() ?? 
                     DateTime.now(),
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageSenderName: map['lastMessageSenderName'],
      lastMessageSenderPhotoUrl: map['lastMessageSenderPhotoUrl'],
      lastMessageType: messageType,
      unreadCounts: unreadCounts,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }

  /// Gets the unread message count for a specific user
  int getUnreadCount(String userId) => unreadCounts[userId] ?? 0;
  
  /// Checks if the chat has unread messages for a specific user
  bool hasUnreadMessages(String userId) => getUnreadCount(userId) > 0;
  
  /// Gets the ID of the other participant in a 1:1 chat
  // Get the other participant's ID
  String? getOtherParticipantId(String currentUserId) {
    if (participants.length < 2) return null;
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  /// Gets a preview of the last message
  String getLastMessagePreview(String currentUserId) {
    if (lastMessageSenderId == currentUserId) {
      return 'You: $lastMessage';
    }
    
    final senderName = lastMessageSenderName ?? 'Someone';
    return '$senderName: $lastMessage';
  }
  
  /// Creates a copy of the chat summary with updated fields
  ChatSummary copyWith({
    String? chatId,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
    String? lastMessageSenderPhotoUrl,
    MessageType? lastMessageType,
    Map<String, int>? unreadCounts,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ChatSummary(
      chatId: chatId ?? this.chatId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageSenderPhotoUrl: lastMessageSenderPhotoUrl ?? this.lastMessageSenderPhotoUrl,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Converts the chat summary to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastMessageSenderId': lastMessageSenderId,
      if (lastMessageSenderName != null) 'lastMessageSenderName': lastMessageSenderName,
      if (lastMessageSenderPhotoUrl != null) 'lastMessageSenderPhotoUrl': lastMessageSenderPhotoUrl,
      'lastMessageType': lastMessageType.toString().split('.').last,
      ...unreadCounts.map((key, value) => MapEntry('unreadCount_$key', value)),
      'updatedAt': updatedAt,
      if (metadata != null) 'metadata': metadata,
    };
  }

  String getChatTitle(String currentUserId, {int maxLength = 20}) {
    if (metadata == null || metadata!['participantsData'] == null) {
      return 'Group Chat';
    }

    final participantsData = Map<String, dynamic>.from(metadata!['participantsData']);

    final otherParticipants = participantsData.entries
        .where((entry) => entry.key != currentUserId)
        .map((e) => e.value['name'] ?? 'Unknown User')
        .toList();

    if (otherParticipants.isEmpty) return 'Unknown Chat';

    final title = otherParticipants.join(', ');
    return title.length > maxLength
        ? '${title.substring(0, maxLength)}...'
        : title;
  }


  // Get chat subtitle (last message preview)
  String getChatSubtitle(String currentUserId) {
    final isMe = lastMessageSenderId == currentUserId;
    final prefix = isMe ? 'You: ' : '';
    
    if (lastMessageType == 'image') {
      return '${prefix}📷 Photo';
    } else if (lastMessageType == 'video') {
      return '${prefix}🎥 Video';
    } else if (lastMessageType == 'audio') {
      return '${prefix}🎵 Audio';
    } else if (lastMessageType == 'document') {
      return '${prefix}📄 Document';
    } else if (lastMessageType == 'location') {
      return '${prefix}📍 Location';
    } else if (lastMessageType == 'contact') {
      return '${prefix}👤 Contact';
    } else if (lastMessageType == 'sticker') {
      return '${prefix}🎨 Sticker';
    }
    
    return '$prefix$lastMessage';
  }

  // Get formatted time of last message
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(
      lastMessageTime.year, 
      lastMessageTime.month, 
      lastMessageTime.day
    );

    if (messageDate == today) {
      final hour = lastMessageTime.hour.toString().padLeft(2, '0');
      final minute = lastMessageTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${lastMessageTime.day}/${lastMessageTime.month}/${lastMessageTime.year}';
    }
  }
}
