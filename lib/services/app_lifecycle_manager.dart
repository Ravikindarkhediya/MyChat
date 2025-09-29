import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/user_service.dart';

class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {

  // ✅ USER SERVICE INSTANCE
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅  APP START HONE PAR USER KO ONLINE SET KARO
    _setUserOnlineIfLoggedIn();
  }

  @override
  void dispose() {
    // ✅  APP DISPOSE HONE PAR USER KO OFFLINE SET KARO
    _setUserOfflineIfLoggedIn();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      // ✅ YE CASE BHI HANDLE KARO
        _onAppPaused();
        break;
    }
  }

  // ✅ YE METHODS UPDATE KARO
  void _onAppResumed() {
    print('📱 App resumed - Setting user online');
    // Update user online status
    _setUserOnlineIfLoggedIn();
    // Restart listeners if needed
    // You can add more functionality here like reconnecting to streams
  }

  void _onAppPaused() {
    print('📱 App paused - Setting user offline');
    // Update user offline status
    _setUserOfflineIfLoggedIn();
  }

  void _onAppDetached() {
    print('📱 App detached - Setting user offline');
    // Clean up resources and set offline
    _setUserOfflineIfLoggedIn();
  }

  // ✅ YE HELPER METHODS ADD KARO
  void _setUserOnlineIfLoggedIn() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userService.setUserOnline(currentUser.uid);
      print('✅ User set online: ${currentUser.uid}');
    }
  }

  void _setUserOfflineIfLoggedIn() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userService.setUserOffline(currentUser.uid);
      print('❌ User set offline: ${currentUser.uid}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
