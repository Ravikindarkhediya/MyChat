import 'dart:io';

class AdHelper{
  static String get bannerAdUnitId {
    if(Platform.isAndroid){
      return 'ca-app-pub-3940256099942544/6300978111';
    }else if(Platform.isIOS){
      return 'ca-app-pub-3342282178653412/8654768374';
    }else{
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get getInterstitialAdUnitId {
    if(Platform.isAndroid){
      return 'ca-app-pub-3342282178653412/2093816186';
    }else if(Platform.isIOS){
      return 'ca-app-pub-3342282178653412/8654768374';
    }else{
      throw UnsupportedError('Unsupported Platform');
    }
  }
}