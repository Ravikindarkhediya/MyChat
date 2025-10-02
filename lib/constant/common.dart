import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

class Common {

  // Network status monitoring
  final Logger _logger = Logger();

  StreamSubscription setupNetworkListener({
    required RxString currentUserId,
    required Future<void> Function() onRestore,
  }) {
    return Connectivity().onConnectivityChanged.listen(
      (result) async {
        if (result == ConnectivityResult.none) {
          Get.snackbar(
            'Error',
            'Internet connection lost',
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
        } else {
          if (currentUserId.value.isNotEmpty) {
            await onRestore(); // 👈 correctly await karega
          }
        }
      },
      onError: (error) {
        _logger.e('Connectivity listener error', error: error);
      },
    );
  }

  // Helper methods for showing snackbars
  void showSnackbar(String title, String message, Color backgroundColor) {
    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }
}
