import 'package:ads_demo/constant/common.dart';
import 'package:ads_demo/controller/chat_controller.dart';
import 'package:ads_demo/services/user_service.dart';
import 'package:ads_demo/view/profile_screen.dart';
import 'package:ads_demo/widgets/glass.dart';
import 'package:animated_background/animated_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/home_controller.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../widgets/add_friend_dialog.dart';
import 'chat_screen.dart';

class HomePage extends StatelessWidget {
  final HomeController controller = Get.put(HomeController());
  late final ChatController chatController;
  final UserService userService = UserService();
  final user = FirebaseAuth.instance.currentUser;

  HomePage({super.key}) {
    chatController = Get.put(ChatController(userId: user?.uid ?? ''));
  }

  void _showFriendRequestDialog(BuildContext context, FriendRequest request) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Friend Request'),
        content: Text(
          'Accept or reject friend request from ${request.sender.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              chatController.acceptFriendRequest(request.id, request.senderId);
              Get.back();
            },
            child: const Text('Accept'),
          ),
          TextButton(
            onPressed: () {
              chatController.rejectFriendRequest(request.id);
              Get.back();
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black.withOpacity(0.3),
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Obx(() {
          final user = controller.currentUser.value;
          if (user == null || user.uid.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return GestureDetector(
            onTap: (){
              Get.to(()=> const ProfileScreen());
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(user.photoUrl.toString()),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Get.to(() => const ProfileScreen());
            },
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298), Colors.black],
          ),
        ),
        child: AnimatedBackground(
          vsync: controller,
          behaviour: Common().buildBehaviour(),
          child: Obx(() {
            final allUsers = <dynamic>[];
            allUsers.addAll(chatController.friends);
            allUsers.addAll(chatController.friendRequests);

            if (chatController.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (allUsers.isEmpty) {
              return Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No friends yet',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add friends to start chatting',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 5,
                left: 10,
                right: 10,
              ),
              itemCount: allUsers.length,
              itemBuilder: (context, index) {
                // Your existing itemBuilder code
                final userItem = allUsers[index];
                UserModel? userModel;
                FriendRequest? request;
                bool isFriend = false;
                bool isFriendRequest = false;

                if (userItem is UserModel) {
                  userModel = userItem;
                  isFriend = true;
                } else if (userItem is FriendRequest) {
                  request = userItem;
                  userModel = request.sender;
                  isFriendRequest = request.status == 'pending';
                }

                if (userModel == null) return const SizedBox.shrink();

                final chatSummary = chatController.userChats.firstWhereOrNull(
                  (chat) =>
                      chat.participants.contains(userModel!.uid) &&
                      chat.participants.contains(
                        chatController.currentUserId.value,
                      ),
                );

                String subtitleText;
                if (chatSummary != null) {
                  subtitleText = chatSummary.getChatSubtitle(
                    chatController.currentUserId.value,
                  );
                } else if (isFriendRequest) {
                  subtitleText = 'Friend request received';
                } else if (chatController.sentRequests.contains(
                  userModel.uid,
                )) {
                  subtitleText = 'Friend request sent';
                } else {
                  subtitleText = 'No messages yet';
                }

                final isHighlighted =
                    chatController.highlightedUserId.value == userModel.uid;

                return GlassContainer(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: userModel.photoUrl != null
                          ? NetworkImage(userModel.photoUrl!)
                          : null,
                      backgroundColor: Colors.grey[800],
                    ),
                    title: Text(
                      userModel.name,
                      style: TextStyle(
                        color: isHighlighted
                            ? Colors.greenAccent
                            : Colors.white,
                        fontWeight: isHighlighted
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      subtitleText,
                      style: TextStyle(
                        color: isFriendRequest ? Colors.orange : Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                        (chatSummary != null &&
                            chatSummary.hasUnreadMessages(
                              chatController.currentUserId.value,
                            ))
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.redAccent,
                            child: Text(
                              chatSummary
                                  .getUnreadCount(
                                    chatController.currentUserId.value,
                                  )
                                  .toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : chatController.sentRequests.contains(userModel.uid)
                        ? const Icon(Icons.hourglass_top, color: Colors.orange)
                        : isFriendRequest
                        ? const Icon(Icons.person_add, color: Colors.blue)
                        : null,
                    onTap: () {
                      if (userItem is FriendRequest &&
                          userItem.sender != null) {
                        print('Friend request tapped');
                        _showFriendRequestDialog(context, userItem);
                      } else if (userItem is UserModel) {
                        print('Friend tapped, open chat');
                        Get.to(() => ChatScreen(peerUser: userItem));
                      }
                    },
                  ),
                );
              },
            );
          }),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final currentUserId = controller.currentUser.value?.uid ?? '';
          showAddFriendDialog(context, currentUserId);
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.person_add, color: Colors.blueAccent),
      ),
    );
  }
}
