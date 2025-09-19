import 'dart:async';
import 'package:ads_demo/view/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import '../constant/common.dart';
import '../models/friend_request_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_services.dart';
import '../services/user_service.dart';

class ChatController extends GetxController {
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

    _listenToUserChats();
    _networkSub = Common().setupNetworkListener(
      currentUserId: currentUserId,
      onRestore: _loadInitialData,
    );
    _setupSubscriptions();
  }


  void listenSentRequests() {
    _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId.value)
        .snapshots()
        .listen((query) {
      sentRequests.value = query.docs.map((d) => d['receiverId'] as String).toList();
    });
  }

  void _listenToUserChats() {
    // Cancel old subscription if any
    _userChatsSubscription?.cancel();

    // Only subscribe if currentUserId available
    if (currentUserId.value.isEmpty) return;

    _userChatsSubscription = _chatService.getUserChats(currentUserId.value).listen(
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
    // Cancel all subscriptions when controller is disposed
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _userChatsSubscription?.cancel();
    _typingTimer?.cancel();
    messageController.dispose();
    searchController.dispose();
    emailController.dispose();
    super.onClose();
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

    // Step 3: Setup search listener
    _searchListener = () {
      final query = searchController.text.trim();
      if (query.length >= 2) {
        searchUsers(query);
      } else {
        searchResults.clear();
      }
    };
    searchController.addListener(_searchListener);

    // Step 4: Typing listener
    messageController.addListener(_onTypingChanged);

    // Step 5: Resubscribe chats when currentUserId changes later
    ever<String>(currentUserId, (id) {
      if (id.isNotEmpty) {
        _listenToUserChats();
      }
    });
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

  // चैट मैसेज को क्लियर करने के लिए मेथड
  void clearChatMessages(String friendUserId) {
    if (friendUserId.isEmpty) return;
    
    final chatId = _chatService.getChatId(currentUserId.value, friendUserId);
    
    // मैसेज लिस्ट से सभी मैसेज हटाएं
    messages.clear();
    messages.refresh();
    
    // होम स्क्रीन पर लास्ट मैसेज अपडेट करें
    final index = userChats.indexWhere((chat) => 
      chat.chatId == chatId || 
      (chat.participants.contains(currentUserId.value) && 
       chat.participants.contains(friendUserId))
    );
    
    if (index != -1) {
      userChats[index] = userChats[index].copyWith(lastMessage: 'No message yet');
      userChats.refresh();
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
      final userData = await _chatService.getUserData(currentUserId.value);
      if (userData != null) {
        currentUser.value =userData;
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
      await Future.wait([
        _loadUsers(),
        loadFriends(),
        fetchFriendRequests(),
      ]);
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
      final requestIds = List<String>.from(userDoc.data()?['friendRequests'] ?? []);

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
            loadedRequests.add(FriendRequest(
              id: doc.id,
              senderId: senderId,
              sender: senderData,
              status: status,
            ));
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

      // Get the sender's user data
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
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

      common.showSnackbar('Success', 'Friend request accepted', Colors.green);
    } on FirebaseException catch (e) {
      _logger.e('Firebase error accepting friend request', error: e);
      common.showSnackbar('Error', 'Failed to accept friend request', Colors.red);
    } catch (e) {
      _logger.e('Unexpected error accepting friend request', error: e);
      common.showSnackbar('Error', 'An unexpected error occurred', Colors.red);
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
      
      // Reload friend requests
      await fetchFriendRequests();
      
      common.showSnackbar('Info', 'Friend request rejected', Colors.blue);
    } on FirebaseException catch (e) {
      _logger.e('Firebase error rejecting friend request', error: e);
      common.showSnackbar('Error', 'Failed to reject friend request', Colors.red);
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

      // Find user by email
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

      // Don't allow sending request to self
      if (receiverId == currentUserId.value) {
        common.showSnackbar('Error', 'You cannot send a friend request to yourself', Colors.red);
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
          common.showSnackbar('Info', 'This user is already your friend', Colors.blue);
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
        common.showSnackbar('Info', 'Friend request already sent', Colors.blue);
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
      highlightedUserId.value = receiverId;
   common.showSnackbar('Success', 'Friend request sent!', Colors.green);
      emailController.clear();
    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending friend request', error: e);
      common.showSnackbar('Error', 'Failed to send friend request: ${e.message}', Colors.red);

    } catch (e) {
      _logger.e('Unexpected error sending friend request', error: e);
      common.showSnackbar('Error', 'An unexpected error occurred', Colors.red);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendMessageToUser(String receiverId, String message) async {
    if (receiverId.isEmpty || message.trim().isEmpty) {
      common.showSnackbar('Error', 'Invalid message data', Colors.red);
      return;
    }

    if (currentUserId.value.isEmpty) {
      common.showSnackbar('Error', 'User not authenticated', Colors.red);
      return;
    }

    try {
      isSendingMessage.value = true;

      // Create the message model first
      final messageModel = await _chatService.sendMessage(
        senderId: currentUserId.value,
        receiverId: receiverId,
        message: message.trim(),
        senderName: currentUser.value?.name ?? 'Unknown',
        senderPhotoUrl: currentUser.value?.photoUrl,
      );
      
      if (messageModel != null) {
        messages.add(messageModel);
        messages.refresh();
        
        updateUserChats();
      }

      _logger.i('Message sent successfully: ${messageModel.id}');

    } on FirebaseException catch (e) {
      _logger.e('Firebase error sending message to user', error: e);
      common.showSnackbar('Error', 'Failed to send message: ${e.message}', Colors.red);
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error sending message to user', error: e);
      common.showSnackbar('Error', 'Failed to send message', Colors.red);
      rethrow;
    } finally {
      isSendingMessage.value = false;
    }
  }

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
      common.showSnackbar('Error', 'Failed to search users', Colors.red);
      searchResults.clear();
    } catch (e) {
      _logger.e('Unexpected error searching users', error: e);
      common.showSnackbar('Error', 'Unexpected error occurred', Colors.red);
      searchResults.clear();
    } finally {
      isLoading.value = false;
    }
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

}