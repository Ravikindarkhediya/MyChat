// lib/services/firebase_notification_service.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../firebase_options.dart';

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // ✅ Initialize background message handler (call from main.dart)
  static Future<void> initializeBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestInitialPermissions();
    await _setupInitialFCMConfig();
  }

  // ✅ Background message handler (top-level function)
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print("📩 Background message: ${message.notification?.title}");
    print("📱 Message data: ${message.data}");

    // Handle background notification logic
    await _handleBackgroundNotification(message);
  }

  static Future<void> _handleBackgroundNotification(RemoteMessage message) async {
    // Background notification handling logic here
    // Update app badge, show local notification, etc.
  }

  // ✅ Request initial permissions
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

  // ✅ Initial FCM setup
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
    // Store initial message data for later processing
    // You can navigate after app is fully loaded
  }

  // ✅ Initialize for logged-in user
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
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@drawable/ic_stat_mind_zora');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📥 Foreground message: ${message.notification?.title}');
    // Show local notification or update UI
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 App opened from notification');
    _navigateFromNotification(message.data);
  }

  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _navigateFromNotification(data);
    }
  }

  void _navigateFromNotification(Map<String, dynamic> data) {
    final chatId = data['chatId'];
    final senderId = data['senderId'];
    final senderName = data['senderName'];

    if (chatId != null) {
      Get.toNamed('/chat', arguments: {
        'chatId': chatId,
        'otherUserId': senderId,
        'otherUserName': senderName,
      });
    }
  }

  Future<void> _saveFCMToken(String userId) async {
    // Save FCM token to Firestore
    // Implementation here...
  }

  // ✅ Cleanup
  Future<void> cleanup() async {
    // Clean up resources when user logs out
  }
}
