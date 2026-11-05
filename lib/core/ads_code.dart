import 'dart:io';

import 'package:flutter/foundation.dart';

///Google Admob
String idBanner = kDebugMode
    ? "ca-app-pub-3940256099942544/9214589741"
    : Platform.isAndroid
    ? "ca-app-pub-7809814089977162/5727454766"
    : "ca-app-pub-7809814089977162/7560584640";
String idInterstitial = kDebugMode
    ? "ca-app-pub-3940256099942544/1033173712"
    : Platform.isAndroid
    ? "ca-app-pub-7809814089977162/8106206092"
    : "ca-app-pub-7809814089977162/1433385914";
String idSplashInterstitial = kDebugMode
    ? "ca-app-pub-3940256099942544/1033173712"
    : Platform.isAndroid
    ? "ca-app-pub-7809814089977162/3224098475"
    : "ca-app-pub-7809814089977162/2370181804";
/// App-open ad shown when the app returns from the background.
String idAppOpenAd = kDebugMode
    ? Platform.isAndroid
        ? "ca-app-pub-3940256099942544/9257395921"
        : "ca-app-pub-3940256099942544/5575463023"
    : Platform.isAndroid
        ? "ca-app-pub-7809814089977162/8219642735"
        : "ca-app-pub-7809814089977162/9003450832";
String idRewardedAd = kDebugMode
    ? 'ca-app-pub-3940256099942544/5224354917'
    : Platform.isAndroid
    ? "ca-app-pub-7809814089977162/2746467583"
    : "ca-app-pub-7809814089977162/4311604771";
String idRewardedInterstitialAd = kDebugMode
    ? 'ca-app-pub-3940256099942544/5354046379'
    : Platform.isAndroid
    ? "ca-app-pub-7809814089977162/5480042750"
    : "ca-app-pub-7809814089977162/9120304247";
String idNativeAd = kDebugMode
    ? 'ca-app-pub-3940256099942544/2247696110'
    : Platform.isAndroid
    ? "ca-app-pub-7809814089977162/6793124421"
    : "ca-app-pub-7809814089977162/7807222579";
