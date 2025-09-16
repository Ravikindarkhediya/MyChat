import 'package:ads_demo/constant/common.dart';
import 'package:ads_demo/controller/chat_controller.dart';
import 'package:ads_demo/view/profile_screen.dart';
import 'package:ads_demo/widgets/glass.dart';
import 'package:animated_background/animated_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/home_controller.dart';
import '../widgets/add_friend_dialog.dart';
import 'chat_screen.dart';

class HomePage extends StatelessWidget {
  final HomeController controller = Get.put(HomeController());
  late final ChatController chatController;

  HomePage({super.key}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      chatController = Get.put(
        ChatController(userId: user.uid),
        permanent: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        title: Obx(() {
          final user = controller.currentUser.value;

          if (user == null || user.uid.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(user.photoUrl.toString()),
              ),
              const SizedBox(width: 10),
              Text(
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                user.name,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298), Colors.black],
          ),
        ),
        child: AnimatedBackground(
          vsync: controller.vsyncProvider,
          behaviour: Common().buildBehaviour(),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.users.isEmpty) {
              return const Center(
                child: Text(
                  'Empty friend list',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final users = controller.users;

            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                // Get peer user chat summary (1:1 chat)
                final chatSummary = chatController.userChats.firstWhereOrNull(
                  (chat) =>
                      chat.participants.contains(user.uid) &&
                      chat.participants.contains(
                        chatController.currentUserId.value,
                      ),
                );

                // Determine subtitle
                final subtitleText = chatSummary != null
                    ? chatSummary.getChatSubtitle(
                        chatController.currentUserId.value,
                      )
                    : 'No messages yet';

                return GlassCard(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      backgroundColor: Colors.grey[800],
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      subtitleText,
                      style: const TextStyle(color: Colors.white70),
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
                        : null,
                    onTap: () {
                      Get.to(() => ChatScreen(peerUser: user));
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
