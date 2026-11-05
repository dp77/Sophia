import 'dart:convert';
import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  int androidVersion = 1;
  int iosVersion = 1;

  bool showBanner = true;
  bool showAppOpen = true;
  bool showNative = true;
  bool showInterstitial = true;
  bool showRewarded = true;
  /// Splash interstitial shown once after splash initialization.
  bool showSplashInterstitialAd = true;

  /// Image viewer: rewarded interstitial before Share / Save, and its banner.
  bool showImageRewardedAd = true;
  bool showImageBanner = true;
  Map<String, dynamic> forceUpdate = {};

  Future<void> fetchRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(minutes: 1), minimumFetchInterval: Duration.zero),
    );
    // Splash and image ads are on unless switched off in the console.
    await remoteConfig.setDefaults(const {
      'showAppOpen': true,
      'iosShowAppOpen': true,
      'ShowSplashInterstitialAd': true,
      'IosShowSplashInterstitialAd': true,
      'showImageRewardedAd': true,
      'iosShowImageRewardedAd': true,
      'showImageBanner': true,
      'iosShowImageBanner': true,
    });
    await remoteConfig.fetchAndActivate();

    androidVersion = remoteConfig.getInt("android_version");
    iosVersion = remoteConfig.getInt("ios_version");

    showBanner = Platform.isAndroid ? remoteConfig.getBool("showBanner") : remoteConfig.getBool("iosShowBanner");
    showAppOpen = Platform.isAndroid ? remoteConfig.getBool("showAppOpen") : remoteConfig.getBool("iosShowAppOpen");
    showNative = Platform.isAndroid ? remoteConfig.getBool("showNative") : remoteConfig.getBool("iosShowNative");
    showInterstitial = Platform.isAndroid
        ? remoteConfig.getBool("showInterstitial")
        : remoteConfig.getBool("iosShowInterstitial");
    showRewarded = Platform.isAndroid ? remoteConfig.getBool("showRewarded") : remoteConfig.getBool("iosShowRewarded");
    showSplashInterstitialAd = Platform.isAndroid
        ? remoteConfig.getBool("ShowSplashInterstitialAd")
        : remoteConfig.getBool("IosShowSplashInterstitialAd");
    showImageRewardedAd = Platform.isAndroid
        ? remoteConfig.getBool("showImageRewardedAd")
        : remoteConfig.getBool("iosShowImageRewardedAd");
    showImageBanner = Platform.isAndroid
        ? remoteConfig.getBool("showImageBanner")
        : remoteConfig.getBool("iosShowImageBanner");
    final bannerJsonString = remoteConfig.getString("force_update");

    if (bannerJsonString.isNotEmpty) {
      forceUpdate = jsonDecode(bannerJsonString);
    }
  }
}
