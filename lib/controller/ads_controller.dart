import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsController extends GetxController {
  BannerAd? bannerAd;
  bool isBannerLoaded = false;
  int _retryCount = 0;
  static const int _maxRetry = 5;

  @override
  void onInit() {
    super.onInit();
    loadBanner();
  }

  void loadBanner() {
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3342282178653412/8107973460', // Updated
      size: AdSize.banner,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ Banner Loaded');
          isBannerLoaded = true;
          update();
          _retryCount = 0;
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Banner failed: ${error.code} - ${error.message}');
          ad.dispose();
          isBannerLoaded = false;
          update();

          if (_retryCount < _maxRetry) {
            _retryCount++;
            print('Retrying to load banner ($_retryCount)');
            loadBanner();
          }
        },
      ),
    )..load();
  }

  @override
  void onClose() {
    bannerAd?.dispose();
    super.onClose();
  }
}
