import 'dart:ui';

import 'package:ads_demo/constant/common.dart';
import 'package:ads_demo/controller/home_controller.dart';
import 'package:ads_demo/controller/profile_controller.dart';
import 'package:ads_demo/services/chat_services/chat_services.dart';
import 'package:ads_demo/widgets/glass.dart';
import 'package:animated_background/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../controller/chat_controller.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final bool isCurrentUser;

  const ProfileScreen({super.key, this.userId, this.isCurrentUser = false});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final ChatController _chatController = Get.find<ChatController>();
  late final ProfileController profileController;
  final ChatService chatService = ChatService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  File? _pickedImage;
  bool _isLoading = true;
  UserModel? _user;
  List<UserModel> _friends = [];
  bool _isLoadingFriends = true;
  final HomeController homeController = Get.find();

  @override
  void initState() {
    super.initState();
    // Initialize ProfileController
    profileController = Get.put(ProfileController());
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = widget.userId ?? _chatController.currentUserId.value;
      if (userId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Load user data
      final userData = await chatService.getUserData(userId);
      if (userData != null) {
        setState(() {
          _user = userData;
          // Initialize controllers with user data
          _nameController.text = _user?.name ?? '';
          _bioController.text = _user?.bio ?? '';
          _emailController.text = _user?.email ?? '';
          _statusController.text = _user?.status ?? '';

          // Update ProfileController
          profileController.user.value = _user;
          profileController.name.value = _user?.name ?? '';
          profileController.bio.value = _user?.bio ?? '';
          profileController.status.value = _user?.status ?? '';
        });

      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFriends() async {
    try {
      setState(() => _isLoadingFriends = true);
      final userId = widget.userId ?? _chatController.currentUserId.value;
      if (userId.isNotEmpty) {
        final friends = chatService.getUserChats(userId);
        // setState(() => _friends = friends);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load friends: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
        });
        // TODO: Upload the image to Firebase Storage and update user's photoUrl
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      // Update ProfileController values
      profileController.name.value = _nameController.text.trim();
      profileController.bio.value = _bioController.text.trim();
      profileController.status.value = _statusController.text.trim();

      // Save changes through ProfileController
      await profileController.saveChanges();

      setState(() {
        _user = profileController.user.value;
      });

      Get.snackbar('Success', 'Profile updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProfileHeader() {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: _pickedImage != null
                ? Image.file(_pickedImage!, fit: BoxFit.cover)
                : CachedNetworkImage(
              imageUrl: _user?.photoUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
        Obx(() => profileController.isEditing.value
            ? Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: _pickImage,
            child: Container(
              decoration:const  BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent,
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
          ),
        )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 30, left: 16, right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name - editable
          GlassInfoCard(
            label: 'Name',
            value: profileController.name,
            controller: profileController,
            fieldName: 'name',
            textController: _nameController,
            isEditable: true,
          ),
          // Email - non-editable
          GlassInfoCard(
            label: 'Email',
            value: RxString(_user?.email ?? ''),
            controller: profileController,
            fieldName: 'email',
            isEditable: false,
          ),
          // Bio - editable
          GlassInfoCard(
            label: 'Bio',
            value: profileController.bio,
            controller: profileController,
            fieldName: 'bio',
            textController: _bioController,
            isEditable: true,
          ),

          // CreatedAt - non-editable
          GlassInfoCard(
            label: 'Created At',
            value: RxString(
              _user?.createdAt != null
                  ? '${_user!.createdAt!.day}/'
                  '${_user!.createdAt!.month}/'
                  '${_user!.createdAt!.year}'
                  : '',
            ),
            controller: profileController,
            fieldName: 'createdAt',
            isEditable: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1e3c72),
                Color(0xFF2a5298),
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const  Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('User not found', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go back', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1e3c72),
                  const Color(0xFF2a5298),
                  Colors.black12.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: AnimatedBackground(
              vsync: this,
              behaviour: Common().buildBehaviour(),
              child: Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 80),
                      _buildProfileHeader(),
                      _buildProfileInfo(),
                      _buildSignOutButton(
                        onPressed: () {
                          _chatController.signOut();
                        },
                      ),
                    ],
                  ),
                  // Back button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                    ),
                  ),
                  // Edit profile button (for current user)
                  if (widget.isCurrentUser ||
                      _user?.uid == _chatController.currentUserId.value)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Obx(() => profileController.isEditing.value
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                profileController.cancelEditing();
                                setState(() {
                                  _pickedImage = null;
                                  _nameController.text = _user?.name ?? '';
                                  _bioController.text = _user?.bio ?? '';
                                  _statusController.text = _user?.status ?? '';
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                              onPressed: _saveProfile,
                            ),
                          ],
                        )
                            : IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            profileController.enableEditing();
                          },
                        )),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton({required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, color: Colors.redAccent, size: 22),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}