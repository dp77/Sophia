import 'package:girlfriend/core/haptics.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:girlfriend/presentation/widget/sophia_dialog.dart';
import 'package:grokbot_widget/grokbot_widget.dart';
import 'package:flutter/scheduler.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/core/app_config.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:girlfriend/data/api_service/api_caller.dart';
import 'package:girlfriend/presentation/widget/app_background.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
import 'package:girlfriend/data/iap_service/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import '../../view_model/user_provider.dart';
import '../../../data/url_launcher_service.dart';
import 'login_screen.dart';
// ── Design tokens (Option C · photo carousel) ────────────────────────────────

const _pink = Color(0xFFD99A98);
const _gold = Color(0xFFC9A55C);
const _online = Color(0xFF9BC48A);
const _muted = Color(0xFF9C8870);
const _heroFade = Color(0xFF160C0A);
const _sans = 'PlusJakartaSans';
const _serif = 'PlayfairDisplay';
const _ease = Cubic(0.2, 0.8, 0.2, 1);

/// Show both weekly and monthly subscription plans.
const _kShowMonthly = true;

const _heroPhotos = [
  'assets/images/onboard1.png',
  'assets/images/onboard2.png',
  'assets/images/onboard3.png',
];

/// One photo is on screen for 3s; the full loop of 3 photos is 9s.
const _cycleSeconds = 9.0;

/// Progress (0..1) of a one-shot animation that starts at [delay]s and lasts [dur]s.
double _prog(double t, double delay, double dur, [Curve curve = _ease]) =>
    curve.transform(((t - delay) / dur).clamp(0.0, 1.0));

