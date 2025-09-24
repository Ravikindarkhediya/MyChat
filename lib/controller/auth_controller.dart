import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';
import '../services/notification_service.dart';
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
      await _initializeNotificationsForUser();

      return userCredential;
    } catch (e) {
      errorMessage.value = 'Failed to sign in with Google: ${e.toString()}';
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _initializeNotificationsForUser() async {
    try {
      // Check if user data is available
      if (currentUser == null) {
        _logger.w('Cannot initialize notifications: User data not available');
        return;
      }

      await FirebaseNotificationService().initializeForUser(
        userId: currentUser!.uid,
        userName: currentUser!.name,
      );

      _logger.i('✅ Notifications initialized for user: ${currentUser!.uid}');
    } catch (e) {
      _logger.e('❌ Failed to initialize notifications: $e');
      // Don't block the login process if notifications fail
    }
  }



  Future<UserCredential?> _signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Email and password are required';
      return null;
    }

    try {
      _setLoading(true);

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null && !credential.user!.emailVerified) {
        await _sendVerificationEmail();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      _handleAuthErrorNew(e);
      return null;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred. Please try again.';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Public method for login button
  Future<void> login() async {
    await _signInWithEmailAndPassword(
      email: email.value.trim(),
      password: password.value,
    );
  }

  /// Sends a verification email to the current user
  Future<bool> _sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.sendEmailVerification();
      _logger.i('Verification email sent to ${user.email}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error sending verification email',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email, 
    String password, {
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Create user with email and password
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Update user profile
      await credential.user?.updateDisplayName(displayName);
      if (photoUrl != null) {
        await credential.user?.updatePhotoURL(photoUrl);
      }
      
      // Create user in Firestore
      final user = UserModel(
        uid: credential.user!.uid,
        email: email,
        name: displayName,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );
      
      await _userService.saveUser(user);
      
      return credential;
    } on FirebaseAuthException catch (e) {
      _handleAuthErrorNew(e);
      return null;
    } finally {
      isLoading.value = false;
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
  
  /// Updates the loading state and logs the change
  void _setLoading(bool loading) {
    isLoading.value = loading;
    _logger.d('Loading state changed: $loading');
  }
  
  /// Validates if the provided string is a valid email address
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
  
  /// Sends a password reset email to the specified email address
  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.isEmpty || !_isValidEmail(email)) {
      errorMessage.value = 'Please enter a valid email address';
      return false;
    }
    
    try {
      _setLoading(true);
      await _auth.sendPasswordResetEmail(email: email.trim());
      _logger.i('Password reset email sent to $email');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthErrorNew(e);
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error sending password reset email', 
        error: e, 
        stackTrace: stackTrace,
      );
      errorMessage.value = 'An error occurred. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }
  

  Future<bool> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      this.errorMessage.value = 'No user is currently signed in';
      return false;
    }
    
    try {
      isLoading.value = true;
      
      // Delete user document from Firestore
      await _userService.deleteUser(user.uid);
      
      // Delete Firebase Auth user
      await user.delete();
      
      // Log success
      return true;
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Re-authenticate and try again
        this.errorMessage.value = 'Please sign in again to confirm account deletion.';
      } else {
        _handleAuthErrorNew(e);
      }
      return false;
    } catch (e) {
      this.errorMessage.value = 'An error occurred while deleting your account.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }
  
  // Handle Firebase Auth errors - newer implementation
  void _handleAuthErrorNew(FirebaseAuthException e) {
    String message;
    
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found with this email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email.';
        break;
      case 'weak-password':
        message = 'The password is too weak.';
        break;
      case 'invalid-email':
        message = 'The email address is invalid.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many failed login attempts. Please try again later.';
        break;
      case 'operation-not-allowed':
        message = 'This operation is not allowed.';
        break;
      case 'account-exists-with-different-credential':
        message = 'An account already exists with the same email but different sign-in credentials.';
        break;
      default:
        message = 'An error occurred: ${e.message}';
    }
    
    this.errorMessage.value = message;
  }
}

