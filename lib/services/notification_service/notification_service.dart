// lib/services/firebase_notification_service.dart (FIXED)
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart'; // ✅ ADD THIS FOR AlertDialog
import 'package:get/get.dart';
import '../../firebase_options.dart';
import '../calling_service.dart';
import 'api_notification_service.dart';

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final CallingService _callingService = CallingService();

  // Initialize background message handler (call from main.dart)
  static Future<void> initializeBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestInitialPermissions();
    await _setupInitialFCMConfig();
  }

  // Background message handler (top-level function)
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print("📩 Background message: ${message.notification?.title}");
    print("📱 Message data: ${message.data}");

    await _handleBackgroundNotification(message);
  }

  static Future<void> _handleBackgroundNotification(RemoteMessage message) async {
    final messageType = message.data['messageType'];

    if (messageType == 'video_call' || messageType == 'voice_call') {
      await _showIncomingCallNotification(message);
    } else if (messageType == 'friend_request' ||
        messageType == 'friend_request_accepted' ||
        messageType == 'friend_request_rejected') {
      await _showFriendRequestBackgroundNotification(message);
    }
  }
  static Future<void> _showFriendRequestBackgroundNotification(RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'friend_request_channel',
      'Friend Requests',
      channelDescription: 'Notifications for friend requests',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final senderName = message.data['senderName'] ?? 'Someone';
    final messageType = message.data['messageType'] ?? 'friend_request';
    final status = (message.data['status'] ?? '').toString();

    final bool accepted = messageType == 'friend_request_accepted' || status == 'accepted';
    final bool rejected = messageType == 'friend_request_rejected' || status == 'rejected';

    final String title = (accepted || rejected) ? 'Friend Request Update' : 'Friend Request';
    final String body = accepted
        ? '$senderName accepted your friend request'
        : rejected
            ? '$senderName declined your friend request'
            : '$senderName sent you a friend request';

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }
  static Future<void> _showIncomingCallNotification(RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      showWhen: false,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher', // ✅ FIXED ICON
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('answer', 'Answer'),
        AndroidNotificationAction('decline', 'Decline'),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'call_category',
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final senderName = message.data['senderName'] ?? 'Unknown';
    final isVideoCall = message.data['messageType'] == 'video_call';

    await localNotifications.show(
      999, // Use a fixed ID for call notifications
      '${isVideoCall ? 'Video' : 'Voice'} Call',
      'Incoming call from $senderName',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Request initial permissions
  static Future<void> _requestInitialPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        criticalAlert: true,
        carPlay: false,
        provisional: false,
      );

      print('🔔 Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  // Initial FCM setup
  static Future<void> _setupInitialFCMConfig() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final token = await messaging.getToken();
      print('🔑 Initial FCM Token: $token');

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App opened from notification');
        await _handleInitialMessage(initialMessage);
      }
    } catch (e) {
      print('❌ Error in FCM setup: $e');
    }
  }

  static Future<void> _handleInitialMessage(RemoteMessage message) async {
    // Handle when app is opened from notification
    final messageType = message.data['messageType'];
    if (messageType == 'video_call' || messageType == 'voice_call') {
      // Navigate to call screen or auto-join
      Get.toNamed('/call_screen', arguments: message.data);
    }
  }

  // Initialize for logged-in user
  Future<void> initializeForUser({
    required String userId,
    required String userName,
  }) async {
    try {
      await _initializeLocalNotifications();
      _setupMessageHandlers();
      await _saveFCMToken(userId);

      print('✅ Notification service initialized for user: $userId');
    } catch (e) {
      print('❌ Failed to initialize for user: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // ✅ FIXED: Using launcher icon instead of missing custom icon
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Setup call notification channel for Android
    const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
      'call_channel',
      'Incoming Calls',
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);
  }

  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📥 Foreground message: ${message.notification?.title}');

    final messageType = message.data['messageType'];
    if (messageType == 'video_call' || messageType == 'voice_call') {
      await _showIncomingCallDialog(message);
    } else if (messageType == 'friend_request' ||
        messageType == 'friend_request_accepted' ||
        messageType == 'friend_request_rejected') {
      await showFriendRequestNotification(message);
    } else {
      await _showLocalNotification(message);
    }
  }
  Future<void> showFriendRequestNotification(RemoteMessage message) async {
    final senderName = message.data['senderName'] ?? 'Someone';
    final messageType = message.data['messageType'] ?? 'friend_request';
    final status = (message.data['status'] ?? '').toString();

    final bool accepted = messageType == 'friend_request_accepted' || status == 'accepted';
    final bool rejected = messageType == 'friend_request_rejected' || status == 'rejected';

    final String title = (accepted || rejected) ? 'Friend Request Update' : 'Friend Request';
    final String body = accepted
        ? '$senderName accepted your friend request'
        : rejected
            ? '$senderName declined your friend request'
            : '$senderName sent you a friend request';

    Get.defaultDialog(
      title: title,
      middleText: body,
      backgroundColor: Colors.white,
      titleStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      middleTextStyle: const TextStyle(color: Colors.black54, fontSize: 14),
      barrierDismissible: true,
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            // Optionally navigate to friend requests screen
            Get.toNamed('/friend_requests');
          },
          child: const Text('View Requests', style: TextStyle(color: Colors.blue)),
        ),
        ElevatedButton(
          onPressed: () {
            Get.back();
            Get.snackbar('Info', 'Check your friend requests to proceed');
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('OK', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
  Future<void> _showIncomingCallDialog(RemoteMessage message) async {
    final senderName = message.data['senderName'] ?? 'Unknown';
    final roomId = message.data['chatId'];
    final isVideoCall = message.data['messageType'] == 'video_call';

    // ✅ OPTION 1: Using GetX Dialog (Recommended)
    Get.defaultDialog(
      title: '${isVideoCall ? 'Video' : 'Voice'} Call',
      middleText: 'Incoming call from $senderName',
      backgroundColor: Colors.white,
      titleStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      middleTextStyle: const TextStyle(color: Colors.black54, fontSize: 14),
      barrierDismissible: false,
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            print('Call declined from $senderName');
          },
          child: const Text('Decline', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () async {
            Get.back();
            print('Answering call from $senderName');
            try {
              await _callingService.answerCall(roomId, 'Current User', isVideoCall: isVideoCall);
            } catch (e) {
              print('Error answering call: $e');
              Get.snackbar('Error', 'Failed to join call: $e');
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Answer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default',
      channelDescription: 'Default notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 App opened from notification');
    _navigateFromNotification(message.data);
  }

  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);

      // Handle call notification actions
      if (response.actionId == 'answer') {
        final roomId = data['chatId'];
        final isVideoCall = data['messageType'] == 'video_call';
        print('Answering call from notification...');
        _callingService.answerCall(roomId, 'Current User', isVideoCall: isVideoCall);
      } else if (response.actionId == 'decline') {
        print('Call declined from notification');
        Get.snackbar('Call', 'Call declined');
      } else {
        _navigateFromNotification(data);
      }
    }
  }

  void _navigateFromNotification(Map<String, dynamic> data) {
    final messageType = data['messageType'];

    if (messageType == 'video_call' || messageType == 'voice_call') {
      print('Navigating to call screen...');
      Get.toNamed('/call_screen', arguments: data);
    } else if (messageType == 'friend_request') {
      // ✅ YE NAYA CASE ADD KARO
      print('Navigating to friend requests screen...');
      Get.toNamed('/friend_requests');
    } else {
      // Navigate to chat
      final chatId = data['chatId'];
      final senderId = data['senderId'];
      final senderName = data['senderName'];

      if (chatId != null) {
        print('Navigating to chat screen...');
        Get.toNamed('/chat', arguments: {
          'chatId': chatId,
          'otherUserId': senderId,
          'otherUserName': senderName,
        });
      }
    }
  }

  Future<void> _saveFCMToken(String userId) async {
    try {
      print('🔄 Starting FCM token retrieval for user: $userId');

      // Get fresh token
      final token = await _firebaseMessaging.getToken();

      if (token == null) {
        print('❌ FCM Token is null - requesting permissions first');
        await _requestNotificationPermissions();

        // Try again after permissions
        await Future.delayed(Duration(seconds: 2));
        final retryToken = await _firebaseMessaging.getToken();

        if (retryToken == null) {
          print('❌ FCM Token still null after permission request');
          return;
        }

        print('✅ FCM Token retrieved after permission: ${retryToken.substring(0, 20)}...');
      } else {
        print('✅ FCM Token retrieved: ${token.substring(0, 20)}...');
      }

      final finalToken = token ?? await _firebaseMessaging.getToken();

      if (finalToken != null) {
        // ✅ STEP 1: Save to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': finalToken,
          'tokenTimestamp': FieldValue.serverTimestamp(),
          'deviceInfo': {
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'appVersion': '1.0.0',
          }
        });
        print('💾 FCM Token saved to Firestore: ✅');

        // ✅ STEP 2: Save to Backend API
        final apiSuccess = await ApiNotificationService.updateFCMToken(
          userId: userId,
          fcmToken: finalToken,
          deviceType: Platform.isAndroid ? 'android' : 'ios',
        );
        print('💾 FCM Token saved to Backend: ${apiSuccess ? '✅' : '❌'}');

        // ✅ STEP 3: Test token by sending test notification
        await _validateTokenWithTestNotification(userId, finalToken);

      } else {
        print('❌ Unable to get FCM token');
      }
    } catch (e) {
      print('❌ Error in FCM token management: $e');
    }
  }
  Future<void> _validateTokenWithTestNotification(String userId, String token) async {
    try {
      print('🧪 Testing FCM token with test notification...');

      // Send test notification via API
      final testResult = await ApiNotificationService.sendNotification(
        receiverId: userId,
        senderId: userId,
        senderName: 'System Test',
        message: 'FCM Token is working! 🎉',
        chatId: 'test_notification',
        messageType: 'test',
      );

      print('🧪 Test notification result: ${testResult ? '✅ SUCCESS' : '❌ FAILED'}');

      if (!testResult) {
        print('⚠️ Token validation failed - may need to refresh token');
      }

    } catch (e) {
      print('❌ Token validation error: $e');
    }
  }

  // ✅ ADD: Request permissions properly
  Future<void> _requestNotificationPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        criticalAlert: false,
        carPlay: false,
        provisional: false,
      );

      print('🔔 Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ Notification permissions denied');
        Get.snackbar(
          'Permissions Required',
          'Please enable notifications to receive friend requests',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Permission request error: $e');
    }
  }
  // Cleanup
  Future<void> cleanup() async {
    _callingService.dispose();
    print('🧹 Firebase notification service cleaned up');
  }
}
