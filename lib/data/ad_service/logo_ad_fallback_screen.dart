import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../presentation/widget/banner_ad_widget.dart';

class LogoAdFallbackScreen extends StatefulWidget {
  final VoidCallback? onAdClosed;
  const LogoAdFallbackScreen({super.key, this.onAdClosed});

  @override
  State<LogoAdFallbackScreen> createState() => _LogoAdFallbackScreenState();
}

class _LogoAdFallbackScreenState extends State<LogoAdFallbackScreen> {
  Timer? _countdownTimer;

  late final int _totalSeconds;
  int _countdown = 0;
  bool _showClose = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = kDebugMode ? 5 : 30;
    _countdown = _totalSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        if (kDebugMode) {
          _closeScreen();
        } else {
          setState(() => _showClose = true);
        }
      }
    });
  }

  double get _progress {
    if (_totalSeconds <= 0) return 1;
    final elapsed = _totalSeconds - _countdown;
    return (elapsed / _totalSeconds).clamp(0.0, 1.0);
  }

  void _closeScreen() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      widget.onAdClosed?.call();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  static final promoItems = <PromoItem>[
    PromoItem(asset: 'assets/images/rewardVpn.webp', link: 'https://onelink.to/jdu5sx', weight: 10),
    PromoItem(asset: 'assets/images/rewardUdhaar.webp', link: 'https://onelink.to/6cq6bj', weight: 7),
    PromoItem(asset: 'assets/images/rewardFf.webp', link: 'https://onelink.to/h28rxr', weight: 5),
    PromoItem(asset: 'assets/images/rewardBm.webp', link: 'https://www.thebattlemania.com/', weight: 2),
  ];

  static PromoItem? _cachedPromoItem;
  static DateTime? _lastPromoItemTime;

  static PromoItem _getWeightedPromoItem() {
    final now = DateTime.now();
    if (_cachedPromoItem != null && _lastPromoItemTime != null) {
      final timeDifference = now.difference(_lastPromoItemTime!);
      if (timeDifference.inSeconds < 30) {
        return _cachedPromoItem!;
      }
    }

    _cachedPromoItem = PromoItem.selectWeighted(promoItems);
    _lastPromoItemTime = now;
    return _cachedPromoItem!;
  }

  @override
  Widget build(BuildContext context) {
    final promoItem = _getWeightedPromoItem();
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 6,
                      color: Colors.white.withValues(alpha: 0.16),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progress,
                        child: Container(color: Colors.white.withValues(alpha: 0.95)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: InkWell(
                onTap: () {
                  launchUrl(Uri.parse(promoItem.link));
                },
                child: Image.asset(promoItem.asset, fit: BoxFit.cover),
              ),
            ),
            if (_showClose)
              Positioned(
                top: 32,
                left: 16,
                child: SafeArea(
                  child: InkWell(
                    onTap: _closeScreen,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: const BannerAdWidget(collapsibleType: "bottom"),
      ),
    );
  }
}

class PromoItem {
  final String asset;
  final String link;
  final int weight;

  PromoItem({required this.asset, required this.link, required this.weight});

  static PromoItem selectWeighted(List<PromoItem> items) {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }

    final totalWeight = items.fold<int>(0, (sum, item) => sum + item.weight);

    final random = Random().nextInt(totalWeight);

    int cumulativeWeight = 0;
    for (final item in items) {
      cumulativeWeight += item.weight;
      if (random < cumulativeWeight) {
        return item;
      }
    }

    return items.last;
  }
}
