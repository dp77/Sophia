package com.diapp.girlfriend

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class CustomNativeAdFactorySmall(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {

    companion object {
        private const val DEFAULT_BUTTON_BG_COLOR = 0xFFD9F45F.toInt()
        private const val DEFAULT_BUTTON_TEXT_COLOR = 0xFF000000.toInt()
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.custom_native_ad_small, null) as NativeAdView

        val buttonBgColor = (customOptions?.get("buttonBackgroundColor") as? Number)?.toInt()
            ?: DEFAULT_BUTTON_BG_COLOR
        val buttonTextColor = (customOptions?.get("buttonTextColor") as? Number)?.toInt()
            ?: DEFAULT_BUTTON_TEXT_COLOR

        val headlineView = nativeAdView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        nativeAdView.headlineView = headlineView

        val bodyView = nativeAdView.findViewById<TextView>(R.id.ad_body)
        if (nativeAd.body != null && nativeAd.body!!.isNotEmpty()) {
            bodyView.text = nativeAd.body
            bodyView.visibility = View.VISIBLE
        } else {
            bodyView.visibility = View.GONE
        }
        nativeAdView.bodyView = bodyView

        val callToActionView = nativeAdView.findViewById<Button>(R.id.ad_call_to_action)
        if (nativeAd.callToAction != null) {
            callToActionView.text = nativeAd.callToAction
            callToActionView.visibility = View.VISIBLE

            val buttonBackground = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 20f * context.resources.displayMetrics.density
                setColor(buttonBgColor)
            }
            callToActionView.background = buttonBackground
            callToActionView.setTextColor(buttonTextColor)
        } else {
            callToActionView.visibility = View.GONE
        }
        nativeAdView.callToActionView = callToActionView

        val iconView = nativeAdView.findViewById<ImageView>(R.id.ad_app_icon)
        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon?.drawable)
            iconView.visibility = View.VISIBLE
        } else {
            iconView.visibility = View.GONE
        }
        nativeAdView.iconView = iconView

        nativeAdView.setNativeAd(nativeAd)

        return nativeAdView
    }
}
