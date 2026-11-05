import 'dart:async';
import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:girlfriend/core/haptics.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';

import '../../../core/ads_code.dart';
import '../../../data/ad_service/ad_cooldown.dart';
import '../../../data/analytics/analytics_service.dart';
import '../../../data/remote_config_service.dart';
import '../../widget/banner_ad_widget.dart';

enum _ImageAction { share, save }

class ImageFullScreen extends StatefulWidget {
  final String imageUrl;

  const ImageFullScreen({super.key, required this.imageUrl});

  @override
  State<ImageFullScreen> createState() => ImageFullScreenState();
}

class ImageFullScreenState extends State<ImageFullScreen> {
  double _dragOffsetY = 0;

  /// Which button is busy (ad loading / downloading / saving), if any.
  _ImageAction? _busy;

  RewardedInterstitialAd? _ad;
  bool _adLoading = false;
  Completer<void>? _adReady;

  /// The image saved to a temp file once, then reused for share and save.
  File? _file;

  final GlobalKey _shareKey = GlobalKey();

  bool get _isPremium => context.read<UserProvider>().isPremiumUser;
  bool get _adsEnabled => RemoteConfigService().showImageRewardedAd;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'ImageFullScreen',
      innerScreenName: 'ImagePreview',
      context: 'content',
    );
    // Preload so the ad is usually ready by the time they tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isPremium && _adsEnabled) _loadAd();
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  // ── Rewarded interstitial ────────────────────────────────────────────────

  void _loadAd() {
    if (_ad != null || _adLoading) return;
    _adLoading = true;
    _adReady = Completer<void>();
    RewardedInterstitialAd.load(
      adUnitId: idRewardedInterstitialAd,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _adLoading = false;
          if (!mounted) {
            ad.dispose();
          } else {
            _ad = ad;
          }
          _adReady?.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            'ImageFullScreen: rewarded interstitial failed: ${error.message}',
          );
          _adLoading = false;
          _adReady?.complete();
        },
      ),
    );
  }

  /// Shows the ad. Returns true when the user may continue: they earned the
  /// reward, or no ad could be shown (we never block them on our ad failing).
  Future<bool> _showAdForReward() async {
    if (_isPremium || !_adsEnabled) return true;
    // An ad played less than 30 seconds ago (here or anywhere in the app): let them through.
    if (AdCooldown.isActive) return true;
    _loadAd();
    if (_ad == null) {
      try {
        await _adReady?.future.timeout(const Duration(seconds: 8));
      } on TimeoutException {
        return true;
      }
    }
    final ad = _ad;
    if (ad == null || !mounted) return true;
    _ad = null;

    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        AdCooldown.markAdShown();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        earned = true; // couldn't show: let them through
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    if (mounted) _loadAd(); // ready for the next tap
    return earned;
  }

  // ── Share / save ─────────────────────────────────────────────────────────

  Future<File> _imageFile() async {
    final cached = _file;
    if (cached != null && await cached.exists()) return cached;
    final res = await Dio().get<List<int>>(
      widget.imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final type = res.headers.value('content-type') ?? '';
    final path = Uri.tryParse(widget.imageUrl)?.path.toLowerCase() ?? '';
    final ext = type.contains('png') || path.endsWith('.png')
        ? 'png'
        : type.contains('webp') || path.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/sophia_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await file.writeAsBytes(res.data!, flush: true);
    return _file = file;
  }

  Future<void> _run(_ImageAction action) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      final allowed = await _showAdForReward();
      if (!mounted) return;
      if (!allowed) {
        SophiaToast.show(
          msg: action == _ImageAction.share
              ? 'Watch the full ad to share this photo'
              : 'Watch the full ad to save this photo',
          type: ToastType.info,
        );
        return;
      }
      final file = await _imageFile();
      if (!mounted) return;
      if (action == _ImageAction.share) {
        await _share(file);
      } else {
        await _save(file);
      }
    } catch (e) {
      debugPrint('ImageFullScreen: $action failed: $e');
      SophiaToast.show(
        msg: action == _ImageAction.share
            ? "Couldn't share the photo. Please try again."
            : "Couldn't save the photo. Please try again.",
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _share(File file) async {
    // iPad needs an anchor for the share sheet.
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
    );
  }

  Future<void> _save(File file) async {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        SophiaToast.show(
          msg: 'Allow photo access in Settings to save photos.',
          type: ToastType.info,
        );
        return;
      }
    }
    await Gal.putImage(file.path);
    Haptics.selection();
    SophiaToast.show(msg: 'Saved to your photos', type: ToastType.success);
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dragAbs = _dragOffsetY.abs();
    final opacityFactor = (1 - (dragAbs / 260)).clamp(0.25, 1.0);
    final chromeOpacity = (1 - dragAbs / 120).clamp(0.0, 1.0);
    final isPremium = context.select<UserProvider, bool>(
      (u) => u.isPremiumUser,
    );
    final showAdTag = !isPremium && _adsEnabled;
    final showBanner = !isPremium && RemoteConfigService().showImageBanner;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacityFactor),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _dragOffsetY += details.primaryDelta ?? 0;
                      });
                    },
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (_dragOffsetY.abs() > 120 || velocity.abs() > 900) {
                        Navigator.pop(context);
                        return;
                      }
                      setState(() {
                        _dragOffsetY = 0;
                      });
                    },
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, _dragOffsetY),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: CachedNetworkImage(
                            imageUrl: widget.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: Haptics.wrap(() {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    }),
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.all(10),
                      child: SvgIcon('ic_back', color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: chromeOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionPill(
                        key: _shareKey,
                        icon: Icons.ios_share_rounded,
                        label: 'Share',
                        showAdHint: showAdTag,
                        busy: _busy == _ImageAction.share,
                        enabled: _busy == null,
                        onTap: () => _run(_ImageAction.share),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionPill(
                        icon: Icons.download_rounded,
                        label: 'Save',
                        showAdHint: showAdTag,
                        busy: _busy == _ImageAction.save,
                        enabled: _busy == null,
                        filled: true,
                        onTap: () => _run(_ImageAction.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showBanner)
              Opacity(
                opacity: chromeOpacity,
                child: const BannerAdWidget(height: 50),
              ),
          ],
        ),
      ),
    );
  }
}

/// Glass (or amethyst, when [filled]) pill with an icon, a label and, for free
/// users, a tiny "AD" tag so the ad doesn't come as a surprise.
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showAdHint, busy, enabled, filled;
  final VoidCallback onTap;

  const _ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.showAdHint,
    required this.busy,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: showAdHint ? '$label photo, plays a short ad' : '$label photo',
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled || busy ? 1 : 0.5,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: filled ? SophiaColors.amethyst : null,
              color: filled ? null : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: filled ? 0.28 : 0.16),
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: SophiaColors.amethystMid.withValues(alpha: 0.7),
                        blurRadius: 22,
                        spreadRadius: -8,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showAdHint && !busy) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      decoration: BoxDecoration(
                        color: SophiaColors.champagne.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: SophiaColors.champagne.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'AD',
                        style: TextStyle(
                          color: SophiaColors.champagne,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
