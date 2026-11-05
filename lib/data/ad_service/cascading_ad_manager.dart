import 'dart:async';
import 'package:flutter/material.dart';
import 'package:girlfriend/data/remote_config_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ads_code.dart';
import 'ad_cooldown.dart';
import 'logo_ad_fallback_screen.dart';

/// Manages a cascading ad-serving logic with preloading for a better UX.
///
/// Flow: Rewarded Ad -> Rewarded Interstitial Ad -> Fullscreen Native Ad -> Logo Fallback
class CascadingAdManager {
  static String get rewardedAdUnitId => idRewardedAd;
  static String get rewardedInterstitialAdUnitId => idRewardedInterstitialAd;
  static String get nativeAdUnitId => idNativeAd;

  static RewardedAd? _rewardedAd;
  static RewardedInterstitialAd? _rewardedInterstitialAd;
  static bool _isRewardedLoading = false;
  static bool _isRewardedInterstitialLoading = false;

  static Future<void> preloadAds() async {
    _preloadRewardedAd();
  }

  static void _preloadRewardedAd() {
    if (!RemoteConfigService().showRewarded) return;
    if (_rewardedAd != null || _isRewardedLoading) return;
    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          Future.delayed(const Duration(seconds: 2), _preloadRewardedInterstitialAd);
        },
      ),
    );
  }

  static void _preloadRewardedInterstitialAd() {
    if (!RemoteConfigService().showRewarded) return;
    if (_rewardedInterstitialAd != null || _isRewardedInterstitialLoading) {
      return;
    }
    _isRewardedInterstitialLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedInterstitialAd = null;
          _isRewardedInterstitialLoading = false;
          debugPrint(
            "REWARD INTERSTITIAL FAILED: Code=${error.code}, Message=${error.message}, Domain=${error.domain}",
          );
        },
      ),
    );
  }

  /// Helper to trigger the restart of the ad loading cycle from the top.
  static void _restartAdLoadingCycle() {
    // Give the system time to release media codec resources
    Future.delayed(const Duration(seconds: 1), _preloadRewardedAd);
  }

  static Future<void> _waitForAnyRewardedAd({Duration timeout = const Duration(seconds: 15)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (_rewardedAd != null || _rewardedInterstitialAd != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  static Future<void> showAd(BuildContext context, {VoidCallback? onAdClosed}) async {
    if (!RemoteConfigService().showRewarded) {
      await _showNativeFallback(context, onAdClosed: onAdClosed);
      return;
    }
    if (_rewardedAd == null && _rewardedInterstitialAd == null) {
      _preloadRewardedAd();
      await _waitForAnyRewardedAd();
    }
    if (!context.mounted) return;
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          AdCooldown.markAdShown();
          onAdClosed?.call();
          _restartAdLoadingCycle();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint("REWARD ADS FAILED TO SHOW: Code=${error.code}, Message=${error.message}, Domain=${error.domain}");
          ad.dispose();
          _rewardedAd = null;
          // Ad failed to show, continue cascade
          _showRewardedInterstitialAd(context, onAdClosed: onAdClosed);
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          // Handle reward
        },
      );
      return;
    }
    await _showRewardedInterstitialAd(context, onAdClosed: onAdClosed);
  }

  static Future<void> _showRewardedInterstitialAd(BuildContext context, {VoidCallback? onAdClosed}) async {
    if (_rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedInterstitialAd = null;
          AdCooldown.markAdShown();
          onAdClosed?.call();
          _restartAdLoadingCycle();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint(
            "REWARD INTERSTITIAL FAILED TO SHOW: Code=${error.code}, Message=${error.message}, Domain=${error.domain}",
          );
          ad.dispose();
          _rewardedInterstitialAd = null;
          _showNativeFallback(context, onAdClosed: onAdClosed);
        },
      );
      _rewardedInterstitialAd!.show(onUserEarnedReward: (ad, reward) {});
      return;
    }
    await _showNativeFallback(context, onAdClosed: onAdClosed);
  }

  static Future<void> _showNativeFallback(BuildContext context, {VoidCallback? onAdClosed}) async {
    // bool nativeAdShown = await _showFullscreenNativeAd(
    //   context,
    //   () {
    //     onAdClosed?.call();
    //     _restartAdLoadingCycle();
    //   },
    // );
    // if (nativeAdShown) return;

    await _showLogoFallback(context, () {
      onAdClosed?.call();
      _restartAdLoadingCycle();
    });
  }

  // static Future<bool> _showFullscreenNativeAd(BuildContext context, VoidCallback? onAdClosed) async {
  //   final completer = Completer<bool>();
  //   bool adLoaded = false;
  //
  //   unawaited(
  //     FullscreenNativeAd.show(
  //       context,
  //       adUnitId: nativeAdUnitId,
  //       showCloseButton: false,
  //       autoCloseAfter: const Duration(seconds: 25),
  //       onAdClosed: () {
  //         if (!completer.isCompleted) {
  //           completer.complete(adLoaded);
  //         }
  //         if (adLoaded) {
  //           onAdClosed?.call();
  //         }
  //       },
  //     ).then((adLoadedSuccessfully) {
  //       adLoaded = adLoadedSuccessfully;
  //       if (!adLoadedSuccessfully) {
  //         if (!completer.isCompleted) {
  //           completer.complete(false);
  //         }
  //       }
  //     }),
  //   );
  //
  //   return completer.future;
  // }

  static Future<void> _showLogoFallback(BuildContext context, VoidCallback? onAdClosed) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => LogoAdFallbackScreen(onAdClosed: onAdClosed)));
  }
}
