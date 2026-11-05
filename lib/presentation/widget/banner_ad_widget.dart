import 'package:flutter/material.dart';
import 'package:girlfriend/data/remote_config_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ads_code.dart';
import 'sophia_skeleton.dart';
import 'sophia_style.dart';

/// A widget that displays a banner ad.
///
/// This widget can display either a standard anchored adaptive banner ad or a
/// collapsible banner ad. To display a collapsible ad, provide a [collapsibleType].
///
/// While the ad loads it reserves the ad's real height and shows a shimmer, so
/// the content below doesn't jump when the ad arrives.
class BannerAdWidget extends StatefulWidget {
  /// The type of collapsible ad. Can be 'bottom' or 'top'.
  /// If null, a standard anchored adaptive banner is shown. The height of the
  /// adaptive banner is typically around 50-60dp on most phones.
  final String? collapsibleType;
  final double? height;

  const BannerAdWidget({super.key, this.collapsibleType, this.height});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  /// Real adaptive banner height from the last size lookup, reused so the
  /// next screen reserves the exact slot from its first frame.
  static double? _knownAdHeight;

  BannerAd? _bannerAd;

  /// Built once per ad and reused on every rebuild, so iOS never gets asked to
  /// create the same platform view twice ("recreating_view").
  Widget? _adView;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _hasInitialized = false;

  /// Height to reserve before the ad is in: the real one once known, else an
  /// estimate of Google's adaptive banner height for this screen width.
  double _slotHeight(BuildContext context) {
    if (_knownAdHeight != null) return _knownAdHeight!;
    final estimate = (MediaQuery.sizeOf(context).width / 6.4).clamp(50.0, 90.0).toDouble();
    return widget.height != null && widget.height! > estimate ? widget.height! : estimate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized && !_isAdLoaded && !_isAdLoading) {
      _hasInitialized = true;
      _loadAd();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    if (!mounted) return;

    if (!RemoteConfigService().showBanner) {
      debugPrint('BannerAdWidget: Banner ads disabled by remote config');
      return;
    }

    setState(() {
      _isAdLoading = true;
    });

    final screenWidth = MediaQuery.of(context).size.width;

    // Get the anchored adaptive banner size.
    final AdSize? adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(screenWidth.truncate());

    if (adSize == null) {
      debugPrint('Unable to get anchored adaptive banner size.');
      if (mounted) {
        setState(() {
          _isAdLoading = false;
        });
      }
      return;
    }

    // Reserve the real height right away, before the ad itself arrives.
    if (_knownAdHeight != adSize.height.toDouble()) {
      _knownAdHeight = adSize.height.toDouble();
      if (mounted) setState(() {});
    }

    // Determine the ad unit ID based on the platform.
    final String adUnitId = idBanner;

    // Create the ad request with extras if it's a collapsible ad.
    final adRequest = AdRequest(extras: widget.collapsibleType != null ? {'collapsible': widget.collapsibleType!} : {});

    BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: adRequest,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _adView = AdWidget(key: ObjectKey(ad), ad: ad);
              _isAdLoaded = true;
              _isAdLoading = false;
            });
          } else {
            ad.dispose();
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoading = false;
            });
          }
        },
      ),
    ).load();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_isAdLoaded && _bannerAd != null && _adView != null) {
      final ad = _bannerAd!;
      child = SizedBox(
        key: const ValueKey('ad'),
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: _adView,
          ),
        ),
      );
    } else if (_isAdLoading) {
      child = _AdPlaceholder(key: const ValueKey('loading'), height: _slotHeight(context));
    } else {
      // Ad disabled or failed: no slot.
      child = const SizedBox(key: ValueKey('none'), width: double.infinity);
    }
    // Only a failed ad changes the height; that collapse animates instead of jumping.
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Banner-shaped skeleton: icon, two text lines and a button, with the lilac sweep.
class _AdPlaceholder extends StatelessWidget {
  final double height;
  const _AdPlaceholder({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final box = (height - 16).clamp(24.0, 44.0).toDouble();
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(bottom: BorderSide(color: SophiaColors.lilac.withValues(alpha: 0.08))),
      ),
      child: SophiaShimmer(
        child: Row(
          children: [
            SkeletonBox(width: box, height: box, radius: 8, strength: 1.4),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(widthFactor: 0.7, child: SkeletonBox(height: 10, radius: 5, strength: 1.4)),
                  SizedBox(height: 6),
                  FractionallySizedBox(widthFactor: 0.45, child: SkeletonBox(height: 8, radius: 4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const SkeletonBox(width: 64, height: 28, radius: 14, strength: 1.4),
          ],
        ),
      ),
    );
  }
}
