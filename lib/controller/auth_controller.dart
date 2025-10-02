import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';
import '../services/chat_services/chat_firebase_manager.dart';
import '../services/notification_service/notification_service.dart';
import '../services/user_service.dart';

/// Controller for handling authentication state and user management
class AuthController extends GetxController {
  static AuthController get instance => Get.find();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );
  final UserService _userService = UserService();
  final Logger _logger = Logger();
  
  // Reactive user state
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  UserModel? get currentUser => _currentUser.value;
  
  // Auth state
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isLoggedIn = false.obs;
  final RxBool isEmailVerified = false.obs;
  
  // Form fields
  final RxString email = ''.obs;
  final RxString password = ''.obs;
  
  // Setters for form fields
  void setEmail(String value) => email.value = value;
  void setPassword(String value) => password.value = value;
  
  // Stream subscriptions that need to be disposed
  final List<StreamSubscription> _subscriptions = [];
  
  @override
  void onInit() {
    super.onInit();
    _setupAuthStateListener();
  }
  
  @override
  void onClose() {
    // Cancel all subscriptions when the controller is disposed
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.onClose();
  }
  
  void _setupAuthStateListener() {
    _subscriptions.add(
      _auth.authStateChanges().listen((User? user) async {
        if (user != null) {
          await _handleSignedInUser(user);
        } else {
          _handleSignedOut();
        }
      })
    );
    
    // Listen for email verification status changes
    _subscriptions.add(
      _auth.userChanges().listen((User? user) {
        if (user != null) {
          isEmailVerified.value = user.emailVerified;
          _logger.d('Email verification status changed: ${user.emailVerified}');
        }
      })
    );
  }


  /// Sign in with Google
  Future<UserCredential?> googleSignIn() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Step 1: Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      // Step 2: Get authentication details
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Step 3: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      // Step 5: Convert to our UserModel
      final userModel = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        bannerUrl: '',
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      // Step 6: Save or update user in Firestore
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // New user → Save in Firestore
        await _userService.saveUser(userModel);
      } else {
        // Existing user → Update profile info
        await _userService.updateUser(firebaseUser.uid, {
          'name': firebaseUser.displayName ?? 'User',
          'email': firebaseUser.email ?? '',
          'photoUrl': firebaseUser.photoURL,
          'lastSeen': DateTime.now(),
          'isOnline': true,
        });
      }

      // Step 7: Update local state
      _currentUser.value = userModel;
      isLoggedIn.value = true;

      return userCredential;
    } catch (e) {
      errorMessage.value = 'Failed to sign in with Google: ${e.toString()}';
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ Update this method in AuthController
  Future<void> _initializeNotificationsForUser() async {
    try {
      if (currentUser == null) {
        _logger.w('Cannot initialize notifications: User data not available');
        return;
      }

      // ✅ Use ChatFirebaseManager instead of FirebaseNotificationService
      await ChatFirebaseManager().initChatNotifications(
        userId: currentUser!.uid,
        userName: currentUser!.name,
      );

      _logger.i('✅ Notifications initialized for user: ${currentUser!.uid}');
    } catch (e) {
      _logger.e('❌ Failed to initialize notifications: $e');
    }
  }

  // Handle signed in user
  Future<void> _handleSignedInUser(User user) async {
    try {
      // Get user data from Firestore
      final userData = await _userService.getUser(user.uid);
      
      if (userData != null) {
        _currentUser.value = userData;
        isLoggedIn.value = true;
        
        // Update user's online status
        await _userService.updateUserPresence(user.uid, true);
        // Initialize notifications for this signed-in user
        await _initializeNotificationsForUser();
      } else {
        // User not found in Firestore, create a new user
        final newUser = UserModel(
          uid: user.uid,
          email: user.email.toString(),
          name: user.displayName.toString(),
          photoUrl: user.photoURL,
          status: user.providerData.isNotEmpty 
              ? user.providerData.first.providerId 
              : 'email',
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        
        await _userService.saveUser(newUser);
        _currentUser.value = newUser;
        isLoggedIn.value = true;
        // Initialize notifications for newly created user as well
        await _initializeNotificationsForUser();
      }
    } catch (e) {
      errorMessage.value = 'Failed to load user data: ${e.toString()}';
      await _auth.signOut();
    }
  }

  /// Handles the signed-out user state
  void _handleSignedOut() {
    _logger.d('User signed out');
    _currentUser.value = null;
    isLoggedIn.value = false;
    isEmailVerified.value = false;
    errorMessage.value = '';
  }
}

