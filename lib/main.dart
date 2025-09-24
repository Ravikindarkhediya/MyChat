import 'package:ads_demo/services/app_lifecycle_manager.dart';
import 'package:ads_demo/services/notification_service.dart';
import 'package:ads_demo/view/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseNotificationService.initializeBackgroundHandler();
  MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleManager(
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),       // Light theme
        darkTheme: ThemeData.dark(useMaterial3: true),    // Dark purple theme
        themeMode: ThemeMode.system,
        home: SplashPage(),
      ),
    );

  }
}
