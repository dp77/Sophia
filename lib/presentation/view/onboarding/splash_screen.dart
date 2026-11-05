import 'dart:async';
import 'dart:math' as math;

import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/ad_service/cascading_ad_manager.dart';
import '../../../data/ad_service/ad_cooldown.dart';
import '../../../data/analytics/analytics_service.dart';
import '../../../data/iap_service/iap_service.dart';
import '../../../data/navigation_service.dart';
import '../../../data/remote_config_service.dart';
import '../../../core/ads_code.dart';
import '../../view_model/auth_provider.dart';
import '../../view_model/chat_list_provider.dart';
import '../../view_model/user_provider.dart';
import '../home_screen.dart';
import 'onboarding_screen.dart';
// ── Palette (local, so this screen has no dependency on colors.dart) ─────────
const _pink = Color(0xffFF5FA2);
const _softPink = Color(0xffFF9CC8);
const _lavender = Color(0xffE9C8FF);
const _violet = Color(0xff8E3DFF);
const _bgTop = Color(0xff1B0733);
const _bgMid = Color(0xff12041F);
const _bgBottom = Color(0xff2C0B47);

/// Path of the picture shown in the tilted card. Change to your own asset.
const _cardImage = 'assets/images/logo.webp';
const _onboardingCompletedKey = 'onboarding_completed';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// One slow looping clock drives hearts, waves, rings and the float effect.
  /// Every motion uses an integer multiple of this clock, so the loop is seamless.
  late final AnimationController _loop;

  /// One-shot entrance animation.
  late final AnimationController _intro;

  late final List<_Heart> _hearts;
  bool _isCompletingOnboarding = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'SplashScreen',
      innerScreenName: 'Initializing',
      context: 'app_start',
    );
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _hearts = _generateHearts();
    _initAndNavigate();
  }

  List<_Heart> _generateHearts() {
    final rnd = math.Random(7);
    final list = <_Heart>[];

    // Big, blurred, outlined hearts drifting slowly (background depth)
    for (var i = 0; i < 5; i++) {
      list.add(
        _Heart(
          x: (i + 0.5) / 5 + (rnd.nextDouble() - 0.5) * 0.15,
          size: 110 + rnd.nextDouble() * 100,
          speed: 1,
          swayCycles: 1,
          phase: i / 5,
          amp: 18 + rnd.nextDouble() * 14,
          opacity: 0.10 + rnd.nextDouble() * 0.07,
          tilt: (rnd.nextDouble() - 0.5) * 0.5,
          big: true,
          hue: rnd.nextDouble(),
        ),
      );
    }

    // Small bright hearts floating up faster
    for (var i = 0; i < 16; i++) {
      list.add(
        _Heart(
          x: rnd.nextDouble(),
          size: 9 + rnd.nextDouble() * 20,
          speed: 2 + rnd.nextInt(2), // 2 or 3 passes per loop
          swayCycles: 2 + rnd.nextInt(3),
          phase: rnd.nextDouble(),
          amp: 8 + rnd.nextDouble() * 14,
          opacity: 0.45 + rnd.nextDouble() * 0.45,
          tilt: (rnd.nextDouble() - 0.5) * 0.7,
          big: false,
          hue: rnd.nextDouble(),
        ),
      );
    }
    return list;
  }

  // ── App startup logic (unchanged) ──────────────────────────────────────────

  Future<void> _initAndNavigate() async {
    await IapService.instance.init();
    await _fetchRemoteConfig();
    await CascadingAdManager.preloadAds();
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);
    final chatList = Provider.of<ChatListProvider>(context, listen: false);
    await auth.initializeAuth(userProvider: user, chatListProvider: chatList);
    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    await _showSplashInterstitial();
    if (!mounted) return;

    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final onboardingCompleted =
        preferences.getBool(_onboardingCompletedKey) ?? false;
    if (onboardingCompleted) {
      _navigateToHome();
    } else {
      NavigationService.navigateToScreenAndRemoveUntil(
        context,
        OnboardingScreen(onFinish: _completeOnboarding),
      );
    }
  }

  Future<void> _showSplashInterstitial() async {
    final remoteConfig = RemoteConfigService();
    if (!remoteConfig.showSplashInterstitialAd) return;

    final completed = Completer<void>();
    var adIsShowing = false;
    Timer? loadTimeout;

    void finish() {
      if (!completed.isCompleted) {
        loadTimeout?.cancel();
        completed.complete();
      }
    }

    loadTimeout = Timer(const Duration(seconds: 8), () {
      if (!adIsShowing) finish();
    });

    await InterstitialAd.load(
      adUnitId: idSplashInterstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted || completed.isCompleted) {
            ad.dispose();
            return;
          }
          adIsShowing = true;
          loadTimeout?.cancel();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              AdCooldown.markAdShown();
              finish();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Splash interstitial failed to show: $error');
              ad.dispose();
              finish();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Splash interstitial failed to load: $error');
          finish();
        },
      ),
    );

    await completed.future;
  }

  void _completeOnboarding() {
    if (_isCompletingOnboarding) return;
    _isCompletingOnboarding = true;
    _navigateToHome();
    unawaited(_markOnboardingCompleted());
  }

  Future<void> _markOnboardingCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompletedKey, true);
  }

  void _navigateToHome() {
    NavigationService.navigateToScreenAndRemoveUntilFromKey(const HomeScreen());
  }

  Future<void> _fetchRemoteConfig() async {
    try {
      await RemoteConfigService().fetchRemoteConfig();
    } catch (e) {
      debugPrint('Error fetching remote config: $e');
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _intro.dispose();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardSize = size.width * 0.66;

    final cardAnim = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    final textAnim = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    );
    final loaderAnim = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Gradient background
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bgTop, _bgMid, _bgBottom],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 2. Soft glow behind the card
          Positioned(
            top: size.height * 0.12,
            left: size.width * 0.5 - size.width * 0.5,
            width: size.width,
            height: size.width,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x442A0E5C), Color(0x00000000)],
                ),
              ),
            ),
          ),

          // 3. Hearts floating from bottom to top
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HeartsPainter(hearts: _hearts, clock: _loop),
              ),
            ),
          ),

          // 4. Animated waves at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.27,
            child: RepaintBoundary(
              child: CustomPaint(painter: _WavesPainter(clock: _loop)),
            ),
          ),

          // 5. Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                _buildCard(cardSize, cardAnim),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: textAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(textAnim),
                    child: _buildTitle(),
                  ),
                ),
                const Spacer(flex: 2),
                FadeTransition(opacity: loaderAnim, child: _buildLoader()),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(double s, Animation<double> anim) {
    return AnimatedBuilder(
      animation: Listenable.merge([anim, _loop]),
      builder: (context, _) {
        // Gentle floating (4s cycle)
        final bob = math.sin(_loop.value * 2 * math.pi * 6) * 6;
        final scale = 0.8 + 0.2 * anim.value;
        final opacity = anim.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, bob),
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: s + 60,
                height: s + 60,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // back glass layers
                    Transform.rotate(
                      angle: -0.2,
                      child: _glassPlate(s * 0.9, 0.06),
                    ),
                    Transform.rotate(
                      angle: 0.2,
                      child: _glassPlate(s * 0.92, 0.05, tint: _violet),
                    ),
                    // main photo card
                    Transform.rotate(angle: 0.1, child: _photoCard(s)),
                    // heart badge
                    Positioned(right: 6, bottom: 28, child: _heartBadge()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glassPlate(double s, double alpha, {Color tint = Colors.white}) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(46),
        color: tint.withValues(alpha: alpha),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
    );
  }

  Widget _photoCard(double s) {
    return Container(
      width: s,
      height: s,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(46),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [_softPink, Color(0x33FFFFFF), _violet],
        ),
        boxShadow: [
          BoxShadow(
            color: _pink.withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: _violet.withValues(alpha: 0.35),
            blurRadius: 60,
            offset: const Offset(10, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(43),
        child: Image.asset(
          _cardImage,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  Widget _heartBadge() {
    // Heartbeat pulse (2s cycle)
    final beat =
        1 + 0.10 * math.pow(math.sin(_loop.value * 2 * math.pi * 12), 2);
    return Transform.scale(
      scale: beat.toDouble(),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _bgMid.withValues(alpha: 0.55),
          border: Border.all(
            color: _softPink.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: _pink.withValues(alpha: 0.5), blurRadius: 22),
          ],
        ),
        child: const Icon(Icons.favorite_rounded, color: _pink, size: 30),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => const LinearGradient(
            colors: [_pink, _softPink, _lavender],
          ).createShader(rect),
          child: const Text(
            'Sophia',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              fontSize: 66,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'AI Chat Companion',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w500,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fadeLine(reverse: false),
            const SizedBox(width: 10),
            const Icon(Icons.favorite_rounded, color: _softPink, size: 16),
            const SizedBox(width: 10),
            _fadeLine(reverse: true),
          ],
        ),
      ],
    );
  }

  Widget _fadeLine({required bool reverse}) {
    final colors = [
      _lavender.withValues(alpha: 0),
      _lavender.withValues(alpha: 0.6),
    ];
    return Container(
      width: 48,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: reverse ? colors.reversed.toList() : colors,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // expanding pulse rings
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _RingsPainter(clock: _loop)),
            ),
          ),
          // glass disc
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          // Material 3 expressive loading indicator (morphing shape)
          const ExpressiveLoadingIndicator(color: Color(0xffF6D9FF)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hearts
// ═══════════════════════════════════════════════════════════════════════════

class _Heart {
  final double x; // 0..1 horizontal anchor
  final double size;
  final int speed; // full bottom→top passes per loop
  final int swayCycles; // left-right sways per loop
  final double phase; // 0..1 start offset
  final double amp; // sway amplitude in px
  final double opacity;
  final double tilt;
  final bool big;
  final double hue; // 0..1 → pink..violet mix

  const _Heart({
    required this.x,
    required this.size,
    required this.speed,
    required this.swayCycles,
    required this.phase,
    required this.amp,
    required this.opacity,
    required this.tilt,
    required this.big,
    required this.hue,
  });
}

class _HeartsPainter extends CustomPainter {
  final List<_Heart> hearts;
  final Animation<double> clock;

  _HeartsPainter({required this.hearts, required this.clock})
    : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;

    for (final h in hearts) {
      // progress 0 (bottom) → 1 (top)
      final p = (t * h.speed + h.phase) % 1.0;

      final cy = size.height + h.size - p * (size.height + h.size * 2);
      final cx =
          h.x * size.width +
          math.sin(2 * math.pi * (t * h.swayCycles + h.phase)) * h.amp;

      // fade in at the bottom, fade out at the top
      final fade = math.sin(math.pi * p);
      final alpha = (h.opacity * fade).clamp(0.0, 1.0);
      if (alpha <= 0.005) continue;

      final color = Color.lerp(_pink, _violet, h.hue * (h.big ? 1 : 0.55))!;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: h.size,
        height: h.size,
      );
      final path = _heartPath(rect);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(
        h.tilt + math.sin(2 * math.pi * (t * h.swayCycles + h.phase)) * 0.15,
      );

      if (h.big) {
        // soft blurred body + thin glowing outline
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, h.size * 0.06),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _softPink.withValues(
              alpha: alpha * 1.6 > 1 ? 1 : alpha * 1.6,
            ),
        );
      } else {
        // glow + crisp heart
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: alpha * 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, h.size * 0.35),
        );
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter old) => false;
}

