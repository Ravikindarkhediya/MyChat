import 'package:ads_demo/models/user_model.dart';

class FriendRequest {
  final String id;
  final String senderId;
  final UserModel sender;
  final String status;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.sender,
    required this.status,
  });
}
