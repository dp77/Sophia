/*
import 'dart:async';
import 'dart:io';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/data/remote_config_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ads_code.dart';
import '../../core/colors.dart';

/// A full-screen native ad that can be shown as a dialog or screen.
class FullscreenNativeAd extends StatefulWidget {
  final String? adUnitId;
  final VoidCallback? onAdClosed;
  final VoidCallback? onAdClicked;
  final Function(bool)? onAdDisplayResult; // New callback
  final bool showCloseButton;
  final Duration? autoCloseAfter;

  const FullscreenNativeAd({
    super.key,
    this.adUnitId,
    this.onAdClosed,
    this.onAdClicked,
    this.onAdDisplayResult,
    this.showCloseButton = true,
    this.autoCloseAfter,
  });

  /// Show the fullscreen native ad as a dialog
  static Future<bool> show(
    BuildContext context, {
    String? adUnitId,
    VoidCallback? onAdClosed,
    VoidCallback? onAdClicked,
    bool showCloseButton = true,
    Duration? autoCloseAfter,
    bool barrierDismissible = false,
  }) async {
    final completer = Completer<bool>();
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierColor: Colors.black,
        builder: (context) => FullscreenNativeAd(
          adUnitId: adUnitId,
          onAdClosed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            onAdClosed?.call();
          },
          onAdClicked: onAdClicked,
          showCloseButton: showCloseButton,
          autoCloseAfter: autoCloseAfter,
          onAdDisplayResult: (bool success) {
            if (!completer.isCompleted) {
              completer.complete(success);
            }
          },
        ),
      ),
    );
    return completer.future;
  }

  @override
  State<FullscreenNativeAd> createState() => _FullscreenNativeAdState();
}

class _FullscreenNativeAdState extends State<FullscreenNativeAd>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;
  AnimationController? _controller;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAd();

    if (!widget.showCloseButton && widget.autoCloseAfter != null) {
      _controller = AnimationController(vsync: this, duration: widget.autoCloseAfter)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (mounted) {
              setState(() {
                _canClose = true;
              });
            }
          }
        });
      _controller?.forward();
    } else {
      _canClose = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_canClose && _controller != null && !_controller!.isAnimating) {
        _controller?.forward();
      }
    }
  }

  Future<void> _loadAd() async {
    if (!RemoteConfigService().showNative) {
      debugPrint('FullscreenNativeAd: Native ads disabled by remote config');
      widget.onAdDisplayResult?.call(false);
      _closeAd();
      return;
    }

    // Native ad options for portrait media and video settings
    // startMuted: false is required for sound, but might prevent autoplay depending on OS/network.
    final nativeAdOptions = NativeAdOptions(
      mediaAspectRatio: MediaAspectRatio.portrait,
      videoOptions: VideoOptions(
        startMuted: false, 
        customControlsRequested: true, 
        clickToExpandRequested: true
      ),
    );

    if (Platform.isAndroid) {
      _nativeAd = NativeAd(
        adUnitId: widget.adUnitId ?? idNativeAd,
        request: const AdRequest(),
        factoryId: 'fullscreenNativeAd',
        listener: _createAdListener(),
        nativeAdOptions: nativeAdOptions,
        customOptions: {'buttonBackgroundColor': lightViolet, 'buttonTextColor': Colors.black},
      );
    } else {
      // iOS - use default template
      _nativeAd = NativeAd(
        adUnitId: widget.adUnitId ?? idNativeAd,
        request: const AdRequest(),
        listener: _createAdListener(),
        nativeAdOptions: nativeAdOptions,
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: Colors.black,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: AppColors.backgroundColor,
            backgroundColor: AppColors.primary,
            style: NativeTemplateFontStyle.bold,
            size: 16,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            style: NativeTemplateFontStyle.bold,
            size: 16,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.grey[400],
            style: NativeTemplateFontStyle.normal,
            size: 14,
          ),
        ),
      );
    }

    try {
      await _nativeAd?.load();
    } catch (e) {
      debugPrint('FullscreenNativeAd: Error loading ad: $e');
      if (mounted) {
        setState(() {
          _isAdFailed = true;
          _isAdLoaded = false;
          _nativeAd = null;
        });
        widget.onAdDisplayResult?.call(false);
        _closeAd();
      }
    }
  }

  NativeAdListener _createAdListener() {
    return NativeAdListener(
      onAdLoaded: (ad) {
        debugPrint('FullscreenNativeAd: ✅ Ad loaded successfully!');
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
            _isAdFailed = false;
          });
          widget.onAdDisplayResult?.call(true);
        }
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('FullscreenNativeAd: ❌ Ad failed to load: ${error.message}');
        ad.dispose();
        if (mounted) {
          setState(() {
            _isAdFailed = true;
            _isAdLoaded = false;
            _nativeAd = null;
          });
          widget.onAdDisplayResult?.call(false);
          // Auto close on failure
          _closeAd();
        }
      },
      onAdClicked: (ad) {
        debugPrint('FullscreenNativeAd: Ad clicked');
        widget.onAdClicked?.call();
      },
      onAdImpression: (ad) {
        debugPrint('FullscreenNativeAd: Ad impression recorded');
      },
    );
  }

  void _closeAd() {
    widget.onAdClosed?.call();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: _isAdLoaded && _nativeAd != null
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: AdWidget(ad: _nativeAd!),
                      )
                    : _isAdFailed
                    ? _buildErrorState()
                    : _buildLoadingState(),
              ),

              // Close Button or Progress Bar
              if (_canClose)
                Positioned(top: 8, right: 8, child: _buildCloseButton())
              else if (_controller != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _controller!,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _controller!.value,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 4,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _closeAd,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExpressiveLoadingIndicator(color: AppColors.primary),
        const SizedBox(height: 16),
        Text('Loading...', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.white.withValues(alpha: 0.5), size: 48),
        const SizedBox(height: 16),
        Text('Ad not available', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
      ],
    );
  }
}
*/
