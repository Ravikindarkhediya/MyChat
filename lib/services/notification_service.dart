import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

class NotificationService {

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _sendPushNotification(
    String receiverId,
    String senderName,
    String message,
  ) async {
    try {
      // 1️⃣ Get the FCM token for the receiver
      final userDoc = await _db.collection('users').doc(receiverId).get();
      final fcmToken = userDoc.get('fcmToken');

      if (fcmToken == null || fcmToken is! String) {
        Get.log('No FCM token found for user $receiverId');
        return;
      }

      // 2️⃣ Build notification payload
      final payload = {
        'to': fcmToken,
        'notification': {'title': senderName, 'body': message},
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'senderId': senderName,
        },
      };

      // 3️⃣ Send notification via FCM HTTP API
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_SERVER_KEY',
          // replace with your Firebase server key
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        Get.log('Notification sent to $receiverId');
      } else {
        Get.log('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      Get.log('Error sending push notification: $e');
    }
  }
}
