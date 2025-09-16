// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
//
// import '../controller/home_controller.dart';
//
// class AdsPage extends StatelessWidget {
//   final String title;
//   AdsPage({super.key, required this.title});
//
//   final HomeController controller = Get.put(HomeController());
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(title),
//       ),
//       body: Stack(
//         children: [
//           // Banner Ad
//           GetBuilder<HomeController>(
//             builder: (_) {
//               if (controller.bannerAd != null) {
//                 return Align(
//                   alignment: Alignment.topCenter,
//                   child: SizedBox(
//                     width: controller.bannerAd!.size.width.toDouble(),
//                     height: controller.bannerAd!.size.height.toDouble(),
//                     child: AdWidget(ad: controller.bannerAd!),
//                   ),
//                 );
//               }
//               return const SizedBox.shrink();
//             },
//           ),
//
//           // Example counter display
//           Center(
//             child: Obx(() => Text(
//               'Counter: ${controller.counter.value}',
//               style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             )),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           controller.incrementCounter();
//           controller.showInterstitial();
//         },
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
