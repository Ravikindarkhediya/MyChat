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
import '../models/user_model.dart';
import '../widgets/add_friend_dialog.dart';
import 'chat_screen.dart';

class HomePage extends StatelessWidget {
  final HomeController controller = Get.put(HomeController());
  late final ChatController chatController;
  final UserService userService = UserService();
  final user = FirebaseAuth.instance.currentUser;

  HomePage({super.key}) {
      chatController = Get.put(
        ChatController(userId: user?.uid ?? ''),
      );
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
          child: StreamBuilder<List<UserModel>>(
            stream: userService.getUsers(excludeUserId: user!.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Empty friend list',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final users = snapshot.data!;
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userItem = users[index];

                  return Obx(() {
                    final chatSummary = chatController.userChats.firstWhereOrNull(
                          (chat) =>
                      chat.participants.contains(userItem.uid) &&
                          chat.participants.contains(chatController.currentUserId.value),
                    );

                    final subtitleText = chatSummary != null
                        ? chatSummary.getChatSubtitle(chatController.currentUserId.value)
                        : chatController.sentRequests.contains(userItem.uid)
                        ? 'Friend request sent'
                        : 'No messages yet';

                    final isHighlighted =
                        chatController.highlightedUserId.value == userItem.uid;

                    return GlassContainer(
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userItem.photoUrl != null
                              ? NetworkImage(userItem.photoUrl!)
                              : null,
                          backgroundColor: Colors.grey[800],
                        ),
                        title: Text(
                          userItem.name,
                          style: TextStyle(
                            color: isHighlighted ? Colors.greenAccent : Colors.white,
                            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          subtitleText,
                          style: const TextStyle(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: (chatSummary != null &&
                            chatSummary.hasUnreadMessages(chatController.currentUserId.value))
                            ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.redAccent,
                          child: Text(
                            chatSummary
                                .getUnreadCount(chatController.currentUserId.value)
                                .toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        )
                            : chatController.sentRequests.contains(userItem.uid)
                            ? const Icon(Icons.hourglass_top, color: Colors.orange)
                            : null,
                        onTap: () {
                          Get.to(() => ChatScreen(peerUser: userItem));
                        },
                      ),
                    );
                  });


                },
              );
            },
          ),
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
