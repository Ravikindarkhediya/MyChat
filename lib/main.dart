import 'package:ads_demo/services/app_lifecycle_manager.dart';
import 'package:ads_demo/services/notification_service/notification_service.dart';
import 'package:ads_demo/view/splash_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// ✅ Updated main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Remove this line - we're using ChatFirebaseManager instead
  // await FirebaseNotificationService.initializeBackgroundHandler();

  // ✅ Add ChatFirebaseManager background handler
  FirebaseMessaging.onBackgroundMessage(_chatBackgroundMessageHandler);

  MobileAds.instance.initialize();
  runApp(const MyApp());
}

// ✅ Add this background handler
@pragma('vm:entry-point')
Future<void> _chatBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('📩 Background chat message: ${message.notification?.title}');
  print('📱 Message data: ${message.data}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleManager(
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: ThemeMode.system,
        home: SplashPage(),
      ),
    );
  }
}

