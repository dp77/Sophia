package com.diapp.girlfriend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "fullscreenNativeAd", NativeAdFactory(this)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "customNativeAd", CustomNativeAdFactory(this)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "customNativeAdSmall", CustomNativeAdFactorySmall(this)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "fullscreenNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "customNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "customNativeAdSmall")

        super.cleanUpFlutterEngine(flutterEngine)
    }
}
