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
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: GlassContainer(
            width: Get.width * 0.85,
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            opacity: 0.2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.3),
                            Colors.purple.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Text(
                        '🤝 Friend Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Profile Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      // Profile Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: request.sender.photoUrl?.isNotEmpty == true
                              ? FadeInImage.assetNetwork(
                            placeholder: 'assets/images/default_avatar.png',
                            image: request.sender.photoUrl!,
                            fit: BoxFit.cover,
                            imageErrorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.7),
                                    Colors.purple.withOpacity(0.7),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          )
                              : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.7),
                                  Colors.purple.withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // User Name
                      Text(
                        request.sender.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      // User Email
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          request.sender.email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    '${request.sender.name} wants to be your friend. Accept this request to start chatting!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    // Reject Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          chatController.rejectFriendRequest(request.id);
                          Get.back();
                          Get.snackbar(
                            'Rejected',
                            'Friend request rejected',
                            backgroundColor: Colors.red.withOpacity(0.8),
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM,
                            margin: const EdgeInsets.all(16),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.6),
                                Colors.red.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Reject',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Accept Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          chatController.acceptFriendRequest(request.id, request.senderId);
                          Get.back();
                          Get.snackbar(
                            'Accepted! 🎉',
                            'You are now friends with ${request.sender.name}',
                            backgroundColor: Colors.green.withOpacity(0.8),
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM,
                            margin: const EdgeInsets.all(16),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.6),
                                Colors.green.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Accept',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
