import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'enums.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? bannerUrl;
  final String? status;
  final String? bio;
  final bool? isOnline;
  final DateTime? lastSeen;
  final List<String>? friends;
  final List<String>? friendRequests;
  final Map<String, dynamic>? settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bannerUrl,
    this.status,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    this.friends,
    this.friendRequests,
    this.settings,
    this.createdAt,
    this.updatedAt,
  });

  // Create UserModel from Firestore document
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? 'Unknown User',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      bannerUrl: data['bannerUrl'],
      status: data['status'],
      bio: data['bio'],
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen']?.toDate(),
      friends: data['friends'] != null ? List<String>.from(data['friends']) : null,
      friendRequests: data['friendRequests'] != null ? List<String>.from(data['friendRequests']) : null,
      settings: data['settings'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }
  
  // Create UserModel from Map
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'Unknown User',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      bannerUrl: data['bannerUrl'],
      status: data['status'],
      bio: data['bio'],
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null ? 
        (data['lastSeen'] is Timestamp ? data['lastSeen'].toDate() : DateTime.parse(data['lastSeen'].toString())) : null,
      friends: data['friends'] != null ? List<String>.from(data['friends']) : null,
      friendRequests: data['friendRequests'] != null ? List<String>.from(data['friendRequests']) : null,
      settings: data['settings'],
      createdAt: data['createdAt'] != null ? 
        (data['createdAt'] is Timestamp ? data['createdAt'].toDate() : DateTime.parse(data['createdAt'].toString())) : null,
      updatedAt: data['updatedAt'] != null ? 
        (data['updatedAt'] is Timestamp ? data['updatedAt'].toDate() : DateTime.parse(data['updatedAt'].toString())) : null,
    );
  }

  // Convert UserModel to Map
  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bannerUrl': bannerUrl,
      'status': status,
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'friends': friends,
      'friendRequests': friendRequests,
      'settings': settings,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    
    if (includeId) {
      map['uid'] = uid;
    }
    
    return map;
  }

  // Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? bannerUrl,
    String? status,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? friends,
    List<String>? friendRequests,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      status: status ?? this.status,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
