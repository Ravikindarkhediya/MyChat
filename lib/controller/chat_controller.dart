import 'dart:async';
import 'package:ads_demo/view/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_services.dart';
import '../services/user_service.dart';
import 'dart:io';

class ChatController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final _logger = Logger();

  // Constructor parameters
  final String userId;
  final String? peerId;

  ChatController({required this.userId, this.peerId});

  // Disposers
  final List<StreamSubscription> _subscriptions = [];

  // Observables
  final RxList<MessageModel> messages = <MessageModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<UserModel> friends = <UserModel>[].obs;
  final RxList<UserModel> searchResults = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString currentUserId = ''.obs;
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  var userChats = <ChatSummary>[].obs;

  // Controllers
  final TextEditingController messageController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  late VoidCallback _searchListener;

  // For friend requests
  final RxList<UserModel> friendRequests = <UserModel>[].obs;
  final RxList<String> friendRequestIds = <String>[].obs;

  // Chat state
  final RxString currentChatId = ''.obs;
  final Rx<UserModel?> currentPeer = Rx<UserModel?>(null);
  final RxBool isSendingMessage = false.obs;
  final RxBool isTyping = false.obs;

  // Typing indicators
  final RxMap<String, bool> typingUsers = <String, bool>{}.obs;
  Timer? _typingTimer;

  @override
  void onInit() {
    super.onInit();
    _initializeUser();
    _listenToUserChats();

    _setupNetworkListener();
    _setupSubscriptions();
  }

  void _listenToUserChats() {
    _chatService.getUserChats(userId).listen((chats) {
      userChats.value = chats;
    });
  }
// Network connectivity checker
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showErrorSnackbar('No internet connection');
        return false;
      }

      // Additional check by trying to reach Google DNS
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      _logger.w('Network connectivity check failed', error: e);
      return false;
    }
  }

// Enhanced error handling for Firebase operations
  Future<T?> _executeWithNetworkCheck<T>(Future<T> Function() operation) async {
    if (!await _checkNetworkConnectivity()) {
      _showErrorSnackbar('Please check your internet connection');
      return null;
    }

    try {
      return await operation();
    } on SocketException catch (e) {
      _logger.e('Network error', error: e);
      _showErrorSnackbar('Network connection failed. Please check your internet.');
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        _showErrorSnackbar('Firebase service unavailable. Please try again later.');
      } else {
        _showErrorSnackbar('Firebase error: ${e.message}');
      }
      _logger.e('Firebase error', error: e);
      return null;
    } catch (e) {
      _logger.e('Unexpected error', error: e);
      _showErrorSnackbar('An unexpected error occurred');
      return null;
    }
  }

// Modified sendMessage with network check
  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || currentPeer.value == null) return;

    try {
      isSendingMessage.value = true;
      messageController.clear();
      isTyping.value = false;
      _updateTypingStatus(false);

      await _executeWithNetworkCheck(() async {
        await _chatService.sendMessage(
          senderId: currentUserId.value,
          receiverId: currentPeer.value!.uid,
          message: text,
          senderName: currentUser.value?.name ?? 'Unknown',
          senderPhotoUrl: currentUser.value?.photoUrl,
        );
      });

    } catch (e) {
      _logger.e('Error sending message', error: e);
      messageController.text = text; // Restore message text
    } finally {
      isSendingMessage.value = false;
    }
  }

