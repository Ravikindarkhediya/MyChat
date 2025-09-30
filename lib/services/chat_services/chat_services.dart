import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ads_demo/constant/common.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/enums.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger();
  String? _recentlyReadChatId;
  String? get _currentUserId => _auth.currentUser?.uid;


  void setRecentlyReadChat(String chatId) {
    _recentlyReadChatId = chatId;
  }

  String getChatId(String user1, String user2) {
    if (user1.isEmpty || user2.isEmpty) {
      throw ArgumentError('User IDs cannot be empty');
    }

    final sortedUsers = [user1, user2]..sort();
    return '${sortedUsers[0]}_${sortedUsers[1]}';
  }

  // Send voice message
  Future<MessageModel> sendVoiceMessage({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String audioPath,
    required int duration,
    String? senderPhotoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (senderId.isEmpty || receiverId.isEmpty) {
        throw ArgumentError('Sender ID and Receiver ID cannot be empty');
      }

      // Read audio file and convert to base64
      final audioFile = File(audioPath);
      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      final chatId = getChatId(senderId, receiverId);
      final messageRef = _db.collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final timestamp = FieldValue.serverTimestamp();
      final messageData = <String, dynamic>{
        'id': messageRef.id,
        'chatId': chatId,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': base64Audio, // Store base64 audio data
        'type': MessageType.audio.toString().split('.').last,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'timestamp': timestamp,
        'status': MessageStatus.sent.toString().split('.').last,
        'isRead': false,
        'isEdited': false,
        'metadata': {
          ...metadata ?? {},
          'duration': duration,
          'audioSize': audioBytes.length,
        },
      };

      final batch = _db.batch();

      batch.set(messageRef, messageData);

      batch.set(
        _db.collection('chats').doc(chatId),
        {
          'participants': [senderId, receiverId],
          'lastMessage': '🎵 Voice message',
          'lastMessageTime': timestamp,
          'lastMessageSenderId': senderId,
          'unreadCount_$senderId': 0,
          'unreadCount_$receiverId': FieldValue.increment(1),
          'updatedAt': timestamp,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (senderId != receiverId) {
        await _sendPushNotification(receiverId, senderName, '🎵 Voice message');
      }

      // Delete temporary audio file
      if (audioFile.existsSync()) {
        await audioFile.delete();
      }

      return MessageModel.fromMap({
        ...messageData,
        'timestamp': DateTime.now(),
      });

    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending voice message', error: e, stackTrace: StackTrace.current);
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error sending voice message', error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  // Convert base64 audio to file for playback
  Future<String> saveAudioFromBase64(String base64Audio, String messageId) async {
    try {
      final directory = await getTemporaryDirectory();
      final audioFile = File('${directory.path}/audio_$messageId.aac');

      if (!audioFile.existsSync()) {
        final audioBytes = base64Decode(base64Audio);
        await audioFile.writeAsBytes(audioBytes);
      }

      return audioFile.path;
    } catch (e) {
      _logger.e('Error saving audio from base64', error: e);
      rethrow;
    }
  }

  // Rest of your existing methods remain the same...
  Future<MessageModel> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    required String senderName,
    String? senderPhotoUrl,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (senderId.isEmpty || receiverId.isEmpty) {
        throw ArgumentError('Sender ID and Receiver ID cannot be empty');
      }

      final chatId = getChatId(senderId, receiverId);
      final messageRef = _db.collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final timestamp = FieldValue.serverTimestamp();
      final messageData = <String, dynamic>{
        'id': messageRef.id,
        'chatId': chatId,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': message,
        'type': type.toString().split('.').last,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'timestamp': timestamp,
        'status': MessageStatus.sent.toString().split('.').last,
        'isRead': false,
        'isEdited': false,
        'metadata': metadata ?? {},
      };

      final batch = _db.batch();

      batch.set(messageRef, messageData);

      batch.set(
        _db.collection('chats').doc(chatId),
        {
          'participants': [senderId, receiverId],
          'lastMessage': message,
          'lastMessageTime': timestamp,
          'lastMessageSenderId': senderId,
          'unreadCount_$senderId': 0,
          'unreadCount_$receiverId': FieldValue.increment(1),
          'updatedAt': timestamp,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (senderId != receiverId) {
        await _sendPushNotification(receiverId, senderName, message);
      }

      return MessageModel.fromMap({
        ...messageData,
        'timestamp': DateTime.now(),
      });

    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending message', error: e, stackTrace: StackTrace.current);
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error sending message', error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  // All other existing methods remain unchanged...
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      await _db.collection('chats').doc(chatId).update({
        'unreadCount_$userId': 0,
      });

      final messages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true, 'status': 'read'});
      }

      await batch.commit();

    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Stream<List<MessageModel>> getMessages({
    required String currentUserId,
    required String otherUserId,
    int limit = 50,
  }) {
    if (currentUserId.isEmpty || otherUserId.isEmpty) {
      return const Stream.empty();
    }

    final chatId = getChatId(currentUserId, otherUserId);

    markMessagesAsRead(chatId, currentUserId);

    return _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final filteredDocs = snapshot.docs.where((doc) {
        final deletedFor = (doc.data()['deletedFor'] ?? []) as List<dynamic>;
        return !deletedFor.contains(currentUserId);
      });

      // Preserve Firestore's descending order so it works with ListView.reverse = true
      return filteredDocs
          .map((doc) => MessageModel.fromMap({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
    });
  }

  Stream<List<ChatSummary>> getUserChats(String userId) {
    if (userId.isEmpty) return const Stream.empty();

    return _db.collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = {
        ...doc.data(),
        'id': doc.id,
      };

      if (_recentlyReadChatId == doc.id) {
        data['unreadCounts'] = {
          ...(data['unreadCounts'] ?? {}),
          _currentUserId: 0,
        };
      }

      return ChatSummary.fromMap(data);
    }).toList());
  }


  Future<List<ChatSummary>> fetchUserChats(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final snapshot = await _db.collection('chats')
          .where('participants', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ChatSummary.fromMap({
        ...doc.data(),
        'id': doc.id,
      }))
          .toList();
    } catch (e) {
      _logger.e('Error fetching user chats', error: e);
      return [];
    }
  }

  Future<UserModel?> getUserData(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      return UserModel.fromMap({
        ...doc.data() as Map<String, dynamic>,
        'uid': doc.id,
      });
    } on FirebaseException catch (e) {
      Get.log('Error getting user data: ${e.message}');
      return null;
    }
  }

  Future<bool> softDeleteChatForUser({
    required String currentUserId,
    required String friendUserId,
  }) async {
    if (currentUserId.isEmpty || friendUserId.isEmpty) return false;

    try {
      final chatId = getChatId(currentUserId, friendUserId);
      final chatRef = _db.collection('chats').doc(chatId);
      final messagesRef = chatRef.collection('messages');

      final batch = _db.batch();

      final messagesSnapshot = await messagesRef.get();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
        });
      }

      batch.update(chatRef, {
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
      });

      await batch.commit();

      Common().showSnackbar(
        'Success',
        'Chat cleared from your account',
        Colors.green,
      );

      return true;
    } catch (e) {
      Common().showSnackbar(
        'Error',
        'Failed to clear chat: $e',
        Colors.red,
      );
      return false;
    }
  }

  Future<List<UserModel>> searchUsers(String query, {String? excludeUserId}) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();

      final nameQuery = _db
          .collection('users')
          .where('searchTerms', arrayContains: queryLower);

      final emailQuery = _db
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThanOrEqualTo: queryLower + '\uf8ff');

      final [nameResults, emailResults] = await Future.wait([
        nameQuery.get(),
        emailQuery.get(),
      ]);

      final allResults = <String, UserModel>{};

      void addResults(QuerySnapshot snapshot) {
        for (var doc in snapshot.docs) {
          if (excludeUserId == null || doc.id != excludeUserId) {
            allResults[doc.id] = UserModel.fromMap({
              ...doc.data() as Map<String, dynamic>,
              'uid': doc.id,
            });
          }
        }
      }

      addResults(nameResults);
      addResults(emailResults);

      return allResults.values.toList();
    } on FirebaseException catch (e) {
      Get.log('Error searching users: ${e.message}');
      return [];
    }
  }

  Future<void> _sendPushNotification(
      String receiverId,
      String senderName,
      String message,
      ) async {
    try {
      final userDoc = await _db.collection('users').doc(receiverId).get();
      final fcmToken = userDoc.get('fcmToken');

      if (fcmToken == null || fcmToken is! String) {
        Get.log('No FCM token found for user $receiverId');
        return;
      }
    } catch (e) {
      Get.log('Error sending push notification: $e');
    }
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String currentUserId,
    bool deleteForEveryone = false,
  }) async {
    try {
      if (deleteForEveryone) {
        await _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .delete();
      } else {
        await _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e) {
      Get.snackbar('Error', 'Failed to delete message: ${e.message}');
      rethrow;
    }
  }

  Future<MessageModel?> updateMessage({
    required String chatId,
    required String messageId,
    required String newContent,
    String? currentUserId,
  }) async {
    try {
      final messageRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final updateData = {
        'content': newContent,
        'isEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await messageRef.update(updateData);

      final doc = await messageRef.get();
      if (!doc.exists) return null;

      return MessageModel.fromMap({
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      });
    } on FirebaseException catch (e) {
      Get.snackbar('Error', 'Failed to update message: ${e.message}');
      return null;
    }
  }


  Future<void> markChatAsRead(String chatId, String userId) async {
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

    await chatDoc.update({
      'unreadCount_$userId': 0,
    });

    // Optionally, update `readBy` for lastMessage too
    await chatDoc.collection('messages')
        .where('readBy', arrayContains: userId)
        .get()
        .then((snap) {
      for (var doc in snap.docs) {
        doc.reference.update({
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }
    });
  }
// Generate unique message ID
  String generateMessageId(String chatId) {
    final docRef = _db.collection('chats').doc(chatId).collection('messages').doc();
    return docRef.id;
  }

// Send using MessageModel
  Future<MessageModel> sendMessageModel(MessageModel message) async {
    final chatId = message.chatId;
    final messageRef = _db.collection('chats').doc(chatId).collection('messages').doc(message.id);

    await messageRef.set(message.toMap());

    // Optionally update chat summary
    await _db.collection('chats').doc(chatId).set({
      'participants': [message.senderId, message.receiverId],
      'lastMessage': message.content,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': message.senderId,
      'unreadCount_${message.receiverId}': FieldValue.increment(1),
    }, SetOptions(merge: true));

    return message;
  }

}
