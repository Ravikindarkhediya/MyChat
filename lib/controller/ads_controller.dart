import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../helper/ad_helper.dart';

class AdsController extends GetxController {
  RxInt counter = 0.obs;

  BannerAd? bannerAd;
  InterstitialAd? interstitialAd;

  @override
  void onInit() {
    super.onInit();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  void _loadBannerAd() {
    BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          bannerAd = ad as BannerAd;
          update(); // Notify UI
        },
        onAdFailedToLoad: (ad, err) {
          print('Failed to load banner Ad: ${err.message}');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    ).load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.getInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {},
          );
          interstitialAd = ad;
          update(); // Notify UI
        },
        onAdFailedToLoad: (err) {
          print('Failed to load interstitial Ad: ${err.message}');
        },
      ),
    );
  }

  void showInterstitial() {
    interstitialAd?.show();
  }

  void incrementCounter() {
    counter.value++;
  }

  @override
  void onClose() {
    bannerAd?.dispose();
    interstitialAd?.dispose();
    super.onClose();
  }
}
