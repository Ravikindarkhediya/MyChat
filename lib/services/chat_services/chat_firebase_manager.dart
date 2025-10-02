import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controller/auth_controller.dart';
import '../notification_service/api_notification_service.dart';
import '../notification_service/notification_service.dart';

class ChatFirebaseManager {
  static final ChatFirebaseManager _instance = ChatFirebaseManager._internal();
  factory ChatFirebaseManager() => _instance;
  ChatFirebaseManager._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  String? _currentUserId;
  String? _currentUserName;

  // ================================
  // ✅ CHAT-SPECIFIC INITIALIZATION
  // ================================

  Future<void> initChatNotifications({
    required String userId,
    required String userName,
  }) async {
    _currentUserId = userId;
    _currentUserName = userName;

    NotificationSettings notificationSettings =
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      criticalAlert: true,
      carPlay: false,
      provisional: false,
    );

    if (notificationSettings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');

      // ✅ Remove topic subscriptions - not needed for chat
      // Instead, save user-specific FCM token to Firestore
      await _saveFCMTokenToFirestore();

      // ✅ Initialize local notifications with chat-specific settings
      await _initializeLocalNotifications();

      // ✅ Set up chat-specific message handlers
      _setChatMessageHandlers();

      print('✅ Chat notifications initialized for user: $userId');
    } else {
      print('❌ User declined notification permission');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // ✅ Chat-specific Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = const InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          print('💬 Chat notification payload: ${response.payload}');
          _handleChatNotificationClick(response.payload!);
        }
      },
    );

    // ✅ Create chat-specific notification channel
    await _createChatNotificationChannel();
  }

  Future<void> _createChatNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages', // Channel ID
      'Chat Messages', // Channel name
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ Chat notification channel created');
  }

  // ================================
  // ✅ FCM TOKEN MANAGEMENT FOR CHAT
  // ================================

  // ✅ Update the _saveFCMTokenToFirestore method in ChatFirebaseManager
  Future<void> _saveFCMTokenToFirestore() async {
    try {
      final String? fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken == null) {
        print('❌ Failed to get FCM token');
        return;
      }

      print('📱 FCM TOKEN: $fcmToken');

      // ✅ Save token to Firestore
      await _db.collection('users').doc(_currentUserId).set({
        'fcmToken': fcmToken,
        'deviceType': Platform.isIOS ? 'ios' : 'android',
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ Also send to API server
      await ApiNotificationService.updateFCMToken(
        userId: _currentUserId!,
        fcmToken: fcmToken,
        deviceType: Platform.isIOS ? 'ios' : 'android',
      );

      print('✅ FCM token saved to Firestore and API');

      // ✅ Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _updateTokenInFirestore(newToken);
      });

    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

// ✅ Update token refresh method
  Future<void> _updateTokenInFirestore(String newToken) async {
    try {
      await _db.collection('users').doc(_currentUserId).update({
        'fcmToken': newToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      // ✅ Also update on API server
      await ApiNotificationService.updateFCMToken(
        userId: _currentUserId!,
        fcmToken: newToken,
        deviceType: Platform.isIOS ? 'ios' : 'android',
      );

      print('✅ FCM token updated in Firestore and API');
    } catch (e) {
      print('❌ Error updating FCM token: $e');
    }
  }


  // ================================
  // ✅ CHAT-SPECIFIC MESSAGE HANDLERS
  // ================================

  void _setChatMessageHandlers() {
    // ✅ Foreground message handler for chat
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📥 Foreground chat message: ${message.notification?.title}');
      final String? messageType = message.data['messageType'];

      // ✅ Friend request notifications (send/accept/reject)
      if (messageType == 'friend_request' ||
          messageType == 'friend_request_accepted' ||
          messageType == 'friend_request_rejected') {
        await FirebaseNotificationService().showFriendRequestNotification(message);
        return;
      }

      // ✅ Chat message notifications
      final String? chatId = message.data['chatId'];
      final String? activeChatId = await _getActiveChatId();
      if (chatId != null && chatId != activeChatId) {
        await _showChatNotification(message);
      } else {
        print('🔇 User is in same chat, skipping notification');
      }
    });

    // ✅ Background message handler
    FirebaseMessaging.onBackgroundMessage(_chatBackgroundMessageHandler);

    // ✅ App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from notification');
      _handleChatNotificationClick(jsonEncode(message.data));
    });

    // ✅ Initial message when app starts from notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 App started from notification');
        _handleChatNotificationClick(jsonEncode(message.data));
      }
    });
  }

  // ================================
  // ✅ CHAT NOTIFICATION DISPLAY
  // ================================

  Future<void> _showChatNotification(RemoteMessage message) async {
    final String senderName = message.data['senderName'] ?? 'Unknown User';
    final String messageText = message.data['message'] ?? message.notification?.body ?? '';
    final String messageType = message.data['messageType'] ?? 'text';

    // ✅ Format notification body based on message type
    final String notificationBody = _formatChatNotificationBody(messageText, messageType);

    // ✅ Chat-specific Android notification settings
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages', // Use the channel we created
      'Chat Messages',
      importance: Importance.high,
      priority: Priority.high,
      ticker: '$senderName sent a message',
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_chat_avatar'),
      enableVibration: true,
      enableLights: true,
      playSound: true,
      autoCancel: true,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        notificationBody,
        contentTitle: senderName,
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ✅ Use timestamp as notification ID to avoid duplicates
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      senderName,
      notificationBody,
      platformDetails,
      payload: jsonEncode(message.data),
    );

    print('🔔 Chat notification shown: $senderName - $notificationBody');
  }

  // ✅ Format notification body based on message type
  String _formatChatNotificationBody(String message, String messageType) {
    switch (messageType) {
      case 'image':
        return '📷 Sent an image';
      case 'video':
        return '🎥 Sent a video';
      case 'audio':
        return '🎵 Sent an audio message';
      case 'document':
        return '📄 Sent a document';
      case 'location':
        return '📍 Shared location';
      default:
        return message.length > 100 ? '${message.substring(0, 100)}...' : message;
    }
  }

  // ================================
  // ✅ CHAT NOTIFICATION CLICK HANDLING
  // ================================

  void _handleChatNotificationClick(String payload) {
    try {
      if (payload.isEmpty) return;

      final Map<String, dynamic> data = jsonDecode(payload);
      final String? chatId = data['chatId'];
      final String? senderId = data['senderId'];
      final String? senderName = data['senderName'];

      print('💬 Opening chat: $chatId from user: $senderName');

      if (chatId != null) {
        // ✅ Navigate to chat screen using GetX
        Get.toNamed('/chat', arguments: {
          'chatId': chatId,
          'otherUserId': senderId,
          'otherUserName': senderName,
        });

        // ✅ Mark messages as read
        _markChatMessagesAsRead(chatId);

        // ✅ Set as active chat
        _setActiveChatId(chatId);
      }
    } catch (e) {
      print('❌ Error handling chat notification click: $e');
    }
  }

  // ================================
  // ✅ SENDING CHAT NOTIFICATIONS
  // ================================

  Future<void> sendChatNotification({
    required String receiverId,
    required String chatId,
    required String message,
    required String senderId,
    String? messageType,
    String? senderName,
  }) async {
    try {
      print('🚀 Starting API notification call...');
      print('📋 Data: receiverId=$receiverId, senderId=$senderId, chatId=$chatId');

      final success = await ApiNotificationService.sendNotification(
        receiverId: receiverId,
        senderId: senderId, // ✅ Use passed senderId
        senderName: senderName ?? 'Unknown User',
        message: message,
        chatId: chatId,
        messageType: messageType ?? 'text',
      );

      print('📤 API notification result: $success');

      if (success) {
        print('✅ Chat notification sent via API successfully');
      } else {
        print('❌ Failed to send chat notification via API');
      }

    } catch (e) {
      print('❌ Error sending chat notification: $e');
    }
  }


  // ================================
  // ✅ UTILITY METHODS
  // ================================

  Future<String?> _getActiveChatId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('active_chat_id');
    } catch (e) {
      return null;
    }
  }

  Future<void> _setActiveChatId(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_chat_id', chatId);

      // ✅ Also update in Firestore
      await _db.collection('users').doc(_currentUserId).update({
        'activeChatId': chatId,
      });
    } catch (e) {
      print('❌ Error setting active chat: $e');
    }
  }

  Future<void> _markChatMessagesAsRead(String chatId) async {
    try {
      // ✅ Update unread count
      await _db.collection('chats').doc(chatId).update({
        'unreadCount.$_currentUserId': 0,
      });

      // ✅ Mark individual messages as read
      final messagesQuery = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      print('✅ Messages marked as read in chat: $chatId');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  Future<void> updateUserOnlineStatus(bool isOnline) async {
    try {
      if (_currentUserId == null) return;

      await _db.collection('users').doc(_currentUserId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating online status: $e');
    }
  }

}

// ================================
// ✅ BACKGROUND MESSAGE HANDLER
// ================================

@pragma('vm:entry-point')
Future<void> _chatBackgroundMessageHandler(RemoteMessage message) async {
  print('📩 Background chat message: ${message.notification?.title}');

  await Firebase.initializeApp();

  // ✅ Handle background notification logic here
  print('Background message data: ${message.data}');
}