/// Looping 0 → 1 → 0 ease-in-out wave.
double _wave(double t, double period) =>
    (1 - math.cos(2 * math.pi * t / period)) / 2;

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  bool _isMonthly = false;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _isPurchasing = false;
  bool _isVerifying = false; // one backend call at a time
  bool _isRestoring = false; // user tapped "Restore" on this screen

  // Animation clock (seconds since the screen opened).
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'PremiumScreen',
      innerScreenName: 'PlanSelection',
      context: 'monetization',
    );
    _purchaseSub = IapService.instance.purchaseStream.listen(_onPurchaseUpdate);
    _ticker = createTicker(
      (elapsed) => _clock.value = elapsed.inMicroseconds / 1e6,
    )..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ── Purchase handling ──────────────────────────────────────────────────────

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // The store sends one event per transaction (every renewal, every
    // restore), and on iOS they all carry the same app receipt. So pick ONE
    // and verify it once. IapService already finishes every transaction.
    PurchaseDetails? toVerify;
    for (final purchase in purchases) {
      if (!kAllProductIds.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
          toVerify = purchase;
          break;

        case PurchaseStatus.restored:
          // Restores also arrive on their own at app start; only act on them
          // when the user tapped Restore here.
          if (_isRestoring) toVerify ??= purchase;
          break;

        case PurchaseStatus.error:
          setState(() => _isPurchasing = false);
          _showResult(success: false, message: purchase.error?.message);
          break;

        case PurchaseStatus.canceled:
          setState(() => _isPurchasing = false);
          _showCancelled();
          break;

        case PurchaseStatus.pending:
          break;
      }
    }

    if (toVerify == null || _isVerifying) return;
    // Old transactions re-delivered while already premium: nothing to do.
    if (userProvider.isPremiumUser && !_isPurchasing && !_isRestoring) return;
    _handleSuccessfulPurchase(toVerify, userProvider);
  }

  ApiCaller apiCaller = ApiCaller();

  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchase,
    UserProvider userProvider,
  ) async {
    _isVerifying = true;
    try {
      final result = await apiCaller.purchasePremium(
        purchase.verificationData.localVerificationData,
        userProvider.id,
      );

      await result.fold(
        (failure) async {
          if (!mounted) return;
          setState(() => _isPurchasing = false);
          debugPrint('[IAP] Backend verification failed: $failure');

          String errorMessage = 'Verification failed';
          if (failure.toString().contains('network')) {
            errorMessage =
                'Network error. Please check your connection and try again.';
          } else if (failure.toString().contains('duplicate')) {
            errorMessage =
                'Purchase already processed. Please restart the app.';
          } else if (failure.toString().contains('invalid')) {
            errorMessage = 'Invalid purchase. Please contact support.';
          }

          SophiaToast.show(msg: errorMessage);
        },
        (response) async {
          if (!mounted) return;

          final data = response.data;
          if (data['status'] == true) {
            AnalyticsService.instance.event(
              'purchase_completed',
              screenName: 'PremiumScreen',
              innerScreenName: 'PlanSelection',
              context: 'monetization',
              parameters: {
                'plan': purchase.productID,
                'restored': _isRestoring,
              },
            );
            SophiaToast.show(
              msg: data['message'] ?? 'Premium activated successfully!',
            );
            // Update premium in place so every screen switches instantly
            // (no app restart). Restores can fire more than once; show the
            // success dialog only the first time.
            final wasPremium = userProvider.isPremiumUser;
            await userProvider.setPremium(true);
            // Pull the premium credits (purchase response has no credits).
            userProvider.refreshProfile();
            if (!mounted) return;
            setState(() => _isPurchasing = false);
            if (!wasPremium) _showResult(success: true);
          } else {
            setState(() => _isPurchasing = false);
            SophiaToast.show(
              msg: data['message'] ?? 'Purchase verification failed',
            );
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isPurchasing = false);
      debugPrint('[IAP] Exception during purchase handling: $e');
      SophiaToast.show(
        msg: 'An unexpected error occurred. Please try again.',
      );
    } finally {
      _isVerifying = false;
      _isRestoring = false;
    }
  }

  // ── Continue / Restore ─────────────────────────────────────────────────────

  bool _onContinueEnabled() {
    if (_isPurchasing) return false;
    if (_isMonthly) return IapService.instance.monthlyPlanInfo != null;
    return IapService.instance.weeklyPlanInfo != null;
  }

  Future<void> _onContinue() async {
    if (!_onContinueEnabled()) return;
    final plan = _isMonthly ? 'monthly' : 'weekly';
    AnalyticsService.instance.event(
      'purchase_started',
      screenName: 'PremiumScreen',
      innerScreenName: 'PlanSelection',
      context: 'monetization',
      parameters: {'plan': plan},
    );
    final userProvider = context.read<UserProvider>();
    if (!userProvider.isLoggedIn || userProvider.isAnonymous) {
      AnalyticsService.instance.event(
        'purchase_login_required',
        screenName: 'PremiumScreen',
        innerScreenName: 'LoginRequired',
        context: 'monetization',
        parameters: {'plan': plan},
      );
      SophiaToast.show(msg: 'Please sign in to continue with premium.');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _isPurchasing = true);
    try {
      if (_isMonthly) {
        await IapService.instance.buyMonthly();
      } else {
        await IapService.instance.buyWeekly();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      SophiaToast.show(msg: 'Purchase failed. Please try again.');
      debugPrint('[PremiumScreen] Continue error: $e');
    }
  }

  /// Restored purchases arrive on the same purchase stream and go through
  /// [_handleSuccessfulPurchase] for backend verification.
  Future<void> _onRestore() async {
    if (_isPurchasing) return;
    _isRestoring = true;
    try {
      await IapService.instance.restorePurchases();
      SophiaToast.show(msg: 'Checking your previous purchases…');
    } catch (e) {
      debugPrint('[PremiumScreen] Restore error: $e');
      SophiaToast.show(msg: 'Restore failed. Please try again.');
    }
  }

  // ── Dialogs / Snackbars ────────────────────────────────────────────────────

  void _showResult({required bool success, String? message}) {
    if (!mounted) return;
    if (success) {
      showSophiaDialog(
        context: context,
        dismissible: false,
        builder: (_) => SophiaDialog(
          tone: SophiaTone.gold,
          hero: const SophiaMascotHero(state: GrokBotState.celebrate, tone: SophiaTone.gold),
          title: "You're Premium!",
          message: 'Your purchase was successful.\nEnjoy all premium features!',
          actions: [
            SophiaGoldButton(
              label: 'Start Exploring',
              onTap: () {
                Navigator.of(context).pop();
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    } else {
      SophiaToast.show(
        msg: message != null ? 'Purchase failed: $message' : 'Purchase failed. Please try again.',
        type: ToastType.error,
      );
    }
  }

  void _showCancelled() {
    if (!mounted) return;
    SophiaToast.show(msg: 'Payment cancelled', type: ToastType.info);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ValueListenableBuilder<double>(
          valueListenable: _clock,
          builder: (context, clock, _) {
            final t = _reduceMotion ? 100.0 : clock;
            return LayoutBuilder(
              builder: (context, c) => Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: c.maxHeight * 0.57,
                    child: _HeroCarousel(t: t),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Up(t: t, delay: 0, child: _buildTopBar(t)),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              child: _buildContent(t),
                            ),
                          ),
                        ),
                        _buildFooterLinks(t),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(double t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _GlassButton(
            semanticLabel: 'Close',
            onTap: () => Navigator.maybePop(context),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
          ),
          const Spacer(),
          _GlassButton(
            onTap: _onRestore,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Restore',
                style: TextStyle(
                  fontFamily: _sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double t) {
    final weeklyPlan = IapService.instance.weeklyPlanInfo;
    final monthlyPlan = IapService.instance.monthlyPlanInfo;
    final showWeeklyOffer = weeklyPlan?.hasOffer ?? false;

    const benefits = [
      'Unlimited Chats',
      '4,000 Credits',
      'Feels More Personal',
      'No Ads',
      'Remembers You Over Time',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PopFloat(
          t: t,
          delay: 0.6,
          child: _WaitingChip(t: t),
        ),
        const SizedBox(height: 22),
        _Up(
          t: t,
          delay: 0.2,
          child: const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: _gold, size: 16),
              SizedBox(width: 8),
              Text(
                'SOPHIA PRO',
                style: TextStyle(
                  fontFamily: _sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Color(0xFFE6CF97),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Up(
          t: t,
          delay: 0.3,
          child: const Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: _sans,
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              children: [
                TextSpan(text: 'Unlimited '),
                TextSpan(
                  text: 'Full Access',
                  style: TextStyle(
                    fontFamily: _serif,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: _pink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Benefits — 2 columns, staggered entrance
        LayoutBuilder(
          builder: (context, c) {
            final itemWidth = (c.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < benefits.length; i++)
                  SizedBox(
                    width: itemWidth,
                    child: _Up(
                      t: t,
                      delay: 0.4 + i * 0.07,
                      child: _BenefitItem(text: benefits[i]),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _Up(
          t: t,
          delay: 0.7,
          child: _PlanCard(
            title: 'Weekly',
            badgeColor: _pink,
            badgeTextColor: darkPurple,
            price: showWeeklyOffer
                ? weeklyPlan!.offerPrice!
                : (weeklyPlan?.regularPrice ?? '\$--'),
            oldPrice: showWeeklyOffer ? weeklyPlan!.regularPrice : null,
            per: ' /wk',
            selected: !_isMonthly,
            onTap: weeklyPlan == null
                ? null
                : () => setState(() => _isMonthly = false),
          ),
        ),
        if (_kShowMonthly) ...[
          const SizedBox(height: 10),
          _Up(
            t: t,
            delay: 0.8,
            child: _PlanCard(
              title: 'Monthly',
              badge: null,
              badgeColor: lightViolet.withValues(alpha: 0.3),
              badgeTextColor: extraLightViolet,
              price: '₹299',
              per: ' /mo',
              selected: _isMonthly,
              onTap: monthlyPlan == null
                  ? null
                  : () => setState(() => _isMonthly = true),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _Up(
          t: t,
          delay: 0.9,
          child: _ContinueButton(
            t: t,
            loading: _isPurchasing,
            enabled: _onContinueEnabled(),
            onTap: _onContinue,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks(double t) {
    final period = _isMonthly ? 'Monthly' : 'Weekly';
    final linkStyle = TextStyle(
      fontFamily: _sans,
      color: extraLightViolet,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    return _Up(
      t: t,
      delay: 1.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Text(
              Platform.isAndroid
                  ? '$period Auto Renewable. Cancel anytime from Play Store.'
                  : '$period Auto Renewable. Cancel anytime from Apple ID settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: _sans, color: gray, fontSize: 10),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: Haptics.wrap(() async =>
                      UrlLauncherService.launch(AppConfig.privacyPolicyUrl)),
                  child: Text('Privacy Policy', style: linkStyle),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '|',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: Haptics.wrap(() async =>
                      UrlLauncherService.launch(AppConfig.termsOfServiceUrl)),
                  child: Text('Terms & Conditions', style: linkStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carousel timing ──────────────────────────────────────────────────────────

/// Phase 0..1 of photo [i] in the 9s loop. Photo 0 shows first, then 1, then 2.
double _photoPhase(double t, int i) {
  const offsets = [0.0, 6.0, 3.0];
  return ((t + offsets[i]) % _cycleSeconds) / _cycleSeconds;
}

/// Visible 0–33%, fades out 33–40%, hidden, fades back in 93–100%.
double _photoOpacity(double p) {
  if (p < 0.33) return 1;
  if (p < 0.40) return 1 - (p - 0.33) / 0.07;
  if (p < 0.93) return 0;
  return (p - 0.93) / 0.07;
}

/// Slow zoom-out while visible (1.12 → 1.0), reset while hidden.
double _photoScale(double p) {
  if (p < 0.40) return 1.12 - 0.12 * Curves.easeInOut.transform(p / 0.40);
  if (p < 0.93) return 1.0 + 0.12 * ((p - 0.40) / 0.53);
  return 1.12;
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < _heroPhotos.length; i++)
                Builder(
                  builder: (_) {
                    final p = _photoPhase(t, i);
                    final opacity = _photoOpacity(p);
                    if (opacity == 0) return const SizedBox.shrink();
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: _photoScale(p),
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          _heroPhotos[i],
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          gaplessPlayback: true,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        // Fade into the background
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.24, 0.52, 1],
              colors: [
                darkBlue.withValues(alpha: 0.65),
                darkBlue.withValues(alpha: 0),
                Colors.transparent,
                _heroFade,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: darkBlue.withValues(alpha: 0.1),
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: Haptics.wrap(onTap),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

class _WaitingChip extends StatelessWidget {
  const _WaitingChip({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final ping = (t % 1.6) / 1.6;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: darkPurple.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: extraLightViolet.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _online,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _online.withValues(alpha: 0.7 * (1 - ping)),
                  spreadRadius: 8 * Curves.easeOut.transform(ping),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Sophia is waiting for you',
            style: TextStyle(
              fontFamily: _sans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: violet.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 13, color: extraLightViolet),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: _sans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.price,
    required this.per,
    required this.selected,
    required this.onTap,
    this.oldPrice,
  });

  final String title, price, per;
  final String? badge, oldPrice;
  final Color badgeColor, badgeTextColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: Haptics.wrap(onTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? violet.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? lightViolet
                  : Colors.white.withValues(alpha: 0.12),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Radio
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? lightViolet
                        : Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 250),
                    scale: selected ? 1 : 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: lightViolet,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: _sans,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (badge != null) ...[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _sans,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (oldPrice != null)
                    Text(
                      oldPrice!,
                      style: const TextStyle(
                        fontFamily: _sans,
                        fontSize: 11,
                        color: _muted,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: _muted,
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      text: price,
                      style: const TextStyle(
                        fontFamily: _sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: per,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.t,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });
  final double t;
  final bool loading, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = _wave(t, 2.4);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Continue',
      child: GestureDetector(
        onTap: Haptics.wrap(enabled ? onTap : null),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled || loading ? 1 : 0.6,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(29),
              gradient: btnGradient,
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    violet.withValues(alpha: 0.5),
                    lightPink.withValues(alpha: 0.9),
                    k,
                  )!,
                  blurRadius: 30 + 16 * k,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(29),
              child: Shimmer(
                duration: const Duration(seconds: 3),
                color: Colors.white,
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Continue',
                              style: TextStyle(
                                fontFamily: _sans,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Transform.translate(
                              offset: Offset(4 * _wave(t, 1.6), 0),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Entrance animations ──────────────────────────────────────────────────────

/// Fade + slide up.
class _Up extends StatelessWidget {
  const _Up({required this.t, required this.delay, required this.child});
  final double t, delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = _prog(t, delay, 0.7);
    if (p >= 1) return child;
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, 24 * (1 - p)), child: child),
    );
  }
}

/// Pop in, then float up and down forever.
class _PopFloat extends StatelessWidget {
  const _PopFloat({required this.t, required this.delay, required this.child});
  final double t, delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = _prog(t, delay, 0.6);
    final floatT = t - delay - 0.6;
    final dy = 12 * (1 - p) - (floatT > 0 ? 8 * _wave(floatT, 4) : 0);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: 0.85 + 0.15 * p,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

// ── Kept: used by other screens (generate_tab, create_girlfriend_flow_screen) ─

class JumpingButtonWrapper extends StatefulWidget {
  final Widget child;

  const JumpingButtonWrapper({super.key, required this.child});

  @override
  _JumpingButtonWrapperState createState() => _JumpingButtonWrapperState();
}

class _JumpingButtonWrapperState extends State<JumpingButtonWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _animation = Tween(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(scale: _animation.value, child: child);
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
