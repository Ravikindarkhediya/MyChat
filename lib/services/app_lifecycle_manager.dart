// lib/services/app_lifecycle_manager.dart
import 'package:flutter/material.dart';

class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('📱 App lifecycle: $state');

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
        break;
    }
  }

  void _onAppResumed() {
    print('📱 App resumed');
    // Update user online status
    // Restart listeners if needed
  }

  void _onAppPaused() {
    print('📱 App paused');
    // Update user offline status
  }

  void _onAppDetached() {
    print('📱 App detached');
    // Clean up resources
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
