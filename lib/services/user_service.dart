import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger();

  CollectionReference<Map<String, dynamic>> get _usersRef => _firestore.collection('users');

  /// Gets the current user's data
  User? get currentFirebaseUser => _auth.currentUser;

  /// Gets the current user's ID
  String? get currentUserId => _auth.currentUser?.uid;

  Stream<UserModel?> getCurrentUserStream() {
    final userId = currentUserId;
    if (userId == null) {
      _logger.d('No current user ID available');
      return Stream.value(null);
    }

    return _usersRef
        .doc(userId)
        .snapshots()
        .map<UserModel?>((doc) {
          if (!doc.exists) {
            _logger.w('Current user document does not exist: $userId');
            return null;
          }
          try {
            return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
          } catch (e, stackTrace) {
            _logger.e('Error parsing user data', 
              error: e, 
              stackTrace: stackTrace,
            );
            return null;
          }
        })
        .handleError((error, stackTrace) {
          _logger.e('Error in current user stream', 
            error: error, 
            stackTrace: stackTrace,
          );
          return null;
        });
  }

  Stream<List<UserModel>> getUsers({String? excludeUserId, int limit = 20}) {
    try {
      Query<Map<String, dynamic>> query = _usersRef.limit(limit);

      if (excludeUserId != null && excludeUserId.isNotEmpty) {
        query = query.where(FieldPath.documentId, isNotEqualTo: excludeUserId);
      }

      return query.snapshots().map<List<UserModel>>((snapshot) {
        return snapshot.docs.map<UserModel>((doc) {
          try {
            return UserModel.fromMap({...doc.data(), 'uid': doc.id});
          } catch (e, stackTrace) {
            _logger.e('Error parsing user data for ${doc.id}',
              error: e,
              stackTrace: stackTrace,
            );
            // Skip invalid user documents
            return UserModel(
              uid: doc.id,
              name: 'Invalid User',
              email: 'invalid@example.com',
            );
          }
        }).where((user) => user.uid.isNotEmpty).toList();
      }).handleError((error, stackTrace) {
        _logger.e('Error in users stream', 
          error: error,
          stackTrace: stackTrace,
        );
        return [];
      });
    } catch (e, stackTrace) {
      _logger.e('Error setting up users stream',
        error: e,
        stackTrace: stackTrace,
      );
      return Stream.value([]);
    }
  }

  /// Gets a single user by ID
  Future<UserModel?> getUser(String userId) async {
    if (userId.isEmpty) {
      _logger.w('getUser called with empty userId');
      return null;
    }

    try {
      final doc = await _usersRef.doc(userId).get();
      if (!doc.exists) {
        _logger.w('User not found with id: $userId');
        return null;
      }
      return UserModel.fromMap({...doc.data()!, 'uid': doc.id});
    } on FirebaseException catch (e) {
      _logger.e('Firebase error getting user $userId', error: e, stackTrace: StackTrace.current);
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error getting user $userId', error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }


  Future<void> saveUser(UserModel user) async {
    try {
      if (user.uid.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      
      final userData = user.toMap(includeId: false);
      
      // Add server timestamps
      final now = FieldValue.serverTimestamp();
      userData['updatedAt'] = now;
      if (!userData.containsKey('createdAt')) {
        userData['createdAt'] = now;
      }
      
      await _usersRef.doc(user.uid).set(userData, SetOptions(merge: true));
      _logger.i('User saved successfully: ${user.uid}');
      
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('Firebase error saving user ${user.uid}', 
        error: e, 
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error saving user ${user.uid}', 
        error: e, 
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateUser(
    String userId, 
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }
    if (data.isEmpty) {
      throw ArgumentError('Data cannot be empty');
    }

    try {
      // Add updatedAt timestamp
      final updateData = Map<String, dynamic>.from(data)
        ..['updatedAt'] = FieldValue.serverTimestamp();
      
      if (merge) {
        await _usersRef.doc(userId).set(updateData, SetOptions(merge: true));
      } else {
        await _usersRef.doc(userId).update(updateData);
      }
      
      _logger.d('User $userId updated successfully');
    } on FirebaseException catch (e) {
      _logger.e('Firebase error updating user', error: e, stackTrace: StackTrace.current);
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error updating user', error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  /// Deletes a user (admin only)
  Future<bool> deleteUser(String userId) async {
    if (userId.isEmpty) {
      _logger.w('deleteUser called with empty userId');
      return false;
    }

    try {
      await _usersRef.doc(userId).delete();
      _logger.i('User deleted successfully: $userId');
      return true;
    } on FirebaseException catch (e) {
      _logger.e('Firebase error deleting user', error: e, stackTrace: StackTrace.current);
      return false;
    } catch (e) {
      _logger.e('Unexpected error deleting user', error: e, stackTrace: StackTrace.current);
      return false;
    }
  }

  /// Searches for users by name, email, or other fields
  /// 
  /// [query] The search term to look for in user names or emails
  /// [excludeUserId] Optional user ID to exclude from results
  /// [limit] Maximum number of results to return (default: 10)
  /// 
  /// Returns a list of users matching the query, or empty list on error
  Future<List<UserModel>> searchUsers(
    String query, {
    String? excludeUserId,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final queryLower = query.trim().toLowerCase();
      
      // Search by name (using array-contains for search terms)
      final nameQuery = _usersRef
          .where('searchTerms', arrayContains: queryLower)
          .limit(limit);
      
      // Search by email prefix (more efficient than contains)
      final emailQuery = _usersRef
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThanOrEqualTo: queryLower + '\uf8ff')
          .limit(limit);
      
      final results = await Future.wait([
        nameQuery.get(),
        emailQuery.get(),
      ], eagerError: true);
      
      // Combine and deduplicate results
      final allResults = <String, UserModel>{};
      
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          if (excludeUserId == null || doc.id != excludeUserId) {
            try {
              allResults[doc.id] = UserModel.fromMap({
                ...doc.data(),
                'uid': doc.id,
              });
            } catch (e, stackTrace) {
              _logger.e('Error parsing user ${doc.id}',
                error: e,
                stackTrace: stackTrace,
              );
              // Skip invalid user documents
              continue;
            }
          }
          
          // Early return if we've reached the limit
          if (allResults.length >= limit) {
            return allResults.values.take(limit).toList();
          }
        }
      }
      
      return allResults.values.toList();
      
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('Firebase error searching users', 
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error searching users',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Updates the user's FCM token for push notifications
  Future<void> updateFcmToken(String userId, String? fcmToken) async {
    if (userId.isEmpty) return;

    
    try {
      await _usersRef.doc(userId).update({
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.log('Error updating FCM token: $e');
    }
  }
  
  /// Updates the user's online status
  Future<void> updateUserPresence(String userId, bool isOnline) async {
    if (userId.isEmpty) return;
    
    try {
      await _usersRef.doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.log('Error updating user presence: $e');
    }
  }
  
  /// Gets a stream of a user's data
  Stream<UserModel?> userStream(String userId) {
    if (userId.isEmpty) return const Stream.empty();

    return _usersRef
        .doc(userId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return UserModel.fromMap({
        ...data,
        'uid': doc.id, // ensure UID is included
      });
    });
  }


  /// Gets a list of users by their IDs
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final results = await _usersRef
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      return results.docs.map((doc) {
        final data = doc.data();
        if (data == null) {
          return null;
        }
        return UserModel.fromMap({
          ...data,
          'uid': doc.id, // ensure UID is included
        });
      }).whereType<UserModel>().toList(); // filter out nulls
    } catch (e) {
      Get.log('Error getting users by IDs: $e');
      return [];
    }
  }

  /// Updates user's profile image URL
  Future<void> updateProfileImage(String userId, String imageUrl) async {
    if (userId.isEmpty) return;
    
    try {
      await _usersRef.doc(userId).update({
        'photoUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.log('Error updating profile image: $e');
      rethrow;
    }
  }
}
