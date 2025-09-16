import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';
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

  Future<UserCredential?> signInWithEmailAndPassword({
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
      
      return credential;
    } catch (e) {
      if (e is FirebaseAuthException) {
        _handleAuthErrorNew(e);
      } else {
        errorMessage.value = 'An unexpected error occurred. Please try again.';
      }
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Login method for the login button
  void login() async {
    if (email.value.isEmpty || password.value.isEmpty) {
      errorMessage.value = 'Email and password are required';
      return;
    }
    
    try {
      _setLoading(true);
      
      await signInWithEmailAndPassword(
        email: email.value.trim(),
        password: password.value,
      );
      
    } catch (e) {
      if (e is FirebaseAuthException) {
        _handleAuthErrorNew(e);
      } else {
        errorMessage.value = 'An unexpected error occurred. Please try again.';
      }
    } finally {
      _setLoading(false);
    }
  }
  
  /// Sign in with Google
  Future<UserCredential?> googleSignIn() async {
    try {
      _setLoading(true);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Convert Firebase User to your UserModel / PigeonUserDetails
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      final userModel = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      _currentUser.value = userModel;
      isLoggedIn.value = true;

      // Save user in Firestore if needed
      await _userService.saveUser(userModel);

      return userCredential;

    } catch (e) {
      errorMessage.value = 'Failed to sign in with Google: ${e.toString()}';
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  void _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          errorMessage.value = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage.value = 'Wrong password';
          break;
        case 'invalid-email':
          errorMessage.value = 'Invalid email format';
          break;
        case 'user-disabled':
          errorMessage.value = 'This account has been disabled';
          break;
        default:
          errorMessage.value = 'Authentication failed: ${error.message}';
      }
    } else {
      errorMessage.value = 'Authentication failed: $error';
    }
    _logger.e('Authentication error', error: error);
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
      
      if (credential.user != null) {
        _logger.i('User signed in: ${credential.user!.uid}');
        
        // Check if email is verified if required
        if (!credential.user!.emailVerified) {
          _logger.w('Email not verified for user: ${credential.user!.uid}');
          // Optionally: Send verification email
          await _sendVerificationEmail();
        }
      }
      
      return credential;
      
    } on FirebaseAuthException catch (e) {
      _handleAuthErrorNew(e);
      return null;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during sign in', 
        error: e, 
        stackTrace: stackTrace,
      );
      errorMessage.value = 'An unexpected error occurred. Please try again.';
      return null;
    } finally {
      _setLoading(false);
    }
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

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Once signed in, return the UserCredential
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Check if user is new or existing
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        // Create user in Firestore
        final user = UserModel(
          uid: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'User',
          email: userCredential.user!.email ?? '',
          photoUrl: userCredential.user!.photoURL,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        
        await _userService.saveUser(user);
      }
      
      return userCredential;
    } catch (e) {
      errorMessage.value = 'Failed to sign in with Google: ${e.toString()}';
      return null;
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Update user's online status
      if (_auth.currentUser != null) {
        await _userService.updateUserPresence(_auth.currentUser!.uid, false);
      }
      
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      // Sign out from Firebase
      await _auth.signOut();
      
      // Clear current user
      _currentUser.value = null;
      isLoggedIn.value = false;
    } catch (e) {
      errorMessage.value = 'Failed to sign out: ${e.toString()}';
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }
  
  // This method has been replaced by the implementation at line ~600
  
  // This method has been replaced by the implementation at line ~600
  // Keeping the method signature for reference
  Future<void> _updateProfileOld({
    String? displayName,
    String? photoURL,
  }) async {
    // Implementation removed to avoid duplication
    return;
  }
  
  // This method has been replaced by the implementation at line ~650
  Future<bool> _deleteAccountOld() async {
    // Implementation removed to avoid duplication
    return false;
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
  
  /// Updates the current user's profile
  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      errorMessage.value = 'No user is currently signed in';
      return false;
    }
    
    try {
      _setLoading(true);
      
      // Update Firebase Auth profile
      await user.updateDisplayName(displayName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      
      // Update Firestore user document
      final currentUser = _currentUser.value;
      if (currentUser != null) {
        final updatedUser = UserModel(
          uid: currentUser.uid,
          name: displayName ?? currentUser.name,
          email: currentUser.email,
          photoUrl: photoURL ?? currentUser.photoUrl,
          isOnline: currentUser.isOnline,
          lastSeen: currentUser.lastSeen,
          createdAt: currentUser.createdAt,
          bio: currentUser.bio,
          status: currentUser.status,
          bannerUrl: currentUser.bannerUrl,
          friends: currentUser.friends,
          friendRequests: currentUser.friendRequests,
          settings: currentUser.settings,
          updatedAt: DateTime.now(),
        );
        
        await _userService.saveUser(updatedUser);
        _currentUser.value = updatedUser;
      }
      
      _logger.i('Profile updated successfully');
      return true;
      
    } on FirebaseAuthException catch (e) {
      _handleAuthErrorNew(e);
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error updating profile', 
        error: e, 
        stackTrace: stackTrace,
      );
      errorMessage.value = 'An error occurred while updating your profile.';
      return false;
    } finally {
      _setLoading(false);
    }
  }
  Future<void> logout() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final user = _auth.currentUser;

      // Update Firestore presence
      if (user != null) {
        await _userService.updateUserPresence(user.uid, false);
      }

      // Sign out from Google if signed in
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Sign out from Firebase
      await _auth.signOut();

      // Clear local state
      _currentUser.value = null;
      isLoggedIn.value = false;
      isEmailVerified.value = false;

      _logger.i('User successfully logged out');
    } catch (e) {
      errorMessage.value = 'Failed to logout: ${e.toString()}';
      _logger.e('Logout error', error: e);
    } finally {
      isLoading.value = false;
    }
  }
  /// Deletes the current user's account
  /// 
  /// Requires recent login for security reasons
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

