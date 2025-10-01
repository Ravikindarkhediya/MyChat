import 'dart:ui';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

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

    // Fix data:image parsing
    if (source.startsWith('data:image')) {
      try {
        final uri = Uri.parse(source);
        final bytes = uri.data?.contentAsBytes();
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
      } catch (_) {
        return Container(
          color: Colors.white.withOpacity(0.1),
          child: const Icon(Icons.broken_image, color: Colors.white54),
        );
      }
    }

    // Plain base64 fallback (no prefix) - try decoding if it looks like base64 and not a URL
    final looksLikeUrl = source.startsWith('http://') || source.startsWith('https://') || source.startsWith('gs://');
    final looksLikeBase64 = !looksLikeUrl && source.length > 100 && RegExp(r'^[A-Za-z0-9+/=\r\n]+\$?').hasMatch(source.substring(0, source.length.clamp(0, 256)));
    if (looksLikeBase64) {
      try {
        final bytes = base64Decode(source);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        // fall through to next handlers
      }
    }

    // Handle Firebase Storage gs:// URLs
    if (source.startsWith('gs://')) {
      return FutureBuilder<String?>(
        future: _resolveGsUrl(source),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.white.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            );
          }
          final url = snapshot.data;
          if (url == null || snapshot.hasError) {
            print('❌ Failed to resolve gs:// URL: $source, Error: ${snapshot.error}');
            return Container(
              color: Colors.white.withOpacity(0.1),
              child: const Icon(Icons.broken_image, color: Colors.white54),
            );
          }
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, u) => Container(
              color: Colors.white.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
            errorWidget: (context, u, error) {
              print('❌ CachedNetworkImage error for $url: $error');
              return Container(
                color: Colors.white.withOpacity(0.1),
                child: const Icon(Icons.broken_image, color: Colors.white54),
              );
            },
          );
        },
      );
    }

    // Regular HTTP/HTTPS URLs
    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.white.withOpacity(0.1),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
      errorWidget: (context, url, error) {
        print('❌ CachedNetworkImage error for $url: $error');
        return Container(
          color: Colors.white.withOpacity(0.1),
          child: const Icon(Icons.broken_image, color: Colors.white54),
        );
      },
    );
  }

  Future<String?> _resolveGsUrl(String gsUrl) async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance.refFromURL(gsUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      // keep logs minimal
      debugPrint('Failed to resolve gs url: $e');
      return null;
    }
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
    _loadSharedMedia();
  }

  Future<void> _loadSharedMedia() async {
    currentUserId ??= userService.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

    if (peerUser?.uid == null || currentUserId == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    final images = <String>[];

    try {
      final peerUserId = peerUser!.uid;

      // First try to see what chats exist
      final allChats = await FirebaseFirestore.instance
          .collection('chats')
          .get();

      print('📱 Total chats in database: ${allChats.docs.length}');
      for (var chat in allChats.docs.take(5)) {
        print('   Chat ID: ${chat.id}, Data: ${chat.data()}');
      }

      // Try all methods
      await _method1DirectChatId(currentUserId!, peerUserId, images);

      if (images.isEmpty) {
        await _method2SearchAllChats(currentUserId!, peerUserId, images);
      }

      if (images.isEmpty) {
        await _method3AllMessages(currentUserId!, peerUserId, images);
      }

      // Enhanced filtering (include plain base64 without prefix)
      bool _looksLikeBase64(String s) {
        if (s.isEmpty) return false;
        if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('gs://') || s.startsWith('data:image') || s.startsWith('base64:')) {
          return false;
        }
        if (s.length < 100) return false;
        final head = s.substring(0, s.length.clamp(0, 256));
        return RegExp(r'^[A-Za-z0-9+/=\r\n]+\$?').hasMatch(head);
      }

      var validImages = images
          .where((url) => url.isNotEmpty && (
              url.startsWith('http://') ||
              url.startsWith('https://') ||
              url.startsWith('gs://') ||
              url.startsWith('base64:') ||
              url.startsWith('data:image') ||
              _looksLikeBase64(url)
          ))
          .toSet()
          .toList();
      print('🧮 Images found before exclusion: ${validImages.length}');

      // Exclude known profile/banner URLs (and their resolved https versions) so they don't show as shared media
      final excludeCandidates = <String?>[
        peerUser?.photoUrl,
        peerUser?.bannerUrl,
        FirebaseAuth.instance.currentUser?.photoURL,
      ];
      final excludeSet = <String>{};
      for (final u in excludeCandidates) {
        if (u == null || u.isEmpty) continue;
        excludeSet.add(u);
        if (u.startsWith('gs://')) {
          final resolved = await _resolveGsUrl(u);
          if (resolved != null && resolved.isNotEmpty) excludeSet.add(resolved);
        }
      }

      final afterExclusion = validImages.where((u) => !excludeSet.contains(u)).toList();
      print('🧮 Images after exclusion: ${afterExclusion.length} (excluded: ${validImages.length - afterExclusion.length})');

      // Fallback: if exclusion removed everything but we had some items, keep the pre-exclusion list
      if (afterExclusion.isEmpty && validImages.isNotEmpty) {
        print('⚠️ Exclusion removed all images; using pre-exclusion list to ensure UI shows media.');
      } else {
        validImages = afterExclusion;
      }

      setState(() {
        sharedImages = validImages;
        isLoading = false;
      });

      print('Total valid images found: ${validImages.length}');

      if (validImages.isNotEmpty) {
        print('✅ Sample images:');
        validImages.take(3).forEach((url) => print('   ${url.substring(0, url.length > 100 ? 100 : url.length)}...'));
      }

    } catch (e) {
      print('❌ Error loading shared media: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _method1DirectChatId(String currentUserId, String peerUserId, List<String> images) async {
    try {
      final sortedIds = [currentUserId, peerUserId]..sort();
      final sortedChatId = sortedIds.join('_');

      // Try different chat ID variations
      final chatIds = [
        '${currentUserId}_${peerUserId}',
        '${peerUserId}_${currentUserId}',
        sortedChatId,
      ];

      for (String chatId in chatIds) {
        print('🔍 Trying chat ID: $chatId');

        await userService.debugChatMessages(chatId);

        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .get();

        if (chatDoc.exists) {
          print('✅ Found chat document: $chatId');
          print('Chat data: ${chatDoc.data()}');

          // Get messages with broader query
          final messagesQuery = await chatDoc.reference
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1000)
              .get();

          print('📨 Messages found: ${messagesQuery.docs.length}');

          int imageCount = 0;
          for (var msgDoc in messagesQuery.docs) {
            final data = msgDoc.data();
            print('Message data: $data');

            final urls = _extractAllImageUrls(data);
            if (urls.isNotEmpty) {
              images.addAll(urls);
              imageCount += urls.length;
              print('✅ Added ${urls.length} images from message ${msgDoc.id}');
            }
          }

          print('🎯 Total images found in chat $chatId: $imageCount');

          if (images.isNotEmpty) {
            print('✅ Breaking early, found images');
            break;
          }
        } else {
          print('❌ Chat document not found: $chatId');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Method 1 error: $e');
      print('Stack trace: $stackTrace');
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

  List<String> _extractAllImageUrls(Map<String, dynamic> data) {
    final results = <String>[];

    print('🔍 Analyzing message data: $data');

    // Helper methods
    bool _isValidUrl(dynamic v) => v is String &&
        v.isNotEmpty &&
        (v.startsWith('http://') ||
            v.startsWith('https://') ||
            v.startsWith('gs://') ||
            v.startsWith('data:image'));

    bool _isBase64Image(dynamic v) {
      if (v is! String || v.isEmpty) return false;

      // Data URL format (data:image/jpeg;base64,...)
      if (v.startsWith('data:image') && v.contains('base64,')) {
        return true;
      }

      // Base64 prefix format (base64:...)
      if (v.startsWith('base64:')) return true;

      // Plain base64 heuristic
      if (v.startsWith('http://') || v.startsWith('https://') || v.startsWith('gs://')) {
        return false;
      }
      if (v.length < 100) return false;

      final head = v.substring(0, v.length.clamp(0, 256));
      return RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(head);
    }

    // Get message type
    final type = (data['type'] ?? '').toString().toLowerCase();
    print('📝 Message type: $type');

    // 1. ✅ Priority check - mediaUrl field (most important for your case)
    if (data['mediaUrl'] != null) {
      final mediaUrl = data['mediaUrl'] as String;
      if (_isValidUrl(mediaUrl) || _isBase64Image(mediaUrl)) {
        results.add(mediaUrl);
        print('✅ Found image in mediaUrl: ${mediaUrl.length > 50 ? "${mediaUrl.substring(0, 50)}..." : mediaUrl}');
      }
    }

    // 2. ✅ Check if this is an image message type
    if (type == 'image' || type == 'photo' || type == 'media') {

      // Check content field for base64 images
      if (data['content'] != null) {
        final content = data['content'] as String;
        if (_isBase64Image(content)) {
          results.add(content);
          print('✅ Found base64 image in content field');
        }
      }

      // Check other common image fields
      final imageFields = [
        'imageUrl', 'image', 'url', 'src', 'downloadUrl',
        'attachment_url', 'file_url', 'photo', 'picture'
      ];

      for (final field in imageFields) {
        if (data[field] != null) {
          final value = data[field] as String;
          if (_isValidUrl(value) || _isBase64Image(value)) {
            results.add(value);
            print('✅ Found image in $field');
          }
        }
      }
    }

    // 3. ✅ Skip profile/sender images
    final excludeFields = ['senderPhotoUrl', 'receiverPhotoUrl', 'userPhotoUrl'];
    for (final field in excludeFields) {
      if (data[field] != null) {
        final value = data[field] as String;
        print('⏭️ Skipping profile image at $field');
      }
    }

    print('🎯 Total images found in this message: ${results.length}');
    return results.toSet().toList();
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
    } else if (src.startsWith('data:image')) {
      final comma = src.indexOf(',');
      if (comma != -1) {
        final b64 = src.substring(comma + 1);
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
      }
    } else if (!(src.startsWith('http://') || src.startsWith('https://') || src.startsWith('gs://'))) {
      // Try plain base64 for viewer
      try {
        final bytes = base64Decode(src);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.transparent),
              body: Center(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        );
        return;
      } catch (_) {
        // not base64, fall through
      }
    } else if (src.startsWith('gs://')) {
      // Resolve and then open
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      _resolveGsUrl(src).then((url) {
        Navigator.of(context).pop(); // close loader
        if (url != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImage(url: url),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load image')),
          );
        }
      });
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
          child: () {
            final bannerUrl = peerUser?.bannerUrl;
            if (bannerUrl == null || bannerUrl.isEmpty) {
              return Container(
                color: Colors.white.withOpacity(0.1),
                child: Icon(
                  Icons.image_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
              );
            }
            if (bannerUrl.startsWith('gs://')) {
              return FutureBuilder<String?>(
                future: _resolveGsUrl(bannerUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(color: Colors.white.withOpacity(0.1));
                  }
                  final url = snapshot.data;
                  if (url == null) {
                    return Container(
                      color: Colors.white.withOpacity(0.1),
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    );
                  }
                  return CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, _) =>
                        Container(color: Colors.white.withOpacity(0.1)),
                    errorWidget: (context, _, __) => Container(
                      color: Colors.white.withOpacity(0.1),
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  );
                },
              );
            }
            return CachedNetworkImage(
              imageUrl: bannerUrl,
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
            );
          }(),
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
                child: () {
                  final photoUrl = peerUser?.photoUrl;
                  if (photoUrl == null || photoUrl.isEmpty) {
                    return CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        peerUser?.name[0].toUpperCase() ?? '?',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }
                  if (photoUrl.startsWith('gs://')) {
                    return FutureBuilder<String?>(
                      future: _resolveGsUrl(photoUrl),
                      builder: (context, snapshot) {
                        final url = snapshot.data;
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (url == null) {
                          return CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            child: Text(
                              peerUser?.name[0].toUpperCase() ?? '?',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }
                        return CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: CachedNetworkImageProvider(url),
                        );
                      },
                    );
                  }
                  return CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: CachedNetworkImageProvider(photoUrl),
                  );
                }(),
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
