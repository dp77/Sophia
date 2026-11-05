import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/core/haptics.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/premium_screen.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/view_model/watch_earn_status.dart';
import 'package:provider/provider.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../../../data/ad_service/cascading_ad_manager.dart';
import '../../widget/pro_card.dart';

// Watch & Earn — design "A3 · Wallet + ticket".
// Logic mirrors the existing Watch & Earn flow in settings_tab.dart.

const _pink = Color(0xFFD99A98);
const _gold = Color(0xFFC9A55C);
const _goldLight = Color(0xFFF7EBC6);
const _goldMid = Color(0xFFE6CF97);
const _ink = Color(0xFF1F1311);
const _muted = Color(0xFF9C8870);
const _soft = Color(0xFFEBD9C4);
const _sans = 'PlusJakartaSans';
const _serif = 'PlayfairDisplay';
const _ease = Cubic(0.2, 0.8, 0.2, 1);

/// Credits Pro includes (see ProCard / PremiumScreen copy).
const _proCredits = 4000;

/// Credits one rewarded ad gives, from the backend's `credits_per_watch`
/// (null until the status call returns).
int? _creditsPerAd(BuildContext context) =>
    context.watch<WatchEarnStatusProvider>().creditsPerWatch;


double _prog(double t, double delay, double dur, [Curve curve = _ease]) =>
    curve.transform(((t - delay) / dur).clamp(0.0, 1.0));

double _wave(double t, double period) =>
    (1 - math.cos(2 * math.pi * t / period)) / 2;

class WatchEarnScreen extends StatefulWidget {
  const WatchEarnScreen({super.key});

  @override
  State<WatchEarnScreen> createState() => _WatchEarnScreenState();
}

