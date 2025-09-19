import 'dart:async';
import 'package:ads_demo/constant/common.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/enums.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger();

  String getChatId(String user1, String user2) {
    if (user1.isEmpty || user2.isEmpty) {
      throw ArgumentError('User IDs cannot be empty');
    }

    // Always put the lexicographically smaller ID first for consistency
    final sortedUsers = [user1, user2]..sort();
    return '${sortedUsers[0]}_${sortedUsers[1]}';
  }

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

      // Use batch to ensure both operations complete together
      final batch = _db.batch();

      // Add message to the chat
      batch.set(messageRef, messageData);

      // Update the last message in the chat summary
      batch.set(
        _db.collection('chats').doc(chatId),
        {
          'participants': [senderId, receiverId],
          'lastMessage': message,
          'lastMessageTime': timestamp,
          'lastMessageSenderId': senderId,
          'unreadCount_$senderId': 0, // Reset unread count for sender
          'unreadCount_$receiverId': FieldValue.increment(1), // Increment for receiver
          'updatedAt': timestamp,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Send push notification to the receiver
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


  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Reset unread count for this user in the chat summary
      await _db.collection("chats").doc(chatId).update({
        'unreadCount_$userId': 0,
      });
      
      // Mark individual messages as read
      final messages = await _db
          .collection("chats")
          .doc(chatId)
          .collection("messages")
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

    // Mark messages as read when we start listening
    markMessagesAsRead(chatId, currentUserId);

    return _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      // Filter out messages deleted for this user
      final filteredDocs = snapshot.docs.where((doc) {
        final deletedFor = (doc.data()['deletedFor'] ?? []) as List<dynamic>;
        return !deletedFor.contains(currentUserId);
      });

      return filteredDocs
          .map((doc) => MessageModel.fromMap({
        ...doc.data(),
        'id': doc.id,
      }))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  Stream<List<ChatSummary>> getUserChats(String userId) {
    if (userId.isEmpty) return const Stream.empty();

    return _db.collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatSummary.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }
  
  // स्ट्रीम के बजाय एक बार में यूजर चैट्स प्राप्त करने के लिए मेथड
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

      // Mark each message as deleted for current user
      final messagesSnapshot = await messagesRef.get();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
        });
      }

      // Also mark the chat document itself
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
      
      // Search by name
      final nameQuery = _db
          .collection('users')
          .where('searchTerms', arrayContains: queryLower);
      
      // Search by email
      final emailQuery = _db
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThanOrEqualTo: queryLower + '\uf8ff');
      
      final [nameResults, emailResults] = await Future.wait([
        nameQuery.get(),
        emailQuery.get(),
      ]);
      
      // Combine and deduplicate results
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
      // Get FCM token for the receiver
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
        // Permanently delete the message
        await _db
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .doc(messageId)
            .delete();
      } else {
        // Soft delete - mark as deleted for the current user
        await _db
            .collection("chats")
            .doc(chatId)
            .collection("messages")
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
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId);
      
      final updateData = {
        'content': newContent,
        'isEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await messageRef.update(updateData);
      
      // Get the updated message
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
}
