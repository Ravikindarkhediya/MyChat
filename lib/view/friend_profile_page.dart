import 'dart:ui';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/calling_service.dart';
import '../services/user_service.dart';
import '../widgets/glass.dart';
import '../view/shared_media_grid_view.dart';
import '../widgets/full_screen_image.dart';

class FriendProfilePage extends StatefulWidget {
  const FriendProfilePage({super.key});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  // State variables
  UserModel? peerUser;
  bool isLoading = true;
  List<String> sharedImages = [];
  final UserService userService = UserService();
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Widget _buildThumbnail(String source) {
    if (source.startsWith('base64:')) {
      final b64 = source.substring(7);
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Container(
          color: Colors.white.withOpacity(0.1),
          child: const Icon(Icons.broken_image, color: Colors.white54),
        );
      }
    }
    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.white.withOpacity(0.1),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.white.withOpacity(0.1),
        child: const Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get arguments from route
    if (peerUser == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is UserModel) {
        _setPeerUser(args);
      }
    }
  }

  void _initializeData() async {
    // Set current user ID (prefer UserService, fallback to FirebaseAuth)
    currentUserId = userService.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    print('🎯 FriendProfilePage initialized. currentUserId: ' + (currentUserId ?? 'null'));
    // If peerUser already available (e.g., passed quickly), try loading media
    if (peerUser != null && currentUserId != null) {
      await _loadSharedMedia();
      if (mounted) setState(() {});
    }
  }

  void _setPeerUser(UserModel user) {
    setState(() {
      peerUser = user;
    });
    print('✅ Peer user set: ${user.name} (UID: ${user.uid})');
    _loadSharedMedia();
  }

  Future<void> _loadSharedMedia() async {
    // Ensure we have current user id (retry once)
    currentUserId ??= userService.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

    if (peerUser?.uid == null || currentUserId == null) {
      print('❌ Cannot load media: missing user data');
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    final images = <String>[];

    try {
      final peerUserId = peerUser!.uid;

      print('🔍 Loading shared media between:');
      print('   Current User: $currentUserId');
      print('   Peer User: $peerUserId');

      // Try multiple approaches
      await _method1DirectChatId(currentUserId!, peerUserId, images);

      if (images.isEmpty) {
        await _method2SearchAllChats(currentUserId!, peerUserId, images);
      }

      if (images.isEmpty) {
        await _method3AllMessages(currentUserId!, peerUserId, images);
      }

      // Normalize and filter valid URLs and remove duplicates
      final validImages = images
          .where((url) => url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://')))
          .toSet()
          .toList();

      setState(() {
        sharedImages = validImages;
        isLoading = false;
      });

      print('############ shared Images : ${sharedImages.length}');

      if (validImages.isNotEmpty) {
        print('✅ Sample images:');
        validImages.take(3).forEach((url) => print('   $url'));
      } else {
        print('❌ No valid images found');
      }

    } catch (e, stackTrace) {
      print('❌ Error loading shared media: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Method 1: Direct chat ID approach
  Future<void> _method1DirectChatId(String currentUserId, String peerUserId, List<String> images) async {
    try {
      final sortedIds = [currentUserId, peerUserId]..sort();
      final sortedChatId = sortedIds.join('_');

      final chatIds = [
        '${currentUserId}_${peerUserId}',
        '${peerUserId}_${currentUserId}',
        sortedChatId,
      ];

      for (String chatId in chatIds) {
        print('🔍 Trying chat ID: $chatId');

        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .get();

        if (chatDoc.exists) {
          print('✅ Found chat document: $chatId');

          final messagesQuery = await chatDoc.reference
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(500)
              .get();

          print('📨 Messages found: ${messagesQuery.docs.length}');

          for (var msgDoc in messagesQuery.docs) {
            final data = msgDoc.data();
            final urls = _extractAllImageUrls(data);
            if (urls.isNotEmpty) {
              images.addAll(urls);
            }
          }

          if (images.isNotEmpty) break;
        } else {
          print('❌ Chat document not found: $chatId');
        }
      }
    } catch (e) {
      print('❌ Method 1 error: $e');
    }
  }

  // Method 2: Search all chats with participants
  Future<void> _method2SearchAllChats(String currentUserId, String peerUserId, List<String> images) async {
    try {
      print('🔍 Method 2: Searching all chats...');

      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      print('📱 Found ${chatsQuery.docs.length} chats for current user');

      for (var chatDoc in chatsQuery.docs) {
        final data = chatDoc.data();
        final participants = List<String>.from(data['participants'] ?? []);

        print('Chat ${chatDoc.id} participants: $participants');

        if (participants.contains(peerUserId)) {
          print('✅ Found matching chat: ${chatDoc.id}');

          final messagesQuery = await chatDoc.reference
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

          print('📨 Messages in chat: ${messagesQuery.docs.length}');

          for (var msgDoc in messagesQuery.docs) {
            final messageData = msgDoc.data();
            final urls = _extractAllImageUrls(messageData);
            if (urls.isNotEmpty) images.addAll(urls);
          }
        }
      }
    } catch (e) {
      print('❌ Method 2 error: $e');
    }
  }

  // Method 3: Get all messages and filter client-side
  Future<void> _method3AllMessages(String currentUserId, String peerUserId, List<String> images) async {
    try {
      print('🔍 Method 3: Getting all messages...');

      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        final participants = List<String>.from(chatDoc.data()['participants'] ?? []);

        if (participants.contains(peerUserId)) {
          final allMessages = await chatDoc.reference
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .get();

          print('📨 All messages: ${allMessages.docs.length}');

          for (var msgDoc in allMessages.docs) {
            final data = msgDoc.data();
            final urls = _extractAllImageUrls(data);
            if (urls.isNotEmpty) images.addAll(urls);
          }
        }
      }
    } catch (e) {
      print('❌ Method 3 error: $e');
    }
  }

  // Helper: extract all possible image URLs from message data
  List<String> _extractAllImageUrls(Map<String, dynamic> data) {
    final results = <String>[];

    bool _isValidUrl(dynamic v) => v is String && v.isNotEmpty &&
        (v.startsWith('http://') || v.startsWith('https://'));

    // Common direct string fields
    for (final key in const [
      'imageUrl', 'image', 'photoUrl', 'content', 'url', 'file_url', 'attachment_url'
    ]) {
      final v = data[key];
      if (_isValidUrl(v)) results.add(v as String);
    }

    // Message field could be string or map with url
    final msg = data['message'];
    if (_isValidUrl(msg)) results.add(msg as String);
    if (msg is Map) {
      for (final k in ['url', 'imageUrl', 'photoUrl']) {
        final v = msg[k];
        if (_isValidUrl(v)) results.add(v as String);
      }
    }

    // If message type is image and content likely base64, capture it
    final type = (data['type'] ?? '').toString().toLowerCase();
    final content = data['content'];
    if (type.contains('image') && content is String && content.isNotEmpty && !content.startsWith('http')) {
      // Heuristic: base64 strings are usually long and only base64 chars
      final isBase64 = RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(content) && content.length > 100;
      if (isBase64) {
        results.add('base64:' + content);
      }
    }

    // Attachments: list of maps/strings
    for (final listKey in const ['attachments', 'files', 'media']) {
      final list = data[listKey];
      if (list is List) {
        for (final item in list) {
          if (_isValidUrl(item)) results.add(item as String);
          if (item is Map) {
            for (final k in ['url', 'imageUrl', 'photoUrl', 'file_url', 'path']) {
              final v = item[k];
              if (_isValidUrl(v)) results.add(v as String);
            }
          }
        }
      }
    }

    return results;
  }

  void _openFullScreenGrid() {
    if (sharedImages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedMediaGridView(
          images: sharedImages,
          onImageTap: _openImageViewer,
        ),
      ),
    );
  }

  void _openImageViewer(int index) {
    if (index < 0 || index >= sharedImages.length) return;
    final src = sharedImages[index];
    if (src.startsWith('base64:')) {
      final b64 = src.substring(7);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: Center(
              child: Image.memory(base64Decode(b64), fit: BoxFit.contain),
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(url: src),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298), Colors.black],
          ),
        ),
        child: peerUser == null
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(),
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              _buildUserInfo(),
              const SizedBox(height: 24),
              _buildSharedMedia(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.3),
                Colors.purple.withOpacity(0.3),
              ],
            ),
          ),
          child: peerUser?.bannerUrl != null
              ? CachedNetworkImage(
            imageUrl: peerUser!.bannerUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: Colors.white.withOpacity(0.1)),
            errorWidget: (context, url, error) => Container(
              color: Colors.white.withOpacity(0.1),
              child: Icon(
                Icons.broken_image_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          )
              : Container(
            color: Colors.white.withOpacity(0.1),
            child: Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: 0,
          right: 0,
          child: Center(
            child: Hero(
              tag: 'profile_${peerUser?.uid}',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: peerUser?.photoUrl != null
                      ? CachedNetworkImageProvider(peerUser!.photoUrl!)
                      : null,
                  child: peerUser?.photoUrl == null
                      ? Text(
                    peerUser?.name[0].toUpperCase() ?? '?',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return GlassContainer(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            peerUser?.name ?? 'Unknown',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            peerUser?.email ?? '',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              peerUser?.bio ?? 'Bio not available',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSharedMedia() {
    if (isLoading) {
      return const GlassContainer(
        margin: EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (sharedImages.isEmpty) {
      return GlassContainer(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No shared media yet',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shared Media',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: _openFullScreenGrid,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sharedImages.length.clamp(0, 10),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _openImageViewer(index),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildThumbnail(sharedImages[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.videocam_rounded,
            label: 'Video Call',
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.6),
                Colors.blue.withOpacity(0.4),
              ],
            ),
            onTap: () {
              if (peerUser != null && currentUserId != null) {
                CallingService().startVideoCall(
                  peerUser!.uid,
                  'Current User', // You'll need to get actual current user name
                  currentUserId!,
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.call_rounded,
            label: 'Voice Call',
            gradient: LinearGradient(
              colors: [
                Colors.green.withOpacity(0.6),
                Colors.green.withOpacity(0.4),
              ],
            ),
            onTap: () {
              if (peerUser != null && currentUserId != null) {
                CallingService().startVideoCall(
                  peerUser!.uid,
                  'Current User', // You'll need to get actual current user name
                  currentUserId!,
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.person_remove_rounded,
            label: 'Delete',
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.6),
                Colors.red.withOpacity(0.4),
              ],
            ),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text(
                    'Delete Friend',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Are you sure you want to remove this friend?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed == true && currentUserId != null) {
                final success = await userService.removeFriend(
                  currentUserId: currentUserId!,
                  friendUserId: peerUser?.uid ?? '',
                );

                if (success && mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Friend removed'),
                      backgroundColor: Colors.green.withOpacity(0.8),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