Path _heartPath(Rect r) {
  final w = r.width, h = r.height, x = r.left, y = r.top;
  return Path()
    ..moveTo(x + w * 0.5, y + h * 0.95)
    ..cubicTo(
      x + w * 0.05,
      y + h * 0.62,
      x - w * 0.05,
      y + h * 0.25,
      x + w * 0.25,
      y + h * 0.12,
    )
    ..cubicTo(
      x + w * 0.40,
      y + h * 0.05,
      x + w * 0.50,
      y + h * 0.18,
      x + w * 0.50,
      y + h * 0.28,
    )
    ..cubicTo(
      x + w * 0.50,
      y + h * 0.18,
      x + w * 0.60,
      y + h * 0.05,
      x + w * 0.75,
      y + h * 0.12,
    )
    ..cubicTo(
      x + w * 1.05,
      y + h * 0.25,
      x + w * 0.95,
      y + h * 0.62,
      x + w * 0.50,
      y + h * 0.95,
    )
    ..close();
}

// ═══════════════════════════════════════════════════════════════════════════
// Waves
// ═══════════════════════════════════════════════════════════════════════════

class _WavesPainter extends CustomPainter {
  final Animation<double> clock;
  _WavesPainter({required this.clock}) : super(repaint: clock);

  // base height (0 = top of area), amplitude, frequency, speed (int), offset, colors
  static const _layers = <_WaveLayer>[
    _WaveLayer(
      0.30,
      26,
      1.0,
      2,
      0.0,
      Color(0xff6A2BB8),
      Color(0xff1E0838),
      0.55,
    ),
    _WaveLayer(
      0.50,
      30,
      1.3,
      -3,
      1.6,
      Color(0xffC04AA8),
      Color(0xff2A0B47),
      0.70,
    ),
    _WaveLayer(
      0.68,
      22,
      1.7,
      4,
      3.1,
      Color(0xff9B3FD6),
      Color(0xff2C0B47),
      0.85,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;

    for (final l in _layers) {
      final fill = Path()..moveTo(0, size.height);
      final line = Path();

      const step = 6.0;
      for (double x = 0; x <= size.width + step; x += step) {
        final nx = x / size.width;
        final y =
            size.height * l.base +
            l.amp *
                math.sin(
                  nx * 2 * math.pi * l.freq +
                      2 * math.pi * t * l.speed +
                      l.offset,
                ) +
            l.amp *
                0.35 *
                math.sin(
                  nx * 2 * math.pi * l.freq * 2.1 -
                      2 * math.pi * t * 2 +
                      l.offset,
                );
        if (x == 0) {
          line.moveTo(x, y);
        } else {
          line.lineTo(x, y);
        }
        fill.lineTo(x, y);
      }
      fill
        ..lineTo(size.width + step, size.height)
        ..close();

      final rect = Offset.zero & size;
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              l.top.withValues(alpha: l.opacity),
              l.bottom.withValues(alpha: l.opacity),
            ],
          ).createShader(rect),
      );

      // glowing crest line
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..shader = const LinearGradient(
            colors: [_pink, _lavender, _violet],
          ).createShader(rect)
          ..color = Colors.white.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) => false;
}

class _WaveLayer {
  final double base, amp, freq, offset, opacity;
  final int speed;
  final Color top, bottom;
  const _WaveLayer(
    this.base,
    this.amp,
    this.freq,
    this.speed,
    this.offset,
    this.top,
    this.bottom,
    this.opacity,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Pulse rings around the loader
// ═══════════════════════════════════════════════════════════════════════════

class _RingsPainter extends CustomPainter {
  final Animation<double> clock;
  _RingsPainter({required this.clock}) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    final t = clock.value;

    for (var i = 0; i < 3; i++) {
      final p = (t * 6 + i / 3) % 1.0; // 4s per ring
      final r = maxR * (0.55 + 0.45 * p);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _lavender.withValues(alpha: 0.22 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => false;
}