// Network status monitoring
  void _setupNetworkListener() {
    _subscriptions.add(
      Connectivity().onConnectivityChanged.listen(
            (result) {
          if (result == ConnectivityResult.none) {
            _showErrorSnackbar('Internet connection lost');
          } else {
            _showSuccessSnackbar('Internet connection restored');
            _retryFailedOperations();
          }
        },
        onError: (error) {
          _logger.e('Connectivity listener error', error: error);
        },
      ),
    );
  }


  void _retryFailedOperations() {
    // Retry loading data after network restoration
    if (currentUserId.value.isNotEmpty) {
      _loadInitialData();
    }
  }

  @override
  void onClose() {
    // Cancel all subscriptions when controller is disposed
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _typingTimer?.cancel();
    messageController.dispose();
    searchController.dispose();
    emailController.dispose();
    super.onClose();
  }

  void _initializeUser() {
    // Set current user ID from constructor or FirebaseAuth
    final authUserId = _auth.currentUser?.uid;
    if (userId.isNotEmpty) {
      currentUserId.value = userId;
    } else if (authUserId != null) {
      currentUserId.value = authUserId;
    }
  }

  void _setupSubscriptions() {
    // Listen to current user changes
    if (currentUserId.value.isNotEmpty) {
      _subscriptions.add(
        _userService.getCurrentUserStream().listen(
              (user) {
            if (user != null) {
              currentUser.value = user;
              if (currentUserId.value.isEmpty) {
                currentUserId.value = user.uid;
              }
              _loadInitialData();
            }
          },
          onError: (error) {
            _logger.e('Error in user stream', error: error);
          },
        ),
      );
    } else {
      // If we have a userId, load the user data directly
      _loadUserData();
    }

    _searchListener = () {
      final query = searchController.text.trim();
      if (query.length >= 2) {
        searchUsers(query);
      } else {
        searchResults.clear();
      }
    };

    searchController.addListener(_searchListener);

    // Listen to typing status
    messageController.addListener(_onTypingChanged);
  }

  void _onTypingChanged() {
    if (peerId == null) return;

    final isCurrentlyTyping = messageController.text.trim().isNotEmpty;
    if (isTyping.value != isCurrentlyTyping) {
      isTyping.value = isCurrentlyTyping;
      _updateTypingStatus(isCurrentlyTyping);
    }

    // Reset typing after 3 seconds of inactivity
    _typingTimer?.cancel();
    if (isCurrentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (isTyping.value) {
          isTyping.value = false;
          _updateTypingStatus(false);
        }
      });
    }
  }

  Future<void> _updateTypingStatus(bool typing) async {
    if (peerId == null) return;

    try {
      final chatId = _chatService.getChatId(currentUserId.value, peerId!);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(currentUserId.value)
          .set({
        'isTyping': typing,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUserId.value,
      });
    } catch (e) {
      _logger.e('Error updating typing status', error: e);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await getUserData(currentUserId.value);
      if (userData != null) {
        currentUser.value = UserModel.fromMap(userData);
        _loadInitialData();
      }
    } catch (e) {
      _logger.e('Error loading user data', error: e);
    }
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return {...doc.data() as Map<String, dynamic>, 'uid': doc.id};
      } else {
        return null;
      }
    } on FirebaseException catch (e) {
      _logger.e('Firebase error getting user data', error: e);
      return null;
    } catch (e) {
      _logger.e('Unexpected error getting user data', error: e);
      return null;
    }
  }

  Future<void> _loadInitialData() async {
    if (currentUserId.value.isEmpty) return;

    try {
      isLoading.value = true;
      await Future.wait([
        _loadUsers(),
        loadFriends(),
        _listenToFriendRequests(),
      ]);
    } catch (e) {
      _logger.e('Error loading initial data', error: e);
      _showErrorSnackbar('Failed to load initial data');
    } finally {
      isLoading.value = false;
    }
  }

  // Load all users (excluding current user)
  Future<void> _loadUsers() async {
    try {
      final usersStream = _userService.getUsers(excludeUserId: currentUserId.value);
      _subscriptions.add(
        usersStream.listen(
              (userList) => users.value = userList,
          onError: (error) {
            _logger.e('Error in users stream', error: error);
          },
        ),
      );
    } on FirebaseException catch (e) {
      _logger.e('Firebase error loading users', error: e);
      _showErrorSnackbar('Failed to load users');
    } catch (e) {
      _logger.e('Unexpected error loading users', error: e);
      rethrow;
    }
  }

  // Load current user's friends
  Future<void> loadFriends() async {
    try {
      final userId = currentUserId.value;
      if (userId.isEmpty) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final friendIds = List<String>.from(
        userData['friends'] as List<dynamic>? ?? [],
      );

      if (friendIds.isNotEmpty) {
        final friendsSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: friendIds)
            .get();

        friends.value = friendsSnapshot.docs
            .map((doc) => UserModel.fromMap({...doc.data(), 'uid': doc.id}))
            .toList();
      } else {
        friends.clear();
      }
    } on FirebaseException catch (e) {
      _logger.e('Firebase error loading friends', error: e);
      _showErrorSnackbar('Failed to load friends');
    } catch (e) {
      _logger.e('Unexpected error loading friends', error: e);
      rethrow;
    }
  }

  // Listen to friend requests
  Future<void> _listenToFriendRequests() async {
    final userId = currentUserId.value;
    if (userId.isEmpty) return;

    _subscriptions.add(
      _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen(
            (doc) async {
          if (!doc.exists) return;

          final data = doc.data() as Map<String, dynamic>? ?? {};
          final requests = List<String>.from(
            data['friendRequests'] as List<dynamic>? ?? [],
          );

          if (requests.isNotEmpty) {
            await _loadFriendRequests(requests);
          } else {
            friendRequests.clear();
          }
          friendRequestIds.value = requests;
        },
        onError: (error) {
          _logger.e('Error in friend requests stream', error: error);
        },
      ),
    );
  }

  // Load friend requests
  Future<void> _loadFriendRequests(List<String> requests) async {
    try {
      if (requests.isEmpty) {
        friendRequests.clear();
        return;
      }

      final requestsSnapshot = await _firestore
          .collection('friend_requests')
          .where(FieldPath.documentId, whereIn: requests)
          .get();

      final loadedRequests = <UserModel>[];
      for (final doc in requestsSnapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;

        if (senderId != null) {
          final senderData = await getUserData(senderId);
          if (senderData != null) {
            loadedRequests.add(UserModel.fromMap(senderData));
          }
        }
      }

      friendRequests.value = loadedRequests;
    } on FirebaseException catch (e) {
      _logger.e('Firebase error loading friend requests', error: e);
      _showErrorSnackbar('Failed to load friend requests');
    } catch (e) {
      _logger.e('Unexpected error loading friend requests', error: e);
      rethrow;
    }
  }

  // Send friend request
  Future<void> sendFriendRequest(String receiverEmail) async {
    if (receiverEmail.trim().isEmpty) {
      _showErrorSnackbar('Please enter an email address');
      return;
    }

    try {
      isLoading.value = true;

      // Find user by email
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: receiverEmail.trim().toLowerCase())
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        _showErrorSnackbar('User not found with this email');
        return;
      }

      final receiverId = usersSnapshot.docs.first.id;

      // Don't allow sending request to self
      if (receiverId == currentUserId.value) {
        _showErrorSnackbar('You cannot send a friend request to yourself');
        return;
      }

      // Check if already friends
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId.value)
          .get();

      if (userDoc.exists) {
        final friends = List<String>.from(
          (userDoc.data() as Map<String, dynamic>)['friends'] ?? [],
        );

        if (friends.contains(receiverId)) {
          _showInfoSnackbar('This user is already your friend');
          return;
        }
      }

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId.value)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        _showInfoSnackbar('Friend request already sent');
        return;
      }

      // Create friend request
      final requestRef = await _firestore.collection('friend_requests').add({
        'senderId': currentUserId.value,
        'receiverId': receiverId,
        'status': 'pending',
        'senderName': currentUser.value?.name ?? 'Unknown',
        'senderEmail': currentUser.value?.email ?? '',
        'senderPhotoUrl': currentUser.value?.photoUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Add request to receiver's friend requests list
      await _firestore.collection('users').doc(receiverId).update({
        'friendRequests': FieldValue.arrayUnion([requestRef.id]),
      });

      _showSuccessSnackbar('Friend request sent successfully');
      emailController.clear();
    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending friend request', error: e);
      _showErrorSnackbar('Failed to send friend request: ${e.message}');
    } catch (e) {
      _logger.e('Unexpected error sending friend request', error: e);
      _showErrorSnackbar('An unexpected error occurred');
    } finally {
      isLoading.value = false;
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    try {
      isLoading.value = true;
      final batch = _firestore.batch();

      // Update friend request status
      final requestRef = _firestore.collection('friend_requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Add to current user's friends
      final currentUserRef = _firestore.collection('users').doc(currentUserId.value);
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayUnion([senderId]),
        'friendRequests': FieldValue.arrayRemove([requestId]),
      });

      // Add to sender's friends
      final senderRef = _firestore.collection('users').doc(senderId);
      batch.update(senderRef, {
        'friends': FieldValue.arrayUnion([currentUserId.value]),
      });

      await batch.commit();

      // Reload friends and requests
      await Future.wait([loadFriends(), _listenToFriendRequests()]);

      _showSuccessSnackbar('Friend request accepted');
    } on FirebaseException catch (e) {
      _logger.e('Firebase error accepting friend request', error: e);
      _showErrorSnackbar('Failed to accept friend request');
    } catch (e) {
      _logger.e('Unexpected error accepting friend request', error: e);
      _showErrorSnackbar('An unexpected error occurred');
    } finally {
      isLoading.value = false;
    }
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      isLoading.value = true;
      final batch = _firestore.batch();

      // Update friend request status
      final requestRef = _firestore.collection('friend_requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Remove from current user's friend requests
      final currentUserRef = _firestore.collection('users').doc(currentUserId.value);
      batch.update(currentUserRef, {
        'friendRequests': FieldValue.arrayRemove([requestId]),
      });

      await batch.commit();
      _showInfoSnackbar('Friend request rejected');
    } on FirebaseException catch (e) {
      _logger.e('Firebase error rejecting friend request', error: e);
      _showErrorSnackbar('Failed to reject friend request');
    } catch (e) {
      _logger.e('Unexpected error rejecting friend request', error: e);
      _showErrorSnackbar('An unexpected error occurred');
    } finally {
      isLoading.value = false;
    }
  }

  // Set current chat
  void setCurrentChat(String chatId, UserModel peer) {
    currentChatId.value = chatId;
    currentPeer.value = peer;
    messages.clear();
    _listenMessages();
    _listenTypingStatus();
  }

  // Listen to messages for current chat
  void _listenMessages() {
    if (currentPeer.value == null) return;

    final stream = _chatService.getMessages(
      currentUserId: currentUserId.value,
      otherUserId: currentPeer.value!.uid,
    );

    _subscriptions.add(
      stream.listen(
            (messageList) {
          messages.value = messageList;
        },
        onError: (error) {
          _logger.e('Error in messages stream', error: error);
        },
      ),
    );
  }

  // Listen to typing status
  void _listenTypingStatus() {
    if (currentPeer.value == null) return;

    final chatId = _chatService.getChatId(currentUserId.value, currentPeer.value!.uid);

    _subscriptions.add(
      _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .where('userId', isNotEqualTo: currentUserId.value)
          .snapshots()
          .listen(
            (snapshot) {
          final typingData = <String, bool>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final userId = data['userId'] as String?;
            final isTyping = data['isTyping'] as bool? ?? false;
            final timestamp = data['timestamp'] as Timestamp?;

            if (userId != null && timestamp != null) {
              // Consider typing status expired after 5 seconds
              final now = DateTime.now();
              final typingTime = timestamp.toDate();
              final isRecent = now.difference(typingTime).inSeconds < 5;

              typingData[userId] = isTyping && isRecent;
            }
          }
          typingUsers.value = typingData;
        },
        onError: (error) {
          _logger.e('Error in typing status stream', error: error);
        },
      ),
    );
  }

  // Send message to a specific user
  Future<void> sendMessageToUser(String receiverId, String message) async {

    if (receiverId.isEmpty || message.trim().isEmpty) return;

    try {
      isSendingMessage.value = true;

      await _chatService.sendMessage(
        senderId: currentUserId.value,
        receiverId: receiverId,
        message: message.trim(),
        senderName: currentUser.value?.name ?? 'Unknown',
        senderPhotoUrl: currentUser.value?.photoUrl,
      );

    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending message to user', error: e);
      _showErrorSnackbar('Failed to send message: ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error sending message to user', error: e);
      _showErrorSnackbar('Failed to send message');
      rethrow;
    } finally {
      isSendingMessage.value = false;
    }
  }

  // Search for users
  Future<void> searchUsers(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      searchResults.clear();
      return;
    }

    try {
      isLoading.value = true;

      final results = await _chatService.searchUsers(
        trimmedQuery,
        excludeUserId: currentUserId.value,
      );

      searchResults.value = results;
    } on FirebaseException catch (e) {
      _logger.e('Firebase error searching users', error: e);
      _showErrorSnackbar('Failed to search users');
      searchResults.clear();
    } catch (e) {
      _logger.e('Error searching users', error: e);
      _showErrorSnackbar('An unexpected error occurred while searching');
      searchResults.clear();
    } finally {
      isLoading.value = false;
    }
  }

  // Helper methods for showing snackbars
  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  void _showInfoSnackbar(String message) {
    Get.snackbar(
      'Info',
      message,
      backgroundColor: Colors.blue.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  // Clean up method
  Future<void> cleanup() async {
    isTyping.value = false;
    if (peerId != null) {
      await _updateTypingStatus(false);
    }

    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> signOut() async {
    try {
      for (var sub in _subscriptions) {
        await sub.cancel();
      }
      _subscriptions.clear();

      // Sign out from Firebase
      await _auth.signOut();
      await _googleSignIn.signOut();
      // Clear all local states
      currentUser.value = null;
      currentUserId.value = '';
      currentPeer.value = null;
      currentChatId.value = '';
      messages.clear();
      friends.clear();
      users.clear();
      friendRequests.clear();
      friendRequestIds.clear();

      // Clear controllers
      messageController.clear();
      searchController.clear();
      emailController.clear();

      Get.offAll(()=> LoginPage());

      _logger.i("User signed out successfully");
    } catch (e) {
      _logger.e("Error during sign out", error: e);
      Get.snackbar(
        "Error",
        "Failed to sign out. Please try again.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

}