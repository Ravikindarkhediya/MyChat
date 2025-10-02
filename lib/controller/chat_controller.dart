import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ads_demo/view/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import '../constant/common.dart';
import '../models/enums.dart';
import '../models/friend_request_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_services/chat_firebase_manager.dart';
import '../services/chat_services/chat_services.dart';
import '../services/chat_services/voice_recording_service.dart';
import '../services/notification_service/api_notification_service.dart';
import '../services/user_service.dart';

class ChatController extends GetxController with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final _logger = Logger();
  late final StreamSubscription _networkSub;
  final Common common = Common();

  // Constructor parameters
  final String userId;
  final String? peerId;

  ChatController({required this.userId, this.peerId});

  // Disposers
  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription? _userChatsSubscription;

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
  final RxList<String> sentRequests = <String>[].obs;
  final RxBool isPeerUserOnline = false.obs;
  StreamSubscription? _peerOnlineStatusSubscription;

  // Controllers
  final TextEditingController messageController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  late VoidCallback _searchListener;

  // For friend requests
  final RxList<FriendRequest> friendRequests = <FriendRequest>[].obs;
  final RxList<String> friendRequestIds = <String>[].obs;
  final RxString highlightedUserId = ''.obs;

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

    // Observe app lifecycle for presence updates
    WidgetsBinding.instance.addObserver(this);

    _listenToUserChats();
    _networkSub = Common().setupNetworkListener(
      currentUserId: currentUserId,
      onRestore: _loadInitialData,
    );
    _setupSubscriptions();

    // Try to set online at startup
    setCurrentUserOnline();
  }

  void listenSentRequests() {
    _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId.value)
        .snapshots()
        .listen((query) {
          sentRequests.value = query.docs
              .map((d) => d['receiverId'] as String)
              .toList();
        });
  }
  void listenToPeerOnlineStatus(String peerId) {
    if (peerId.isEmpty) return;

    // Cancel previous subscription if any
    _peerOnlineStatusSubscription?.cancel();

    // Listen to peer user's online status
    _peerOnlineStatusSubscription = _userService
        .getUserOnlineStatus(peerId)
        .listen((isOnline) {
      isPeerUserOnline.value = isOnline;
    });
  }

  // ✅ YE METHOD ADD KARO - CURRENT USER KO ONLINE SET KARNE KE LIYE
  Future<void> setCurrentUserOnline() async {
    if (currentUserId.value.isNotEmpty) {
      await _userService.setUserOnline(currentUserId.value);
    }
  }

  // ✅ YE METHOD ADD KARO - CURRENT USER KO OFFLINE SET KARNE KE LIYE
  Future<void> setCurrentUserOffline() async {
    if (currentUserId.value.isNotEmpty) {
      await _userService.setUserOffline(currentUserId.value);
    }
  }
  void _listenToUserChats() {
    // Cancel old subscription if any
    _userChatsSubscription?.cancel();

    // Only subscribe if currentUserId available
    if (currentUserId.value.isEmpty) return;

    _userChatsSubscription = _chatService
        .getUserChats(currentUserId.value)
        .listen(
          (chats) {
            userChats.value = chats;
          },
          onError: (error) {
            _logger.e('Error in user chats stream', error: error);
          },
        );
  }

  Future<void> updateUserChats() async {
    try {
      if (currentUserId.value.isEmpty) return;

      // चैट सर्विस से नवीनतम चैट्स प्राप्त करें
      final chats = await _chatService.fetchUserChats(currentUserId.value);
      if (chats != null) {
        userChats.value = chats;
      }
    } catch (e) {
      _logger.e('Error updating user chats', error: e);
    }
  }

  @override
  void onClose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Cancel all subscriptions when controller is disposed
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }

    _peerOnlineStatusSubscription?.cancel();
    setCurrentUserOffline();
    _userChatsSubscription?.cancel();
    _typingTimer?.cancel();
    messageController.dispose();
    searchController.dispose();
    emailController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Update presence based on lifecycle
    if (state == AppLifecycleState.resumed) {
      setCurrentUserOnline();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      setCurrentUserOffline();
    }
  }

  void _setupSubscriptions() {
    // Step 1: Initialize currentUserId
    final authUserId = _auth.currentUser?.uid;
    if (userId.isNotEmpty) {
      currentUserId.value = userId;
    } else if (authUserId != null) {
      currentUserId.value = authUserId;
    }

    // Step 2: Subscribe to current user changes
    if (currentUserId.value.isNotEmpty) {
      _subscriptions.add(
        _userService.getCurrentUserStream().listen(
          (user) {
            if (user != null) {
              currentUser.value = user;
              _listenToUserChats();
              _loadInitialData();
            }
          },
          onError: (error) {
            _logger.e('Error in user stream', error: error);
          },
        ),
      );
    } else {
      // Fallback: load user data if currentUserId not set
      _loadUserData();
      _listenToUserChats();
    }

    // Step 5: Resubscribe chats when currentUserId changes later
    ever<String>(currentUserId, (id) {
      if (id.isNotEmpty) {
        _listenToUserChats();
      }
    });
  }

  void clearChatMessages(String friendUserId) {
    if (friendUserId.isEmpty) return;

    final chatId = _chatService.getChatId(currentUserId.value, friendUserId);

    messages.clear();
    messages.refresh();

    final index = userChats.indexWhere(
      (chat) =>
          chat.chatId == chatId ||
          (chat.participants.contains(currentUserId.value) &&
              chat.participants.contains(friendUserId)),
    );

    if (index != -1) {
      userChats[index] = userChats[index].copyWith(lastMessage: '');
      userChats.refresh();
    }
  }


  Future<void> updateTypingStatus(String peerId, bool isTyping) async {
    if (peerId.isEmpty || currentUserId.value.isEmpty) return;

    try {
      final chatId = _chatService.getChatId(currentUserId.value, peerId);

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(currentUserId.value)
          .set({
        'isTyping': isTyping,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUserId.value,
        'userName': currentUser.value?.name ?? 'Unknown',
      });

      _logger.i('✅ Typing status updated: $isTyping for chat: $chatId');
    } catch (e) {
      _logger.e('❌ Error updating typing status', error: e);
    }
  }

  void listenToTypingStatus(String peerId) {
    if (peerId.isEmpty || currentUserId.value.isEmpty) return;

    final chatId = _chatService.getChatId(currentUserId.value, peerId);

    _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(peerId) // Other user ka typing status
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data();
        final isTyping = data?['isTyping'] ?? false;

        // Update typing status for this user
        typingUsers[peerId] = isTyping;

        // Auto-clear typing status after 3 seconds
        if (isTyping) {
          Timer(const Duration(seconds: 3), () {
            if (typingUsers[peerId] == true) {
              typingUsers[peerId] = false;
            }
          });
        }
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _chatService.getUserData(currentUserId.value);
      if (userData != null) {
        currentUser.value = userData;
        _loadInitialData();
      }
    } catch (e) {
      _logger.e('Error loading user data', error: e);
    }
  }

  Future<void> _loadInitialData() async {
    if (currentUserId.value.isEmpty) return;

    try {
      isLoading.value = true;
      await Future.wait([_loadUsers(), loadFriends(), fetchFriendRequests()]);
    } catch (e) {
      _logger.e('Error loading initial data', error: e);
      common.showSnackbar('Error', 'Failed to load users', Colors.red);
    } finally {
      isLoading.value = false;
    }
  }

  // Load all users (excluding current user)
  Future<void> _loadUsers() async {
    try {
      final usersStream = _userService.getFriendsStream(currentUserId.value);
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
      common.showSnackbar('Error', 'Failed to load users', Colors.red);
    } catch (e) {
      _logger.e('Unexpected error loading users', error: e);
      rethrow;
    }
  }

  Future<void> fetchFriendRequests() async {
    final userId = currentUserId.value;
    if (userId.isEmpty) return;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final requestIds = List<String>.from(
        userDoc.data()?['friendRequests'] ?? [],
      );

      if (requestIds.isEmpty) {
        friendRequests.clear();
        return;
      }

      final requestsSnapshot = await _firestore
          .collection('friend_requests')
          .where(FieldPath.documentId, whereIn: requestIds)
          .get();

      final loadedRequests = <FriendRequest>[];
      for (final doc in requestsSnapshot.docs) {
        final senderId = doc.data()['senderId'] as String?;
        final status = doc.data()['status'] as String? ?? 'pending';
        if (senderId != null) {
          final senderData = await _chatService.getUserData(senderId);
          if (senderData != null) {
            loadedRequests.add(
              FriendRequest(
                id: doc.id,
                senderId: senderId,
                sender: senderData,
                status: status,
              ),
            );
          }
        }
      }

      friendRequests.value = loadedRequests;
    } catch (e) {
      _logger.e('Error fetching friend requests', error: e);
      friendRequests.clear();
    }
  }

  // Load current user's friends
  Future<void> loadFriends() async {
    try {
      final userId = currentUserId.value;
      if (userId.isEmpty) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
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
      common.showSnackbar('Error', 'Failed to load friends', Colors.red);
    } catch (e) {
      _logger.e('Unexpected error loading friends', error: e);
      common.showSnackbar('Error', 'Failed to load friends', Colors.red);
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    try {
      isLoading.value = true;
      final batch = _firestore.batch();

      // Update friend request status
      final requestRef = _firestore
          .collection('friend_requests')
          .doc(requestId);
      batch.update(requestRef, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Add to current user's friends
      final currentUserRef = _firestore
          .collection('users')
          .doc(currentUserId.value);
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


      // Get the sender's user data
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();
      if (senderDoc.exists) {
        final senderData = UserModel.fromMap({
          ...senderDoc.data()!,
          'uid': senderId,
        });

        // Update local state
        friends.addIf(!friends.any((f) => f.uid == senderId), senderData);
        friendRequests.removeWhere((r) => r.id == requestId);
      }

      // Refresh data from server
      await Future.wait([loadFriends(), fetchFriendRequests()]);


    } on FirebaseException catch (e) {
      _logger.e('Firebase error accepting friend request', error: e);
      common.showSnackbar(
        'Error',
        'Failed to accept friend request',
        Colors.red,
      );
    } catch (e) {
      _logger.e('Unexpected error accepting friend request', error: e);
      common.showSnackbar('Error', 'An unexpected error occurred', Colors.red);
    } finally {
      isLoading.value = false;
    }
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String requestId, String receiverId) async {
    try {
      isLoading.value = true;
      final batch = _firestore.batch();

      // Update friend request status
      final requestRef = _firestore
          .collection('friend_requests')
          .doc(requestId);
      batch.update(requestRef, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Remove from current user's friend requests
      final currentUserRef = _firestore
          .collection('users')
          .doc(currentUserId.value);
      batch.update(currentUserRef, {
        'friendRequests': FieldValue.arrayRemove([requestId]),
      });

      await batch.commit();

      // Notify the original sender that their request was rejected
      try {
        await ApiNotificationService.sendFriendRequestStatusNotification(
          receiverId: receiverId,
          senderId: currentUserId.value,
          senderName: currentUser.value?.name ?? 'Unknown',
          status: 'rejected',
        );
      } catch (e) {
        _logger.w('⚠️ Failed to send reject notification: $e');
      }

      // Reload friend requests
      await fetchFriendRequests();

    } on FirebaseException catch (e) {
      _logger.e('Firebase error rejecting friend request', error: e);
      common.showSnackbar(
        'Error',
        'Failed to reject friend request',
        Colors.red,
      );
    } catch (e) {
      _logger.e('Unexpected error rejecting friend request', error: e);
      common.showSnackbar('Error', 'An unexpected error occurred', Colors.red);
    } finally {
      isLoading.value = false;
    }
  }

  // Send friend request
  Future<void> sendFriendRequest(String receiverEmail) async {
    if (receiverEmail.trim().isEmpty) {
      common.showSnackbar('Error', 'Please enter an email address', Colors.red);
      return;
    }

    try {
      isLoading.value = true;

      // STEP 1: Find user by email FIRST
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: receiverEmail.trim().toLowerCase())
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        common.showSnackbar('Error', 'User not found with this email', Colors.red);
        return;
      }

      final receiverId = usersSnapshot.docs.first.id;

      // STEP 2: Don't allow sending request to self
      if (receiverId == currentUserId.value) {
        common.showSnackbar(
          'Error',
          'You cannot send a friend request to yourself',
          Colors.red,
        );
        return;
      }

      // STEP 3: Check if already friends
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId.value)
          .get();

      if (userDoc.exists) {
        final friends = List<String>.from(
          (userDoc.data() as Map<String, dynamic>)['friends'] ?? [],
        );

        if (friends.contains(receiverId)) {
          common.showSnackbar('Info', 'This user is already your friend', Colors.blue);
          return;
        }
      }

      // STEP 4: Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId.value)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        common.showSnackbar('Info', 'Friend request already sent', Colors.blue);
        return;
      }

      final requestRef = await _firestore.collection('friend_requests').add({
        'senderId': currentUserId.value,
        'receiverId': receiverId,
        'status': 'pending',
        'senderName': currentUser.value?.name ?? 'Unknown',
        'senderEmail': currentUser.value?.email ?? '',
        'senderPhotoUrl': currentUser.value?.photoUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // STEP 6: Add request to receiver's friend requests list
      await _firestore.collection('users').doc(receiverId).update({
        'friendRequests': FieldValue.arrayUnion([requestRef.id]),
      });

      // STEP 7: Send notification (YE OPTIONAL HAI - AGAR API SERVICE AVAILABLE HAI)
      try {
        await ApiNotificationService.sendFriendRequestNotification(
          receiverId: receiverId,
          senderId: currentUserId.value,
          senderName: currentUser.value?.name ?? 'Unknown User',
          senderEmail: currentUser.value?.email ?? '',
          chatId: requestRef.id,
        );
        _logger.i('✅ Friend request notification sent successfully');
      } catch (notificationError) {
        _logger.w('⚠️ Failed to send notification: $notificationError');
        // Don't fail the whole operation if notification fails
      }

      // STEP 8: Update UI and show success
      highlightedUserId.value = receiverId;
      common.showSnackbar('Success', 'Friend request sent!', Colors.green);
      emailController.clear();

    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending friend request', error: e);
      common.showSnackbar(
        'Error',
        'Failed to send friend request: ${e.message}',
        Colors.red,
      );
    } catch (e) {
      _logger.e('Unexpected error sending friend request', error: e);
      common.showSnackbar('Error', 'An unexpected error occurred', Colors.red);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendMessageToUser(String receiverId, String message) async {
    // Validate inputs
    final trimmed = message.trim();
    if (receiverId.isEmpty || trimmed.isEmpty) {
      common.showSnackbar('Error', 'Invalid message data', Colors.red);
      _logger.w('✋ Aborting send: receiverId or message empty');
      return;
    }

    if (currentUserId.value.isEmpty) {
      common.showSnackbar('Error', 'User not authenticated', Colors.red);
      _logger.w('✋ Aborting send: currentUserId is empty');
      return;
    }

    final senderId = currentUserId.value;
    final senderName = currentUser.value?.name ?? 'Unknown';
    final chatId = _chatService.getChatId(senderId, receiverId);

    try {
      isSendingMessage.value = true;

      try {
        final receiverDoc = await _firestore
            .collection('users')
            .doc(receiverId)
            .get();
      } catch (e) {
        _logger.w('⚠️ Failed to read receiver FCM info: $e');
      }

      // Create the message model first
      final messageModel = await _chatService.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        message: trimmed,
        senderName: senderName,
        senderPhotoUrl: currentUser.value?.photoUrl,
      );

      if (messageModel != null) {
        messages.add(messageModel);
        messages.refresh();
        updateUserChats();
      }

      // Trigger push notification for the receiver via API server
      try {
        await ChatFirebaseManager().sendChatNotification(
          receiverId: receiverId,
          chatId: chatId,
          message: trimmed,
          messageType: 'text',
          senderName: senderName,
          senderId: senderId,
        );
      } catch (e) {
        _logger.w('⚠️ Failed to enqueue notification: $e');
      }

      _logger.i(
        '💡 Message sent successfully: ${messageModel?.id ?? '(null-id)'}',
      );
    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending message to user', error: e);
      common.showSnackbar(
        'Error',
        'Failed to send message: ${e.message}',
        Colors.red,
      );
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error sending message to user', error: e);
      common.showSnackbar('Error', 'Failed to send message', Colors.red);
      rethrow;
    } finally {
      isSendingMessage.value = false;
    }
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

      Get.offAll(() => LoginPage());

      _logger.i('User signed out successfully');
    } catch (e) {
      _logger.e('Error during sign out', error: e);
      Get.snackbar(
        'Error',
        'Failed to sign out. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> sendVoiceMessage(
    String receiverId,
    String audioPath,
    int duration,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _chatService.sendVoiceMessage(
        senderId: currentUser.uid,
        receiverId: receiverId,
        senderName: currentUser.displayName ?? 'Unknown',
        audioPath: audioPath,
        duration: duration,
        senderPhotoUrl: currentUser.photoURL,
      );

      // Show success feedback
      Get.snackbar(
        'Success',
        'Voice message sent!',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send voice message: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }


  Future<void> sendImageMessage(String receiverId, File imageFile) async {
    if (receiverId.isEmpty || !imageFile.existsSync()) {
      common.showSnackbar('Error', 'Invalid image or receiver', Colors.red);
      return;
    }

    if (currentUserId.value.isEmpty) {
      common.showSnackbar('Error', 'User not authenticated', Colors.red);
      return;
    }

    try {
      isSendingMessage.value = true;

      // Read image and convert to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Create data URL format
      final String imageExtension = imageFile.path.split('.').last.toLowerCase();
      final String mimeType = _getMimeType(imageExtension);
      final String dataUrl = 'data:$mimeType;base64,$base64Image';

      // Create message model with base64 in mediaUrl field
      final chatId = _chatService.getChatId(currentUserId.value, receiverId);
      final message = MessageModel(
        id: _chatService.generateMessageId(chatId),
        chatId: chatId,
        senderId: currentUserId.value,
        receiverId: receiverId,
        type: MessageType.image,
        content: "",
        mediaUrl: dataUrl,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        metadata: {
          'size': bytes.length,
          'encoding': 'base64',
          'originalExtension': imageExtension,
          'mimeType': mimeType,
        },
      );

      // Send to Firestore
      await _chatService.sendMessageModel(message);

      // Add to local UI
      messages.add(message);
      messages.refresh();
      updateUserChats();

      // Send notification
      await ChatFirebaseManager().sendChatNotification(
        receiverId: receiverId,
        chatId: chatId,
        message: '📷 Photo',
        messageType: 'image',
        senderName: currentUser.value?.name ?? 'Unknown',
        senderId: currentUserId.value,
      );

      print('✅ Image message sent successfully as base64');

    } catch (e, st) {
      _logger.e('Failed to send image message', error: e, stackTrace: st);
      common.showSnackbar('Error', 'Failed to send image', Colors.red);
    } finally {
      isSendingMessage.value = false;
    }
  }

// Helper method to get MIME type
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
