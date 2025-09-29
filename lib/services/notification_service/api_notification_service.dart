// lib/services/api_notification_service.dart (Updated)
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiNotificationService {
  static const String baseUrl = 'https://chat-app-nodejs-2.onrender.com';

  static Future<bool> sendNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String message,
    required String chatId,
    String messageType = 'text',
  }) async {
    try {
      print('🌐 API Call Starting...');
      print('🔗 URL: $baseUrl/send-notification');
      print('📦 Payload: {receiverId: $receiverId, senderId: $senderId, senderName: $senderName, chatId: $chatId, messageLen: ${message.length}, type: $messageType}');

      final response = await http
          .post(
          Uri.parse('$baseUrl/send-notification'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'receiverId': receiverId,
            'senderId': senderId,
            'senderName': senderName,
            'message': message,
            'chatId': chatId,
            'messageType': messageType,
          }))
          .timeout(const Duration(seconds: 15));

      print('📊 HTTP Response Status: ${response.statusCode}');
      print('📄 HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ API Notification sent: ${data['success']}');
        print('📋 Response: ${data['message']}');
        return data['success'] ?? false;
      } else {
        print('❌ API Notification failed: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending API notification: $e');
      return false;
    }
  }

  static Future<bool> sendCallNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String roomId,
    required bool isVideoCall,
  }) async {
    return await sendNotification(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName,
      message: isVideoCall ? 'Incoming video call from $senderName' : 'Incoming voice call from $senderName',
      chatId: roomId,
      messageType: isVideoCall ? 'video_call' : 'voice_call',
    );
  }

  static Future<bool> updateFCMToken({
    required String userId,
    required String fcmToken,
    String? deviceType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/$userId/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fcmToken': fcmToken,
          'deviceType': deviceType ?? 'flutter',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error updating FCM token via API: $e');
      return false;
    }
  }

  static Future<bool> sendFriendRequestNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'receiverId': receiverId,
          'senderId': senderId,
          'senderName': senderName,
          'message': '$senderName sent you a friend request',
          'chatId': '', // Empty for friend requests
          'messageType': 'friend_request',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error sending friend request notification: $e');
      return false;
    }
  }


}
