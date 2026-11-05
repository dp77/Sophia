/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../data/iap_service/iap_service.dart';

class OneTimeOfferDialog extends StatefulWidget {
  const OneTimeOfferDialog({super.key});

  @override
  State<OneTimeOfferDialog> createState() => _OneTimeOfferDialogState();
}

class _OneTimeOfferDialogState extends State<OneTimeOfferDialog> {
  static const int _totalSeconds = 3599;
  late int _remainingSeconds;
  Timer? _timer;

  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;
    _startTimer();

    // Listen for purchase completions to close the dialog
    IapService.instance.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
          if (mounted) Navigator.of(context).pop();
        } else if (purchase.status == PurchaseStatus.error) {
          if (mounted) setState(() => _isPurchasing = false);
        }
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds < 0) {
          _remainingSeconds = _totalSeconds;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _minutes => ((_remainingSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  String get _seconds => (_remainingSeconds % 60).toString().padLeft(2, '0');

  Future<void> _onContinue() async {
    final iap = IapService.instance;
    final plan = iap.planInfo;

    if (plan == null) {
      // Products not loaded yet — dismiss and let user try again
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isPurchasing = true);

    // Use the intro offer if eligible, otherwise fall back to base plan
    final selectedPlanId = plan.hasIntroOffer ? kAndroidIntroOfferId : kProductId;

    await iap.buy(selectedPlanId: selectedPlanId);

    // _isPurchasing resets to false on error via purchaseStream listener above.
    // On success the dialog closes automatically via the same listener.
  }

  @override
  Widget build(BuildContext context) {
    final iap = IapService.instance;
    final plan = iap.planInfo;

    // Determine display prices
    // originalPrice  → always the full / regular price (left side)
    // offerPrice     → intro/discounted price when eligible, otherwise 40% off regular
    final String originalPrice = plan?.regularPrice ?? '\$72.0';
    final String offerPrice;
    if (plan != null && plan.hasIntroOffer && plan.introPrice.isNotEmpty) {
      offerPrice = plan.introPrice;
    } else if (plan != null) {
      // No intro offer from store — derive 40 % discount manually as fallback
      final raw = plan.regularPrice.replaceAll(RegExp(r'[^\d.]'), '');
      final num = double.tryParse(raw);
      if (num != null) {
        final discounted = (num * 0.6).toStringAsFixed(2);
        offerPrice = plan.regularPrice.replaceAll(RegExp(r'[\d.]+'), discounted);
      } else {
        offerPrice = plan.regularPrice;
      }
    } else {
      offerPrice = '\$60.0';
    }

    final bool isLoading = iap.isLoading;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          gradient: bgGradient,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: white.withValues(alpha: 0.25), width: 1),
        ),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    'One Time Offer',
                    style: TextStyle(color: white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '40% OFF',
                    style: TextStyle(color: extraLightViolet, fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Text('LIMITED TIME OFFER', style: TextStyle(color: lightViolet, fontSize: 10, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TimerBlock(value: _minutes),
                      _TimerSeparator(),
                      _TimerBlock(value: _seconds),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price Row
                  isLoading
                      ? _PriceLoadingPlaceholder()
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _PriceColumn(label: 'Original Price', price: originalPrice, isOffer: false),
                                  ),
                                  Container(width: 28, height: 28, color: Colors.transparent),
                                  Expanded(
                                    child: _PriceColumn(label: 'Offer Price', price: offerPrice, isOffer: true),
                                  ),
                                ],
                              ),
                              Container(height: 55, width: 1, color: white),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: darkBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: white.withValues(alpha: 0.3), width: 2),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    color: white.withValues(alpha: 0.8),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 18),

                  // Continue / Purchase button
                  GestureDetector(
                    onTap: _isPurchasing || isLoading ? null : _onContinue,
                    child: Container(
                      width: double.infinity,
                      height: 65,
                      decoration: BoxDecoration(gradient: btnGradient, borderRadius: BorderRadius.circular(20)),
                      child: Center(
                        child: _isPurchasing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Continue',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: white),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            GestureDetector(
              onTap: _isPurchasing ? null : () => Navigator.of(context).pop(),
              child: Container(
                width: 26,
                height: 26,
                margin: EdgeInsets.only(top: 10, right: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Center(child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.3), size: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Price Loading Placeholder ────────────────────────────────────────────────

class _PriceLoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
      ),
    );
  }
}

// ─── Timer Block ──────────────────────────────────────────────────────────────

class _TimerBlock extends StatelessWidget {
  final String value;
  const _TimerBlock({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF120B09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
      ),
    );
  }
}

class _TimerSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── Price Column ─────────────────────────────────────────────────────────────

class _PriceColumn extends StatelessWidget {
  final String label;
  final String price;
  final bool isOffer;

  const _PriceColumn({required this.label, required this.price, required this.isOffer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      color: Colors.white.withValues(alpha: 0.00),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          isOffer
              ? ShaderMask(
                  shaderCallback: (bounds) => btnGradient.createShader(bounds),
                  child: Text(
                    price,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                )
              : Text(
                  price,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white.withValues(alpha: 0.4),
                    decorationThickness: 1.5,
                  ),
                ),
          const SizedBox(height: 2),
          Text('per year', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10)),
        ],
      ),
    );
  }
}
*/