class _WatchEarnScreenState extends State<WatchEarnScreen>
    with SingleTickerProviderStateMixin {
  bool _isWatchAndEarnInProgress = false;
  int? _remainingToday; // null while loading

  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'WatchEarnScreen',
      innerScreenName: 'RewardedAd',
      context: 'monetization',
    );
    _ticker = createTicker(
      (elapsed) => _clock.value = elapsed.inMicroseconds / 1e6,
    )..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRemaining());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

  Future<int?> _fetchRemaining() {
    final watchEarnStatus = Provider.of<WatchEarnStatusProvider>(
      context,
      listen: false,
    );
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return watchEarnStatus.watchAndEarnStatus(userProvider.id);
  }

  Future<void> _refreshRemaining() async {
    final remaining = await _fetchRemaining();
    if (!mounted) return;
    setState(() => _remainingToday = remaining ?? 0);
  }

  void _openPremium() =>
      NavigationService.navigateToScreenFromBottom(context, PremiumScreen());

  Future<void> _onWatch() async {
    if (_isWatchAndEarnInProgress) return;
    AnalyticsService.instance.event(
      'rewarded_ad_started',
      screenName: 'WatchEarnScreen',
      innerScreenName: 'RewardedAd',
      context: 'monetization',
    );
    setState(() => _isWatchAndEarnInProgress = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final remainingToday = await _fetchRemaining();
    if (!mounted) return;

    if (remainingToday == null || remainingToday <= 0) {
      SophiaToast.show(msg: 'Your daily limit has been reached');
      setState(() {
        _isWatchAndEarnInProgress = false;
        _remainingToday = 0;
      });
      _openPremium();
      return;
    }

    final bool isConnected = await InternetConnection().hasInternetAccess;
    if (!mounted) return;
    if (!isConnected) {
      SophiaToast.show(msg: 'No internet connection.');
      setState(() => _isWatchAndEarnInProgress = false);
      return;
    }

    SophiaToast.show(msg: 'Loading...');
    try {
      await CascadingAdManager.showAd(
        context,
        onAdClosed: () async {
          final success = await userProvider.watchAndEarn();
          if (!mounted) return;
          SophiaToast.show(
            msg: success
                ? 'Credits earned successfully!'
                : 'Failed to earn credits',
          );
          setState(() => _isWatchAndEarnInProgress = false);
          _refreshRemaining();
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isWatchAndEarnInProgress = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<UserProvider>().credits;
    final remaining = _remainingToday;
    final limitReached = remaining != null && remaining <= 0;

    final String leftText;
    if (remaining == null) {
      leftText = 'Checking today’s ads…';
    } else if (remaining <= 0) {
      leftText = 'No ads left today';
    } else {
      leftText = '$remaining ${remaining == 1 ? 'ad' : 'ads'} left today';
    }

    return Scaffold(
      backgroundColor: darkBlue,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: bgGradient),
        child: ValueListenableBuilder<double>(
          valueListenable: _clock,
          builder: (context, clock, _) {
            final t = _reduceMotion ? 100.0 : clock;
            return SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Up(t: t, delay: 0, child: _header()),
                    const SizedBox(height: 16),
                    _WalletCard(t: t, credits: credits),
                    const SizedBox(height: 22),
                    _Up(
                      t: t,
                      delay: 0.3,
                      child: _Wiggle(
                        t: t,
                        child: _RewardTicket(
                          t: t,
                          leftText: leftText,
                          onTap: _onWatch,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Up(
                      t: t,
                      delay: 0.45,
                      child: _WatchButton(
                        t: t,
                        loading: _isWatchAndEarnInProgress,
                        limitReached: limitReached,
                        onTap: _onWatch,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Up(
                      t: t,
                      delay: 0.8,
                      child: ProCard(t: t, onTap: _openPremium),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    final shape = CircleBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    );
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Back',
          child: Material(
            color: Colors.white.withValues(alpha: 0.06),
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: Haptics.wrap(() => Navigator.maybePop(context)),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: SvgIcon('ic_back', color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: _sans,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            children: [
              TextSpan(text: 'Watch '),
              TextSpan(
                text: '&',
                style: TextStyle(
                  fontFamily: _serif,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: _pink,
                ),
              ),
              TextSpan(text: ' Earn'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Wallet card ──────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.t, required this.credits});
  final double t;
  final int credits;

  @override
  Widget build(BuildContext context) {
    // Tilt-in entrance, then a gentle float.
    final p = _prog(t, 0.1, 0.9);
    final floatY = -6 * _wave(t, 5);
    // Light sweep: waits for 60% of a 4.5s loop, then crosses the card.
    final sweepPhase = t < 1 ? 0.0 : ((t - 1) % 4.5) / 4.5;
    final sweepK = sweepPhase < 0.6
        ? 0.0
        : Curves.easeInOut.transform((sweepPhase - 0.6) / 0.4);

    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 30 * (1 - p) + floatY),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.00125)
            ..rotateX(18 * math.pi / 180 * (1 - p)),
          child: Container(
            height: 176,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8C2F3C), Color(0xFFB4505C), _pink],
                stops: [0, 0.55, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: violet.withValues(alpha: 0.45),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    // Decorative rings
                    Positioned(top: -60, right: -40, child: _ring(0.22)),
                    Positioned(top: -20, right: -80, child: _ring(0.15)),
                    // Sweep
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: -160 + (c.maxWidth + 320) * sweepK,
                      child: Transform(
                        transform: Matrix4.skewX(-0.35),
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.3),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/logo.webp',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Sophia',
                                style: TextStyle(
                                  fontFamily: _serif,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'CREDIT WALLET',
                                style: TextStyle(
                                  fontFamily: _sans,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 450,
                                      ),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(
                                            scale: Tween(begin: 0.7, end: 1.0)
                                                .animate(
                                                  CurvedAnimation(
                                                    parent: anim,
                                                    curve: Curves.easeOutBack,
                                                  ),
                                                ),
                                            child: FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                          ),
                                      child: Text(
                                        '$credits',
                                        key: ValueKey(credits),
                                        style: const TextStyle(
                                          fontFamily: _sans,
                                          fontSize: 48,
                                          height: 1,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'credits · about $credits messages',
                                      style: TextStyle(
                                        fontFamily: _sans,
                                        fontSize: 13,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [_gold, _goldLight, _gold],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _ink.withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: _ink,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(double alpha) => Container(
    width: 180,
    height: 180,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: alpha)),
    ),
  );
}

// ── Reward ticket ────────────────────────────────────────────────────────────

const _stubWidth = 112.0;

class _RewardTicket extends StatelessWidget {
  const _RewardTicket({
    required this.t,
    required this.leftText,
    required this.onTap,
  });
  final double t;
  final String leftText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ping = (t % 1.6) / 1.6;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
      height: 108,
      child: ClipPath(
        clipper: _TicketClipper(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gold stub
            Container(
              width: _stubWidth,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, _goldLight, _gold],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+${_creditsPerAd(context) ?? '–'}',
                    style: const TextStyle(
                      fontFamily: _sans,
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CREDITS',
                    style: TextStyle(
                      fontFamily: _sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            // Dashed tear line
            CustomPaint(
              size: const Size(2, double.infinity),
              painter: _DashPainter(),
            ),
            // Body
            Expanded(
              child: Container(
                color: Colors.white.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Watch a short ad',
                            style: TextStyle(
                              fontFamily: _sans,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            leftText,
                            style: TextStyle(
                              fontFamily: _sans,
                              fontSize: 12,
                              color: gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Rounded ticket with two half-circle notches at the tear line.
class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 9.0;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      );
    final notches = Path()
      ..addOval(
        Rect.fromCircle(center: const Offset(_stubWidth + 1, 0), radius: r),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(_stubWidth + 1, size.height), radius: r),
      );
    return Path.combine(PathOperation.difference, outline, notches);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    const dash = 5.0, gap = 4.0;
    var y = 12.0;
    while (y < size.height - 12) {
      canvas.drawLine(
        Offset(1, y),
        Offset(1, math.min(y + dash, size.height - 12)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small wiggle every 4 seconds (after the entrance).
class _Wiggle extends StatelessWidget {
  const _Wiggle({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    double deg = 0;
    if (t > 1.5) {
      final p = ((t - 1.5) % 4) / 4;
      if (p > 0.86 && p < 0.95) {
        final k = (p - 0.86) / 0.09; // 0..1
        deg = 2 * math.sin(k * 3 * math.pi) * (1 - k);
      }
    }
    return Transform.rotate(angle: deg * math.pi / 180, child: child);
  }
}

// ── Buttons ──────────────────────────────────────────────────────────────────

class _WatchButton extends StatelessWidget {
  const _WatchButton({
    required this.t,
    required this.loading,
    required this.limitReached,
    required this.onTap,
  });
  final double t;
  final bool loading, limitReached;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = _wave(t, 2.4);
    final perAd = _creditsPerAd(context);
    return Semantics(
      button: true,
      label: limitReached
          ? 'Daily limit reached'
          : perAd == null
          ? 'Watch ad and earn credits'
          : 'Watch ad and earn $perAd credits',
      child: GestureDetector(
        // When the limit is reached, the tap still runs the flow, which sends the user to Premium.
        onTap: Haptics.wrap(loading ? null : onTap),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: limitReached ? null : btnGradient,
            color: limitReached ? Colors.white.withValues(alpha: 0.12) : null,
            boxShadow: limitReached
                ? null
                : [
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
                : Text(
                    limitReached
                        ? 'Daily limit reached'
                        : perAd == null
                        ? 'Watch Ad · Earn credits'
                        : 'Watch Ad · Earn $perAd',
                    style: const TextStyle(
                      fontFamily: _sans,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Pro card (same as option A) ──────────────────────────────────────────────

// ── Entrance ─────────────────────────────────────────────────────────────────

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
