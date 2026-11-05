package com.diapp.girlfriend

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class CustomNativeAdFactory(private val context: Context) : NativeAdFactory {

    companion object {
        private const val DEFAULT_BUTTON_BG_COLOR = 0xFFD9F45F.toInt()
        private const val DEFAULT_BUTTON_TEXT_COLOR = 0xFF000000.toInt()
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.custom_native_ad, null) as NativeAdView

        val buttonBgColor = (customOptions?.get("buttonBackgroundColor") as? Number)?.toInt()
            ?: DEFAULT_BUTTON_BG_COLOR
        val buttonTextColor = (customOptions?.get("buttonTextColor") as? Number)?.toInt()
            ?: DEFAULT_BUTTON_TEXT_COLOR
        val buttonPosition = (customOptions?.get("buttonPosition") as? String) ?: "top"

        android.util.Log.d("NativeAd", "Button position: $buttonPosition")

        val headlineView = nativeAdView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        nativeAdView.headlineView = headlineView

        val bodyView = nativeAdView.findViewById<TextView>(R.id.ad_body)
        if (nativeAd.body != null) {
            bodyView.text = nativeAd.body
            bodyView.visibility = View.VISIBLE
        } else {
            bodyView.visibility = View.GONE
        }
        nativeAdView.bodyView = bodyView

        val callToActionTop = nativeAdView.findViewById<Button>(R.id.ad_call_to_action_top)
        val callToActionBottom = nativeAdView.findViewById<Button>(R.id.ad_call_to_action_bottom)

        val callToActionView = if (buttonPosition == "top") callToActionTop else callToActionBottom
        val callToActionHide = if (buttonPosition == "top") callToActionBottom else callToActionTop

        callToActionHide.visibility = View.GONE

        if (nativeAd.callToAction != null) {
            callToActionView.text = nativeAd.callToAction
            callToActionView.visibility = View.VISIBLE

            val buttonBackground = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 26f * context.resources.displayMetrics.density
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

        val mediaView = nativeAdView.findViewById<MediaView>(R.id.ad_media)
        nativeAdView.mediaView = mediaView

        val mediaContent = nativeAd.mediaContent
        if (mediaContent != null) {
            mediaView.mediaContent = mediaContent
            android.util.Log.d("NativeAd", "Media has video: ${mediaContent.hasVideoContent()}")
            android.util.Log.d("NativeAd", "Media aspect ratio: ${mediaContent.aspectRatio}")
        }

        nativeAdView.setNativeAd(nativeAd)

        val adChoicesInfo = nativeAd.adChoicesInfo
        if (adChoicesInfo != null) {
            android.util.Log.d("NativeAd", "AdChoices available: ${adChoicesInfo.text}")
        } else {
            android.util.Log.d("NativeAd", "AdChoices info is null")
        }

        return nativeAdView
    }
}
