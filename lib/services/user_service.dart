import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger();

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _friendsRef =>
      _firestore.collection('friends');

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('friendRequests');

  /// Gets the current user's Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  /// Gets the current user's UID
  String? get currentUserId => _auth.currentUser?.uid;

  /// ------------------------------
  /// USER DATA
  /// ------------------------------

  Stream<UserModel?> getCurrentUserStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value(null);

    return _usersRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
      } catch (e, st) {
        _logger.e('Error parsing current user', error: e, stackTrace: st);
        return null;
      }
    });
  }

  Future<UserModel?> getUser(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await _usersRef.doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
    } catch (e, st) {
      _logger.e('Error getting user $userId', error: e, stackTrace: st);
      return null;
    }
  }

  // make new user
  Future<void> saveUser(UserModel user) async {
    if (user.uid.isEmpty) throw ArgumentError('User ID cannot be empty');

    final userData = user.toMap(includeId: false);
    final now = FieldValue.serverTimestamp();
    userData['updatedAt'] = now;
    userData.putIfAbsent('createdAt', () => now);

    // ✅ Ensure default empty lists
    userData.putIfAbsent('friends', () => []);
    userData.putIfAbsent('friendRequests', () => []);

    await _usersRef.doc(user.uid).set(userData, SetOptions(merge: true));
    _logger.i('User saved: ${user.uid}');
  }

  Future<void> updateUser(
    String userId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');
    if (data.isEmpty) throw ArgumentError('data cannot be empty');

    final updateData = Map<String, dynamic>.from(data)
      ..['updatedAt'] = FieldValue.serverTimestamp();

    if (merge) {
      await _usersRef.doc(userId).set(updateData, SetOptions(merge: true));
    } else {
      await _usersRef.doc(userId).update(updateData);
    }
    _logger.d('User $userId updated');
  }

  Future<bool> removeFriend({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(currentUserId);

      await userDoc.update({
        'friends': FieldValue.arrayRemove([friendUserId]),
      });

      return true;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    if (userId.isEmpty) return false;
    try {
      await _usersRef.doc(userId).delete();
      return true;
    } catch (e, st) {
      _logger.e('Error deleting user', error: e, stackTrace: st);
      return false;
    }
  }

  Future<bool> areFriends(String user1, String user2) async {
    final query = await _friendsRef.where('users', arrayContains: user1).get();
    for (var doc in query.docs) {
      final users = List<String>.from(doc['users']);
      if (users.contains(user2)) return true;
    }
    return false;
  }

  Future<List<UserModel>> getUserFriends(String userId) async {
    final query = await _friendsRef.where('users', arrayContains: userId).get();

    final friendIds = <String>{};
    for (var doc in query.docs) {
      final users = List<String>.from(doc['users']);
      friendIds.addAll(users);
    }
    friendIds.remove(userId);

    return getUsersByIds(friendIds.toList());
  }

  /// ------------------------------
  /// SEARCH & STREAMS
  /// ------------------------------

  /// Returns only FRIENDS instead of all users
  Stream<List<UserModel>> getFriendsStream(String userId) async* {
    yield* _friendsRef
        .where('users', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final friendIds = <String>{};
          for (var doc in snapshot.docs) {
            final users = List<String>.from(doc['users']);
            friendIds.addAll(users);
          }
          friendIds.remove(userId);
          return getUsersByIds(friendIds.toList());
        });
  }

  /// Full text search
  Future<List<UserModel>> searchUsers(
    String query, {
    String? excludeUserId,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    final nameQuery = _usersRef
        .where('searchTerms', arrayContains: q)
        .limit(limit);
    final emailQuery = _usersRef
        .where('email', isGreaterThanOrEqualTo: q)
        .where('email', isLessThanOrEqualTo: q + '\uf8ff')
        .limit(limit);

    final results = await Future.wait([nameQuery.get(), emailQuery.get()]);
    final all = <String, UserModel>{};

    for (final snap in results) {
      for (final doc in snap.docs) {
        if (excludeUserId != null && doc.id == excludeUserId) continue;
        all[doc.id] = UserModel.fromMap({...doc.data(), 'uid': doc.id});
        if (all.length >= limit) break;
      }
    }
    return all.values.toList();
  }

  /// ------------------------------
  /// HELPERS
  /// ------------------------------

  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final result = await _usersRef
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      return result.docs.map((doc) {
        return UserModel.fromMap({...doc.data(), 'uid': doc.id});
      }).toList();
    } catch (e) {
      _logger.e('Error getUsersByIds', error: e);
      return [];
    }
  }

  Stream<UserModel?> userStream(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _usersRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
    });
  }

  Future<void> updateFcmToken(String userId, String? fcmToken) async {
    if (userId.isEmpty) return;
    await _usersRef.doc(userId).update({
      'fcmToken': fcmToken,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserPresence(String userId, bool isOnline) async {
    if (userId.isEmpty) return;
    await _usersRef.doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfileImage(String userId, String imageUrl) async {
    if (userId.isEmpty) return;
    await _usersRef.doc(userId).update({
      'photoUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  Future<void> setUserOnline(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': true,
        // Do not overwrite lastSeen when going online; it should reflect last offline time
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error setting user online: $e');
    }
  }

  // ✅ YE METHOD ADD KARO - USER KO OFFLINE SET KARNE KE LIYE
  Future<void> setUserOffline(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error setting user offline: $e');
    }
  }

  // ✅ YE METHOD ADD KARO - SPECIFIC USER KA ONLINE STATUS STREAM
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data();
        return data?['isOnline'] ?? false;
      }
      return false;
    });
  }

  // ✅ YE METHOD ADD KARO - USER DATA KA COMPLETE STREAM
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap({...data, 'uid': userId});
      }
      return null;
    });
  }

}
