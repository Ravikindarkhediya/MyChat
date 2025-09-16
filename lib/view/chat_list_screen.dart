// import 'package:ads_demo/controller/home_controller.dart';
// import 'package:ads_demo/models/user_model.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import '../controller/chat_controller.dart';
// import '../widgets/chat_list_item.dart';
// import '../widgets/add_friend_dialog.dart';
// import 'chat_screen.dart';
//
// class ChatListScreen extends StatefulWidget {
//   const ChatListScreen({Key? key}) : super(key: key);
//
//   @override
//   _ChatListScreenState createState() => _ChatListScreenState();
// }
//
// class _ChatListScreenState extends State<ChatListScreen> {
//   final ChatController _chatController = Get.find<ChatController>();
//   final TextEditingController _searchController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final HomeController homeController = Get.find();
//   bool _isSearching = false;
//   List<UserModel> _searchResults = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }
//
//   Future<void> _loadData() async {
//     await _chatController.loadFriends();
//     // Load any other necessary data
//   }
//
//   void _onSearchChanged(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _isSearching = false;
//         _searchResults.clear();
//       });
//       return;
//     }
//
//     setState(() {
//       _isSearching = true;
//     });
//
//     // Search for users
//     final results = await _chatController.searchUsers(query);
//     setState(() {
//       // _searchResults = results;
//     });
//   }
//
//   void _startNewChat(UserModel user) {
//     Get.to(
//       () => ChatScreen(
//         peerUser: user,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: _buildAppBar(),
//       body: _buildBody(),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           final currentUserId = homeController.currentUser.value?.uid ?? '';
//           showAddFriendDialog(context, currentUserId);
//         },
//         backgroundColor: Colors.blueAccent,
//         child: const Icon(Icons.add_comment, color: Colors.white),
//       ),
//     );
//   }
//
//   AppBar _buildAppBar() {
//     return AppBar(
//       elevation: 0,
//       backgroundColor: Colors.transparent,
//       title: _isSearching
//           ? TextField(
//               controller: _searchController,
//               autofocus: true,
//               style: const TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 hintText: 'Search for users...',
//                 hintStyle: const TextStyle(color: Colors.white54),
//                 border: InputBorder.none,
//                 suffixIcon: IconButton(
//                   icon: const Icon(Icons.close, color: Colors.white54),
//                   onPressed: () {
//                     setState(() {
//                       _isSearching = false;
//                       _searchController.clear();
//                       _searchResults.clear();
//                     });
//                   },
//                 ),
//               ),
//               onChanged: _onSearchChanged,
//             )
//           : Text(
//               'Messages',
//               style: GoogleFonts.poppins(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//       actions: [
//         if (!_isSearching)
//           IconButton(
//             icon: const Icon(Icons.search, color: Colors.white),
//             onPressed: () {
//               setState(() {
//                 _isSearching = true;
//               });
//             },
//           ),
//         // Add more app bar actions here if needed
//       ],
//     );
//   }
//
//   Widget _buildBody() {
//     return Column(
//       children: [
//         // Status/Stories section
//         _buildStoriesSection(),
//
//         // Divider
//         Container(
//           height: 1,
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           color: Colors.grey[800],
//         ),
//
//         // Chats list
//         Expanded(
//           child: _isSearching && _searchController.text.isNotEmpty
//               ? _buildSearchResults()
//               : _buildChatsList(),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildStoriesSection() {
//     // This is a placeholder for the stories section
//     // You can implement stories similar to WhatsApp/Instagram
//     return SizedBox(
//       height: 100,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//         itemCount: 10, // Replace with actual story count
//         itemBuilder: (context, index) {
//           if (index == 0) {
//             // Add story button
//             return _buildAddStoryButton();
//           }
//
//           // User story
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8.0),
//             child: Column(
//               children: [
//                 // Story ring
//                 Container(
//                   padding: const EdgeInsets.all(2),
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(
//                       colors: [Colors.purple, Colors.orange],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                   ),
//                   child: Container(
//                     padding: const EdgeInsets.all(2),
//                     decoration: BoxDecoration(
//                       color: Theme.of(context).scaffoldBackgroundColor,
//                       shape: BoxShape.circle,
//                     ),
//                     child: CircleAvatar(
//                       radius: 30,
//                       backgroundColor: Colors.grey[800],
//                       backgroundImage: CachedNetworkImageProvider(
//                         'https://randomuser.me/api/portraits/${index % 2 == 0 ? 'men' : 'women'}/${index + 10}.jpg',
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   index == 0 ? 'You' : 'User ${index + 1}',
//                   style: const TextStyle(color: Colors.white, fontSize: 12),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildAddStoryButton() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8.0),
//       child: Column(
//         children: [
//           Stack(
//             alignment: Alignment.center,
//             children: [
//               // Outer circle with gradient
//               Container(
//                 width: 64,
//                 height: 64,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               // Plus icon
//               Container(
//                 width: 56,
//                 height: 56,
//                 decoration: BoxDecoration(
//                   color: Colors.grey[900],
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.add,
//                   color: Colors.white,
//                   size: 28,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//           const Text(
//             'My Story',
//             style: TextStyle(color: Colors.white, fontSize: 12),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildChatsList() {
//     return Obx(() {
//       if (_chatController.isLoading.value) {
//         return const Center(child: CircularProgressIndicator());
//       }
//
//       if (_chatController.friends.isEmpty) {
//         return _buildEmptyState();
//       }
//
//       return ListView.builder(
//         controller: _scrollController,
//         padding: const EdgeInsets.only(top: 8),
//         itemCount: _chatController.friends.length,
//         itemBuilder: (context, index) {
//           final friend = _chatController.friends[index];
//           return ChatListItem.fromUser(
//             user: friend,
//             unreadCount: 0, // You can implement unread count logic
//             onTap: () => _startNewChat(friend),
//             isOnline: friend.isOnline ?? false,
//           );
//         },
//       );
//     });
//   }
//
//   Widget _buildSearchResults() {
//     if (_searchController.text.isEmpty) {
//       return Container();
//     }
//
//     if (_searchResults.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.search_off,
//               size: 64,
//               color: Colors.grey[400],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'No users found',
//               style: TextStyle(
//                 color: Colors.grey[400],
//                 fontSize: 16,
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return ListView.builder(
//       itemCount: _searchResults.length,
//       itemBuilder: (context, index) {
//         final user = _searchResults[index];
//         return ListTile(
//           leading: CircleAvatar(
//             backgroundImage: user.photoUrl != null
//                 ? CachedNetworkImageProvider(user.photoUrl!)
//                 : null,
//             child: user.photoUrl == null
//                 ? Text(user.name, style: const TextStyle(color: Colors.white))
//                 : null,
//           ),
//           title: Text(
//             user.name,
//             style: const TextStyle(color: Colors.white),
//           ),
//           subtitle: Text(
//             user.email,
//             style: TextStyle(color: Colors.grey[400]),
//           ),
//           onTap: () {
//             _startNewChat(user);
//             setState(() {
//               _isSearching = false;
//               _searchController.clear();
//               _searchResults.clear();
//             });
//           },
//         );
//       },
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: 120,
//               height: 120,
//               decoration: BoxDecoration(
//                 color: Colors.grey[800],
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.chat_bubble_outline,
//                 size: 56,
//                 color: Colors.grey,
//               ),
//             ),
//             const SizedBox(height: 24),
//             Text(
//               'No Chats Yet',
//               style: GoogleFonts.poppins(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'Start a new conversation by tapping the + button',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.grey[400],
//                 fontSize: 16,
//               ),
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               onPressed: () {
//                 final currentUserId = homeController.currentUser.value?.uid ?? '';
//                 showAddFriendDialog(context, currentUserId);
//
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blueAccent,
//                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(25),
//                 ),
//               ),
//               child: const Text(
//                 'New Message',
//                 style: TextStyle(fontSize: 16, color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
// }
