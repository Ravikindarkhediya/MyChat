import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/animation.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class HomeController extends GetxController with GetTickerProviderStateMixin {
  final UserService _userService = UserService();

  var users = <UserModel>[].obs;       // ✅ friends list
  var isLoading = false.obs;
  var currentUser = Rxn<UserModel>();  // ✅ logged-in user profile

  final List<StreamSubscription> _subscriptions = []; // ✅ manage listeners

  @override
  void onInit() {
    super.onInit();
    isLoading.value = true;

    // ✅ Listen to the logged-in user's profile
    _subscriptions.add(
      _userService.getCurrentUserStream().listen((user) {
        if (user != null) {
          currentUser.value = user;

          // ✅ also load this user's friends
          final friendsStream = _userService.getFriendsStream(user.uid);
          _subscriptions.add(
            friendsStream.listen((friendList) {
              users.assignAll(friendList);
              isLoading.value = false;
            }, onError: (err) {
              isLoading.value = false;
              print('Error loading friends: $err');
            }),
          );
        } else {
          // fallback → if user is in FirebaseAuth but not in Firestore
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            currentUser.value = UserModel(
              uid: firebaseUser.uid,
              name: firebaseUser.displayName ?? '',
              email: firebaseUser.email ?? '',
              photoUrl: firebaseUser.photoURL ?? '',
              bannerUrl: '',
            );
          }
          isLoading.value = false;
        }
      }, onError: (err) {
        isLoading.value = false;
      }),
    );
  }

  @override
  void onClose() {
    // ✅ cancel subscriptions to avoid memory leaks
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.onClose();
  }
}
