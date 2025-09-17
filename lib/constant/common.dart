import 'dart:async';

import 'package:animated_background/animated_background.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:logger/logger.dart';

class Common{

  // Behaviour use for AnimatedBackground
  Behaviour buildBehaviour() {
    return RandomParticleBehaviour(
      options: const ParticleOptions(
        baseColor: Colors.white,
        spawnOpacity: 0.0,
        opacityChangeRate: 0.25,
        minOpacity: 0.1,
        maxOpacity: 0.4,
        spawnMinSpeed: 30.0,
        spawnMaxSpeed: 70.0,
        spawnMinRadius: 2.0,
        spawnMaxRadius: 6.0,
        particleCount: 80,
      ),
      paint: Paint()
        ..style = PaintingStyle.fill,
    );
  }

// Network status monitoring
  final Logger _logger = Logger();

  StreamSubscription setupNetworkListener({
    required RxString currentUserId,
    required VoidCallback onRestore,
  }) {
    return Connectivity().onConnectivityChanged.listen(
          (result) {
        if (result == ConnectivityResult.none) {
          Get.snackbar(
            'Error',
            'Internet connection lost',
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
        } else {
          if (currentUserId.value.isNotEmpty) {
            onRestore();
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