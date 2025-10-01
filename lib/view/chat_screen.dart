import 'dart:ui';
import 'package:ads_demo/constant/common.dart';
import 'package:ads_demo/services/calling_service.dart';
import 'package:ads_demo/services/chat_services/chat_services.dart';
import 'package:ads_demo/services/user_service.dart';
import 'package:animated_background/animated_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controller/chat_controller.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_services/image_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/glass.dart';
import '../widgets/message_input_widget.dart';
import 'chat_screen_widgets/appbar_action.dart';
import 'chat_screen_widgets/popup_widget.dart';
import 'friend_profile_page.dart';
import 'home_page.dart';

class ChatScreen extends StatefulWidget {
  final UserModel? peerUser;
  final String? chatId;

  const ChatScreen({super.key, this.peerUser, this.chatId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatController _chatController = Get.find<ChatController>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ChatService _chatService = ChatService();
  final UserService userService = UserService();

  bool _isEmojiVisible = false;
  bool _isLoading = true;
  bool _isTyping = false;
  UserModel? _peerUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentFirebaseUser => _auth.currentUser;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // General Variables
  int _behaviourIndex = 0;
  Behaviour? _behaviour;

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  @override
  void initState() {
    super.initState();

    if (widget.peerUser?.uid != null) {
      _chatController.listenToTypingStatus(widget.peerUser!.uid);
      _chatController.listenToPeerOnlineStatus(widget.peerUser!.uid);
    }

    _chatController.setCurrentUserOnline();
    _initializeAnimations();
    _initializeChat();
    _messageController.addListener(_onTextChanged);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  void _onTextChanged() {
    final isTyping = _messageController.text.trim().isNotEmpty;
    if (_isTyping != isTyping) {
      setState(() => _isTyping = isTyping);
    }
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);

    try {
      if (widget.peerUser != null) {
        _peerUser = widget.peerUser;
      } else if (widget.peerUser?.uid != null) {
        final userData = await _chatService.getUserData(widget.peerUser!.uid);
        if (userData != null) {
          _peerUser = userData;
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load chat: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    // Ensure typing status is cleared when leaving the screen
    if (widget.peerUser?.uid != null) {
      _chatController.updateTypingStatus(widget.peerUser!.uid, false);
    }
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<MessageModel>>(
      stream: _chatService.getMessages(
        currentUserId: _chatController.currentUserId.value,
        otherUserId: widget.peerUser?.uid ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading messages',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading messages...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: GlassContainer(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.3),
                              Colors.purple.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Start a conversation',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Send your first message to ${_peerUser?.name ?? 'start chatting'}',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe =
                message.senderId == _chatController.currentUserId.value;

            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + (index * 50)),
              child: ChatBubble(
                message: message,
                chatController: _chatController,
                isMe: isMe,
                showTime:
                    index == 0 ||
                    index == messages.length - 1 ||
                    (index > 0 &&
                        messages[index - 1].senderId != message.senderId),
                showStatus:
                    isMe &&
                    (index == 0 ||
                        (index > 0 &&
                            messages[index - 1].senderId != message.senderId)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Column(
      children: [
        _buildTypingIndicator(),

        MessageInputWidget(
          onSendTextMessage: (message) {
            _chatController.sendMessageToUser(_peerUser!.uid, message);
          },
          onSendVoiceMessage: (audioPath, duration) {
            _chatController.sendVoiceMessage(
              _peerUser!.uid,
              audioPath,
              duration,
            );
          },
          onCameraPressed: () async {
            if (_peerUser == null) return;

            final imageFile = await ImageService()
                .showImageSourceDialog();
            if (imageFile != null) {
              _chatController.sendImageMessage(_peerUser!.uid, imageFile);
            }
          },

          onTypingChanged: (isTyping) {
            _chatController.updateTypingStatus(_peerUser!.uid, isTyping);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1e3c72),
                const Color(0xFF2a5298),
                Colors.black,
              ],
            ),
          ),
          child: Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading chat...',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 6),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              titleSpacing: 0,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Get.back(),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Hero(
                    tag: 'avatar_${widget.peerUser?.uid}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: _peerUser?.photoUrl != null
                            ? CachedNetworkImageProvider(_peerUser!.photoUrl!)
                            : null,
                        child: _peerUser?.photoUrl == null
                            ? Text(
                                _peerUser?.name.isNotEmpty == true
                                    ? _peerUser!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        print('🚀 Navigation button tapped');
                        print(
                          '🚀 _peerUser: ${_peerUser?.name} (${_peerUser?.uid})',
                        );

                        if (_peerUser != null) {
                          print(
                            '✅ Navigating with peerUser: ${_peerUser!.name}',
                          );
                          Get.to(
                            () => const FriendProfilePage(),
                            arguments: _peerUser,
                          );
                        } else {
                          print(
                            '❌ _peerUser is null, cannot navigate with user data',
                          );
                          // You can either show an error or navigate without arguments
                          Get.snackbar(
                            'Error',
                            'User data not available',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _peerUser?.name ?? 'Loading...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // Live presence + last seen
                          StreamBuilder<UserModel?>(
                            stream: userService.getUserStream(
                              widget.peerUser?.uid ?? '',
                            ),
                            builder: (context, snapshot) {
                              final user = snapshot.data ?? _peerUser;
                              final isOnline = user?.isOnline == true;
                              final lastSeen = user?.lastSeen;
                              final subtitle = isOnline
                                  ? 'Online'
                                  : (lastSeen != null
                                        ? 'last seen ${_formatLastSeen(lastSeen)}'
                                        : 'Offline');
                              return Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline
                                          ? Colors.greenAccent
                                          : Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      subtitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                buildAppBarAction(Icons.videocam_rounded, () {
                  CallingService().startVideoCall(
                    _peerUser!.uid,
                    currentFirebaseUser!.displayName ?? '',
                    currentFirebaseUser!.uid,
                  );
                }),
                buildAppBarAction(Icons.call_rounded, () {
                  CallingService().startVideoCall(
                    _peerUser!.uid,
                    currentFirebaseUser!.displayName ?? '',
                    currentFirebaseUser!.uid,
                  );
                }),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  color: Colors.transparent,
                  elevation: 0,
                  onSelected: (value) async {
                    switch (value) {
                      case 'mute':
                        // TODO: Implement mute notifications
                        break;

                      case 'clear_chat':
                        final success = await _chatService
                            .softDeleteChatForUser(
                              currentUserId:
                                  _chatController.currentUserId.value,
                              friendUserId: widget.peerUser?.uid ?? '',
                            );
                        if (success) {
                          _chatController.clearChatMessages(
                            widget.peerUser?.uid ?? '',
                          );
                          _chatController.updateUserChats();
                        }
                        break;
                      case 'delete':
                        final success = await userService.removeFriend(
                          currentUserId: _chatController.currentUserId.value,
                          friendUserId: widget.peerUser?.uid ?? '',
                        );

                        if (success) {
                          Common().showSnackbar(
                            'Success',
                            'Delete User',
                            Colors.green,
                          );
                          Get.to(() => HomePage());
                        } else {
                          Get.snackbar(
                            'Error',
                            'Failed to remove friend',
                            backgroundColor: Colors.red.withOpacity(0.8),
                            colorText: Colors.white,
                          );
                        }
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    buildPopupMenuItem(
                      'mute',
                      Icons.notifications_off_rounded,
                      'Mute Notifications',
                    ),
                    buildPopupMenuItem(
                      'clear_for_me',
                      Icons.notifications_off_rounded,
                      'Clear Chat',
                    ),
                    buildPopupMenuItem(
                      'block',
                      Icons.block_rounded,
                      'Delete User',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298), Colors.black],
          ),
        ),
        child: AnimatedBackground(
          vsync: this,
          behaviour: _behaviour = Common().buildBehaviour(),
          child: Column(
            children: [
              // Messages list
              Expanded(
                child: Stack(
                  children: [
                    // Messages
                    _buildMessageList(),
                  ],
                ),
              ),

              // Emoji picker
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isEmojiVisible ? 280 : 0,
                child: _isEmojiVisible
                    ? GlassContainer(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Emojis',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _isEmojiVisible = false),
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Emoji picker coming soon!',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Message input
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Obx(() {
      final peerId = _peerUser?.uid;
      if (peerId == null) return const SizedBox.shrink();
      final isOtherUserTyping = _chatController.typingUsers[peerId] ?? false;

      if (!isOtherUserTyping) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated typing dots
                  ...List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'typing...',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
