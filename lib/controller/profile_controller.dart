import 'package:ads_demo/services/user_service.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileController extends GetxController {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Rx<UserModel?> user = Rx<UserModel?>(null);
  RxBool isEditing = false.obs;
  RxBool isChanged = false.obs;
  RxBool isLoading = false.obs;

  // Editable fields
  RxString name = ''.obs;
  RxString photoUrl = ''.obs;
  RxString bannerUrl = ''.obs;
  RxString bio = ''.obs;
  RxString status = ''.obs;

  // Extra info
  RxInt friendsCount = 0.obs;
  RxString lastSeenFormatted = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      isLoading.value = true;
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final u = await _userService.getUser(currentUser.uid);
        if (u != null) {
          user.value = u;
          name.value = u.name;
          photoUrl.value = u.photoUrl ?? '';
          bannerUrl.value = u.bannerUrl ?? '';
          bio.value = u.bio ?? '';
          status.value = u.status ?? 'Online';
          friendsCount.value = u.friends?.length ?? 0;
          _updateLastSeen(u.lastSeen);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load user data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void enableEditing() {
    isEditing.value = true;
    isChanged.value = false;
  }

  void cancelEditing() {
    if (user.value != null) {
      // Reset values to original
      name.value = user.value!.name;
      photoUrl.value = user.value!.photoUrl ?? '';
      bannerUrl.value = user.value!.bannerUrl ?? '';
      bio.value = user.value!.bio ?? '';
      status.value = user.value!.status ?? 'Online';
    }
    isEditing.value = false;
    isChanged.value = false;
  }

  void markChanged() {
    if (!isChanged.value) {
      isChanged.value = true;
    }
  }

  Future<void> saveChanges() async {
    if (user.value == null) {
      Get.snackbar('Error', 'No user data to save');
      return;
    }

    if (!isChanged.value) {
      Get.snackbar('Info', 'No changes to save');
      isEditing.value = false;
      return;
    }

    try {
      isLoading.value = true;

      final updatedUser = UserModel(
        uid: user.value!.uid,
        name: name.value.trim(),
        email: user.value!.email,
        photoUrl: photoUrl.value,
        bannerUrl: bannerUrl.value,
        bio: bio.value.trim(),
        status: status.value.trim(),
        friends: user.value!.friends,
        friendRequests: user.value!.friendRequests,
        lastSeen: DateTime.now(),
        isOnline: true,
        createdAt: user.value!.createdAt,
      );

      await _userService.updateUser(user.value!.uid, updatedUser.toMap());
      user.value = updatedUser;

      // Update last seen
      _updateLastSeen(updatedUser.lastSeen);

      isEditing.value = false;
      isChanged.value = false;

      Get.snackbar('Success', 'Profile updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update profile: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Update last seen formatted string
  void _updateLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return;
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) {
      lastSeenFormatted.value = 'Just now';
    } else if (diff.inHours < 1) {
      lastSeenFormatted.value = '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      lastSeenFormatted.value = '${diff.inHours} hr ago';
    } else {
      lastSeenFormatted.value =
      '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    }
  }

  // Update profile photo
  Future<void> updatePhoto(String url) async {
    photoUrl.value = url;
    markChanged();
  }

  // Update banner
  Future<void> updateBanner(String url) async {
    bannerUrl.value = url;
    markChanged();
  }

  // Update bio
  void updateBio(String value) {
    bio.value = value;
    markChanged();
  }

  // Update status
  void updateStatus(String value) {
    status.value = value;
    markChanged();
  }

  // Update name
  void updateName(String value) {
    name.value = value;
    markChanged();
  }

}