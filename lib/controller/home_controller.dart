import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/animation.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class HomeController extends GetxController with GetSingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  late TickerProvider vsyncProvider;

  var users = <UserModel>[].obs;
  var isLoading = false.obs;
  var currentUser = Rxn<UserModel>();

  @override
  void onInit() {
    super.onInit();
    vsyncProvider = this;
    isLoading.value = true;
    _userService.getUsers().listen((event) {
      users.assignAll(event);

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        try {
          currentUser.value = event.firstWhere(
                (u) => u.uid == firebaseUser.uid,
          );
        } catch (e) {
          // agar list me nahi mila
          currentUser.value = UserModel(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName ?? '',
            email: firebaseUser.email ?? '',
            photoUrl: firebaseUser.photoURL ?? '',
            bannerUrl: '',
          );
        }
      }

      isLoading.value = false;
    }, onError: (err) {
      isLoading.value = false;
      print("Error loading users: $err");
    });
  }
}
