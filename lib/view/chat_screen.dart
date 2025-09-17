import 'dart:ui';
import 'package:ads_demo/constant/common.dart';
import 'package:ads_demo/services/chat_services.dart';
import 'package:ads_demo/widgets/glass.dart';
import 'package:animated_background/animated_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controller/chat_controller.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/particle_pointers.dart';

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
  final ChatService _chatService = ChatService();
  final FocusNode _focusNode = FocusNode();

  bool _isEmojiVisible = false;
  bool _isLoading = true;
  bool _isTyping = false;
  UserModel? _peerUser;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // General Variables
  int _behaviourIndex = 0;
  Behaviour? _behaviour;

  @override
  void initState() {
    super.initState();
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

  // Replace the _initializeChat method in ChatScreen with this:

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);

    try {
      if (widget.peerUser != null) {
        _peerUser = widget.peerUser;
      } else if (widget.chatId != null) {
        // If we have chatId but no peer user, extract peer ID from chatId
        final chatIdParts = widget.chatId!.split('_');
        if (chatIdParts.length == 2) {
          final currentUserId = _chatController.currentUserId.value;
          final peerUserId = chatIdParts[0] == currentUserId
              ? chatIdParts[1]
              : chatIdParts[0];

          final userData = await _chatService.getUserData(peerUserId);
          if (userData != null) {
            _peerUser = userData;
          }
        }
      }

      if (_peerUser == null) {
        throw Exception('Unable to load peer user data');
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
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    setState(() => _isTyping = false);

    try {
      await _chatController.sendMessageToUser(
        widget.peerUser?.uid ?? '',
        message,
      );
      _scrollToBottom();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send message: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      _messageController.text = message;
      setState(() => _isTyping = true);
    }
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
                isMe: isMe,
                showTime: true, // Always show time for better UI
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 25,
        opacity: 0.2,
        child: Row(
          children: [
            // Emoji button
            _buildActionButton(
              icon: Icons.emoji_emotions_outlined,
              onPressed: () {
                _focusNode.unfocus();
                setState(() => _isEmojiVisible = !_isEmojiVisible);
              },
            ),

            // Text input field
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    fillColor: Colors.transparent,
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),

            // Camera button
            _buildActionButton(
              icon: Icons.camera_alt_rounded,
              onPressed: () {
                // TODO: Implement camera
              },
            ),

            // Send/Voice button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: _buildActionButton(
                icon: _isTyping ? Icons.send_rounded : Icons.mic_rounded,
                onPressed: _isTyping ? _sendMessage : () {},
                isHighlighted: _isTyping,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isHighlighted
                  ? LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.6),
                        Colors.purple.withOpacity(0.6),
                      ],
                    )
                  : null,
            ),
            child: Icon(
              icon,
              color: isHighlighted
                  ? Colors.white
                  : Colors.white.withOpacity(0.7),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
                      padding: const EdgeInsets.all(2),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
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
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _peerUser?.isOnline == true
                                    ? Colors.greenAccent
                                    : Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _peerUser?.isOnline == true
                                  ? 'Online'
                                  : 'Offline',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                _buildAppBarAction(Icons.videocam_rounded, () {
                  // TODO: Implement video call
                }),
                _buildAppBarAction(Icons.call_rounded, () {
                  // TODO: Implement voice call
                }),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  color: Colors.transparent,
                  elevation: 0,
                  onSelected: (value) {
                    switch (value) {
                      case 'mute':
                        // TODO: Implement mute notifications
                        break;
                      case 'clear_chat':
                        // TODO: Implement clear chat
                        break;
                      case 'delete':
                        // TODO: Implement block user
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    _buildPopupMenuItem(
                      'mute',
                      Icons.notifications_off_rounded,
                      'Mute Notifications',
                    ),
                    _buildPopupMenuItem(
                      'clear_chat',
                      Icons.delete_rounded,
                      'Clear Chat',
                    ),
                    _buildPopupMenuItem(
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
                child: Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
                  child: _buildMessageList(),
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

  Widget _buildAppBarAction(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    String text,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
