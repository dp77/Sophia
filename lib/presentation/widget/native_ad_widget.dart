import 'dart:io';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/data/remote_config_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ads_code.dart';
import '../../core/colors.dart';

/// Native ad template types for different use cases
enum NativeAdSize {
  /// Small template - compact, icon + text only (~90-100dp height)
  small,

  /// Medium template - includes media preview (~300-350dp height)
  medium,

  /// Custom template - uses platform-specific custom layout (Android only for now)
  custom,

  /// Custom small template - a custom layout with a small size
  custom_small,
}

/// Position of the CTA button (Install/Learn More) in native ads
enum NativeAdButtonPosition {
  /// Button at the top of the ad
  top,

  /// Button at the bottom of the ad
  bottom,
}

/// A widget that displays a native ad with proper lifecycle management.
/// Handles loading, displaying, and disposing of native ads efficiently.
class NativeAdWidget extends StatefulWidget {
  final String? adUnitId;
  final NativeAdSize adSize;
  final EdgeInsetsGeometry? margin;

  /// Position of the Install/CTA button (top or bottom)
  final NativeAdButtonPosition buttonPosition;

  const NativeAdWidget({
    super.key,
    this.adUnitId,
    this.adSize = NativeAdSize.custom_small, // Default to custom for better customization
    this.margin,
    this.buttonPosition = NativeAdButtonPosition.top, // Default to top
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  // Responsive heights based on template type
  double get _adHeight {
    switch (widget.adSize) {
      case NativeAdSize.small:
        return 100; // Compact height for small template
      case NativeAdSize.medium:
        return 350; // Proper height for medium template with media
      case NativeAdSize.custom:
        return 330; // Custom layout height (Install button + media + bottom info)
      case NativeAdSize.custom_small:
        return 90; // Custom small layout height
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!RemoteConfigService().showNative) {
      if (mounted) {
        setState(() {
          _isAdFailed = true;
        });
      }
      return;
    }

    final useCustomFactory =
        (widget.adSize == NativeAdSize.custom || widget.adSize == NativeAdSize.custom_small) && Platform.isAndroid;

    debugPrint(
      'NativeAdWidget: Loading ad with useCustomFactory=$useCustomFactory, platform=${Platform.operatingSystem}',
    );

    // Native ad options for media and video settings
    final nativeAdOptions = NativeAdOptions(
      mediaAspectRatio: MediaAspectRatio.portrait,
      videoOptions: VideoOptions(startMuted: true, customControlsRequested: false, clickToExpandRequested: false),
    );

    if (useCustomFactory) {
      // Use custom native ad factory (Android only)
      final factoryId = widget.adSize == NativeAdSize.custom ? 'customNativeAd' : 'customNativeAdSmall';
      debugPrint('NativeAdWidget: Using custom factory "$factoryId"');
      _nativeAd = NativeAd(
        adUnitId: widget.adUnitId ?? idNativeAd,
        request: const AdRequest(),
        factoryId: factoryId,
        // Must match the factory ID registered in MainActivity
        listener: _createAdListener(),
        nativeAdOptions: nativeAdOptions,
        // Pass custom options to the native factory
        customOptions: {
          'buttonBackgroundColor': violet,
          'buttonTextColor': white,
          'buttonPosition': widget.buttonPosition == NativeAdButtonPosition.top ? 'top' : 'bottom',
        },
      );
    } else {
      // Use default template style (iOS or when custom not requested)
      final templateType = widget.adSize == NativeAdSize.small ? TemplateType.small : TemplateType.medium;

      _nativeAd = NativeAd(
        adUnitId: widget.adUnitId ?? idNativeAd,
        request: const AdRequest(),
        listener: _createAdListener(),
        nativeAdOptions: nativeAdOptions,
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: templateType,
          mainBackgroundColor: darkPurple,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: white,
            backgroundColor: violet,
            style: NativeTemplateFontStyle.bold,
            size: 14,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: white,
            style: NativeTemplateFontStyle.bold,
            backgroundColor: darkPurple,
            size: 14,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: gray,
            style: NativeTemplateFontStyle.normal,
            backgroundColor: darkPurple,
            size: 12,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: gray,
            style: NativeTemplateFontStyle.normal,
            backgroundColor: darkPurple,
            size: 11,
          ),
        ),
      );
    }

    _nativeAd?.load();
  }

  NativeAdListener _createAdListener() {
    return NativeAdListener(
      onAdLoaded: (ad) {
        debugPrint('NativeAdWidget: ✅ Ad loaded successfully! adSize=${widget.adSize}');
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
            _isAdFailed = false;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('NativeAdWidget: ❌ Ad failed to load!');
        debugPrint('NativeAdWidget: Error code: ${error.code}');
        debugPrint('NativeAdWidget: Error message: ${error.message}');
        debugPrint('NativeAdWidget: Error domain: ${error.domain}');
        ad.dispose();
        if (mounted) {
          setState(() {
            _isAdFailed = true;
            _isAdLoaded = false;
            _nativeAd = null;
          });
        }
      },
      onAdClicked: (ad) {
        debugPrint('NativeAdWidget: Ad clicked');
      },
      onAdImpression: (ad) {
        debugPrint('NativeAdWidget: Ad impression recorded');
      },
      onAdClosed: (ad) {
        debugPrint('NativeAdWidget: Ad closed');
      },
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _nativeAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing if ad failed (or show debug info in debug mode)
    if (_isAdFailed) {
      // In debug mode, you can uncomment this to see failed ad placeholder:
      // return Container(
      //   height: 100,
      //   margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      //   color: Colors.red.withValues(alpha: 0.1),
      //   child: Center(child: Text('Ad failed to load', style: TextStyle(color: Colors.red))),
      // );
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: _isAdLoaded && _nativeAd != null
          ? ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: _adHeight,
                maxHeight: _adHeight, // Add some flexibility
              ),
              child: AdWidget(ad: _nativeAd!),
            )
          : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return Container(
      height: _adHeight,
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        border: Border.all(color: white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExpressiveLoadingIndicator(color: violet),
            const SizedBox(height: 12),
            Text('Ad is loading...', style: TextStyle(color: gray, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// A manager class to help with creating unique keys for native ads
/// This ensures ads are properly recreated when tabs change
class NativeAdManager {
  static int _adCounter = 0;

  /// Generates a unique key for a native ad widget
  /// Call this when you need to force a new ad to load
  static Key generateKey(int tabIndex, int adPosition) {
    return ValueKey('native_ad_${tabIndex}_${adPosition}_$_adCounter');
  }

  /// Increment counter to force all ads to reload
  static void invalidateAll() {
    _adCounter++;
  }
}
