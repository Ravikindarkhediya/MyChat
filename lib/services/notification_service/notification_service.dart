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


}
