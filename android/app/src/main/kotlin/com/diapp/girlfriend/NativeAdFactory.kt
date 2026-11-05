package com.diapp.girlfriend

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_layout, null) as NativeAdView

        with(nativeAdView) {
            mediaView = findViewById<MediaView>(R.id.ad_media)
            headlineView = findViewById<TextView>(R.id.ad_headline)
            bodyView = findViewById<TextView>(R.id.ad_body)
            callToActionView = findViewById<Button>(R.id.ad_call_to_action)
            iconView = findViewById<ImageView>(R.id.ad_app_icon)
        }

        (nativeAdView.headlineView as TextView).text = nativeAd.headline
        (nativeAdView.bodyView as TextView).text = nativeAd.body
        (nativeAdView.callToActionView as Button).text = nativeAd.callToAction

        nativeAd.icon?.let {
            (nativeAdView.iconView as ImageView).setImageDrawable(it.drawable)
            nativeAdView.iconView?.visibility = View.VISIBLE
        } ?: run {
            nativeAdView.iconView?.visibility = View.GONE
        }

        nativeAd.mediaContent?.let {
            nativeAdView.mediaView?.mediaContent = it
        }

        nativeAdView.setNativeAd(nativeAd)

        return nativeAdView
    }
}
