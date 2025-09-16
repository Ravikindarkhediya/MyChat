import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart'; // firebase import
import 'login_page.dart';
import 'home_page.dart'; // <-- apna homepage import kar

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _navigate();
  }

  void _navigate() {
    Timer(const Duration(seconds: 4), () {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // user logged-in hai
        Get.off(() => HomePage(),
            transition: Transition.fadeIn,
            duration: const Duration(milliseconds: 800));
      } else {
        // user logged-in nahi hai
        Get.off(() => LoginPage(),
            transition: Transition.fadeIn,
            duration: const Duration(milliseconds: 800));
      }
    });
  }
}

class SplashPage extends StatelessWidget {
  SplashPage({super.key});

  // Initialize controller
  final SplashController controller = Get.put(SplashController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2575FC),
      body: Center(
        child: Lottie.asset(
          "assets/icons/Chat_Bubble.json",
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
