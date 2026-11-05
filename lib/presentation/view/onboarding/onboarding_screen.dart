import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/core/haptics.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';

// Sophia onboarding — 4 animated pages (Option A "Cards").
// Usage:
//   OnboardingScreen(onFinish: () { /* save flag + go to login/home */ })

const _darkBlue = Color(0xFF140B0A);
const _darkPurple = Color(0xFF1F1311);
const _violet = Color(0xFF8C2F3C);
const _lightViolet = Color(0xFFB4505C);
const _extraLightViolet = Color(0xFFE6CF97);
const _lightPink = Color(0xFFD99A98);
const _gray = Color(0xFFB8A48A);
const _pink = Color(0xFFD99A98);
const _online = Color(0xFF9BC48A);

const _sans = 'PlusJakartaSans';
const _serif = 'PlayfairDisplay';

const _ease = Cubic(0.2, 0.8, 0.2, 1);

/// Progress (0..1) of a one-shot animation that starts at [delay]s and lasts [dur]s.
double _prog(double t, double delay, double dur, [Curve curve = _ease]) =>
    curve.transform(((t - delay) / dur).clamp(0.0, 1.0));

/// Looping 0 → 1 → 0 ease-in-out wave with the given period (s).
double _wave(double t, double period) =>
    (1 - math.cos(2 * math.pi * t / period)) / 2;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  /// Called on Skip and on Get Started.
  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  final _clock = ValueNotifier<double>(0); // seconds since the screen opened
  final _pageStart = List<double?>.filled(4, null)..[0] = 0;
  late final Ticker _ticker;
  bool _reduceMotion = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'OnboardingScreen',
      innerScreenName: 'WelcomePage',
      context: 'first_launch',
    );
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
    _ticker.dispose();
    _clock.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Seconds since page [i] became active (drives all its animations).
  double _timeOf(int i) {
    if (_reduceMotion) return 100; // jump straight to the end state
    final start = _pageStart[i];
    return start == null ? 0 : _clock.value - start;
  }

  void _onPageChanged(int i) {
    Haptics.selection();
    _page = i;
    _pageStart[i] = _clock.value;
    const pages = ['Welcome', 'ChatIntro', 'CreateIntro', 'GenerateIntro'];
    AnalyticsService.instance.screen(
      screenName: 'OnboardingScreen',
      innerScreenName: '${pages[i]}Page',
      context: 'first_launch',
    );
  }

  void _next() {
    if (_page < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFinish();
    }
  }

  void _back() => _pageController.previousPage(
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _darkBlue,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_darkBlue, _darkPurple],
            ),
          ),
          child: ValueListenableBuilder<double>(
            valueListenable: _clock,
            builder: (context, _, child) => PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _WelcomePage(
                  t: _timeOf(0),
                  onNext: _next,
                  onSkip: widget.onFinish,
                ),
                _ChatPage(
                  t: _timeOf(1),
                  onNext: _next,
                  onBack: _back,
                  onSkip: widget.onFinish,
                ),
                _CreatePage(
                  t: _timeOf(2),
                  onNext: _next,
                  onBack: _back,
                  onSkip: widget.onFinish,
                ),
                _GeneratePage(
                  t: _timeOf(3),
                  onBack: _back,
                  onStart: widget.onFinish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Pages ─────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.t,
    required this.onNext,
    required this.onSkip,
  });
  final double t;
  final VoidCallback onNext, onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final zoom = 1.14 - 0.14 * _prog(t, 0, 7, Curves.easeOut);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed photo with slow zoom-out
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: h * 0.663,
              child: ClipRect(
                child: Transform.scale(
                  scale: zoom,
                  alignment: Alignment.topCenter,
                  child: Image.asset(
                    'assets/images/onboard1.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: h * 0.688,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.22, 0.55, 1],
                    colors: [
                      _darkBlue.withValues(alpha: 0.55),
                      _darkBlue.withValues(alpha: 0),
                      Colors.transparent,
                      const Color(0xFF170C0A),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: h * 0.474,
              left: 24,
              child: _PopFloat(
                t: t,
                delay: 0.6,
                child: _OnlineChip(t: t),
              ),
            ),
            _PageFrame(
              header: _Up(
                t: t,
                delay: 0,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.webp',
                        width: 32,
                        height: 32,
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
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    _PillButton(
                      label: 'Skip',
                      onTap: onSkip,
                      background: _darkBlue.withValues(alpha: 0.4),
                      borderAlpha: 0.22,
                    ),
                  ],
                ),
              ),
              bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Up(
                    t: t,
                    delay: 0.2,
                    child: const Text(
                      'WELCOME',
                      style: TextStyle(
                        fontFamily: _sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: _extraLightViolet,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Up(
                    t: t,
                    delay: 0.3,
                    child: Text.rich(
                      TextSpan(
                        style: _headline(34),
                        children: [
                          const TextSpan(text: 'Meet '),
                          _accent('Sophia'),
                          const TextSpan(text: ',\nyour AI companion'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Up(
                    t: t,
                    delay: 0.45,
                    child: const Text(
                      'Someone to talk to whenever you like — she listens, remembers your story and is always happy to chat.',
                      style: _body,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Up(
                    t: t,
                    delay: 0.6,
                    child: _ControlsRow(t: t, active: 0, onNext: onNext),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChatPage extends StatelessWidget {
  const _ChatPage({
    required this.t,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });
  final double t;
  final VoidCallback onNext, onBack, onSkip;

  @override
  Widget build(BuildContext context) {
    final zoom = 1.14 - 0.14 * _prog(t, 0, 7, Curves.easeOut);
    return _PageFrame(
      header: _Up(
        t: t,
        delay: 0,
        child: _BackSkipHeader(onBack: onBack, onSkip: onSkip),
      ),
      visual: _Visual(
        width: 342,
        height: 400,
        children: [
          // Photo card
          Positioned.fill(
            child: _Up(
              t: t,
              delay: 0.1,
              child: Container(
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: _extraLightViolet.withValues(alpha: 0.18),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: zoom,
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          'assets/images/onboard2.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.4, 1],
                            colors: [
                              _darkPurple.withValues(alpha: 0),
                              _darkPurple.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 176,
            left: 16,
            child: _PopFloat(
              t: t,
              delay: 0.6,
              amp: 6,
              child: _Bubble(
                maxWidth: 230,
                fromMe: false,
                text: 'Hey! How was your day? Tell me everything.',
              ),
            ),
          ),
          Positioned(
            top: 258,
            right: 16,
            child: _PopFloat(
              t: t,
              delay: 1.2,
              amp: 6,
              child: _Bubble(
                maxWidth: 210,
                fromMe: true,
                text: 'Long one, but better now that we’re talking.',
              ),
            ),
          ),
          Positioned(
            top: 328,
            left: 16,
            child: _PopFloat(
              t: t,
              delay: 1.8,
              amp: 6,
              child: _TypingBubble(t: t),
            ),
          ),
        ],
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Up(
                t: t,
                delay: 0.25,
                child: const _Chip(label: 'English', selected: true),
              ),
              _Up(
                t: t,
                delay: 0.32,
                child: const _Chip(label: 'हिन्दी'),
              ),
              _Up(
                t: t,
                delay: 0.39,
                child: const _Chip(label: 'Español'),
              ),
              _Up(
                t: t,
                delay: 0.46,
                child: const _Chip(label: '+ more'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Up(
            t: t,
            delay: 0.35,
            child: Text.rich(
              TextSpan(
                style: _headline(32),
                children: [
                  const TextSpan(text: 'Chat anytime,\nin '),
                  _accent('your language'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Up(
            t: t,
            delay: 0.5,
            child: const Text(
              "Real conversations, day or night. Pick the language you're most comfortable in.",
              style: _body,
            ),
          ),
          const SizedBox(height: 20),
          _Up(
            t: t,
            delay: 0.6,
            child: _ControlsRow(t: t, active: 1, onNext: onNext),
          ),
        ],
      ),
    );
  }
}

class _CreatePage extends StatelessWidget {
  const _CreatePage({
    required this.t,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });
  final double t;
  final VoidCallback onNext, onBack, onSkip;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      header: _Up(
        t: t,
        delay: 0,
        child: _BackSkipHeader(onBack: onBack, onSkip: onSkip),
      ),
      visual: _Visual(
        width: 342,
        height: 404,
        children: [
          Positioned(
            top: 20,
            left: 16,
            child: _FanCard(
              t: t,
              direction: -1,
              image: 'assets/images/onboard1.png',
            ),
          ),
          Positioned(
            top: 20,
            right: 16,
            child: _FanCard(
              t: t,
              direction: 1,
              image: 'assets/images/onboard2.png',
            ),
          ),
          Positioned(
            top: 4,
            left: 51,
            child: _PopFloat(
              t: t,
              delay: 0.1,
              period: 5,
              child: _CharacterCard(t: t),
            ),
          ),
          Positioned(
            top: 362,
            left: 0,
            right: 0,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _Up(
                  t: t,
                  delay: 0.6,
                  child: const _Chip(
                    label: 'Look',
                    selected: true,
                    large: true,
                  ),
                ),
                _Up(
                  t: t,
                  delay: 0.7,
                  child: const _Chip(label: 'Personality', large: true),
                ),
                _Up(
                  t: t,
                  delay: 0.8,
                  child: const _Chip(label: 'Hobbies', large: true),
                ),
                _Up(
                  t: t,
                  delay: 0.9,
                  child: const _Chip(label: 'Voice', large: true),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Up(
            t: t,
            delay: 0.3,
            child: Text.rich(
              TextSpan(
                style: _headline(32),
                children: [
                  const TextSpan(text: 'Create '),
                  _accent('your own'),
                  const TextSpan(text: '\ncompanion'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Up(
            t: t,
            delay: 0.45,
            child: const Text(
              'Choose a look, shape a personality and add the little details that make her yours.',
              style: _body,
            ),
          ),
          const SizedBox(height: 20),
          _Up(
            t: t,
            delay: 0.6,
            child: _ControlsRow(t: t, active: 2, onNext: onNext),
          ),
        ],
      ),
    );
  }
}

class _GeneratePage extends StatelessWidget {
  const _GeneratePage({
    required this.t,
    required this.onBack,
    required this.onStart,
  });
  final double t;
  final VoidCallback onBack, onStart;

  @override
  Widget build(BuildContext context) {
    final pulse = 1 + 0.12 * _wave(t, 1.5);
    return _PageFrame(
      header: _Up(
        t: t,
        delay: 0,
        child: Row(
          children: [
            _CircleIconButton(
              icon: 'ic_back',
              tooltip: 'Back',
              onTap: onBack,
            ),
            const Spacer(),
            const Text(
              '4 of 4',
              style: TextStyle(
                fontFamily: _sans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _gray,
              ),
            ),
          ],
        ),
      ),
      visual: _Visual(
        width: 342,
        height: 404,
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: 342,
            height: 380,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Reveal(
                    t: t,
                    delay: 0.1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/onboard3.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _Up(
                            t: t,
                            delay: 0.9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _darkBlue.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: _extraLightViolet,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'AI photo',
                                    style: TextStyle(
                                      fontFamily: _sans,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Reveal(
                          t: t,
                          delay: 0.3,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/onboard1.png',
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -0.6),
                              ),
                              ColoredBox(
                                color: _darkBlue.withValues(alpha: 0.25),
                              ),
                              Center(
                                child: Transform.scale(
                                  scale: pulse,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: _violet,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _Reveal(
                          t: t,
                          delay: 0.5,
                          child: Image.asset(
                            'assets/images/onboard2.png',
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 354,
            left: 0,
            right: 0,
            child: Center(
              child: _PopFloat(
                t: t,
                delay: 0.8,
                amp: 6,
                child: _PromptPill(t: t),
              ),
            ),
          ),
        ],
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Up(
            t: t,
            delay: 0.3,
            child: Text.rich(
              TextSpan(
                style: _headline(32),
                children: [
                  const TextSpan(text: 'Photos & reels,\n'),
                  _accent('made for you'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Up(
            t: t,
            delay: 0.45,
            child: const Text(
              'Describe a moment and generate new photos of your companion, then watch her reels.',
              style: _body,
            ),
          ),
          const SizedBox(height: 20),
          _Up(
            t: t,
            delay: 0.55,
            child: Center(child: _Dots(t: t, active: 3)),
          ),
          const SizedBox(height: 16),
          _Up(
            t: t,
            delay: 0.65,
            child: _GetStartedButton(t: t, onTap: onStart),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Layout ────────────────────────────

/// Header on top, optional scaled visual in the middle, text + controls at the bottom.
class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.header, required this.bottom, this.visual});
  final Widget header, bottom;
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: visual == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
                      child: visual,
                    ),
            ),
            bottom,
          ],
        ),
      ),
    );
  }
}

/// Fixed-size design canvas (from the mockup) that scales down to fit smaller screens.
class _Visual extends StatelessWidget {
  const _Visual({
    required this.width,
    required this.height,
    required this.children,
  });
  final double width, height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }
}

// ─────────────────────────── Animations ───────────────────────────

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
  const _PopFloat({
    required this.t,
    required this.delay,
    required this.child,
    this.amp = 8,
    this.period = 4,
  });
  final double t, delay, amp, period;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = _prog(t, delay, 0.6);
    final floatT = t - delay - 0.6;
    final dy = 12 * (1 - p) - (floatT > 0 ? amp * _wave(floatT, period) : 0);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(scale: 0.85 + 0.15 * p, child: child),
      ),
    );
  }
}

/// Rounded image tile that comes in from a blur (like it's being generated).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.t, required this.delay, required this.child});
  final double t, delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = _prog(t, delay, 0.9);
    final sigma = 10 * (1 - p);
    Widget tile = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: child,
    );
    if (sigma > 0.05) {
      tile = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: tile,
      );
    }
    return Opacity(
      opacity: p,
      child: Transform.scale(scale: 0.9 + 0.1 * p, child: tile),
    );
  }
}

// ──────────────────────────── Pieces ────────────────────────────

TextStyle _headline(double size) => TextStyle(
  fontFamily: _sans,
  fontSize: size,
  height: 1.15,
  fontWeight: FontWeight.w700,
  color: Colors.white,
);

TextSpan _accent(String text) => TextSpan(
  text: text,
  style: const TextStyle(
    fontFamily: _serif,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    color: _pink,
  ),
);

const _body = TextStyle(
  fontFamily: _sans,
  fontSize: 15,
  height: 1.55,
  color: _gray,
);

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.background,
    this.borderAlpha = 0.18,
  });
  final String label;
  final VoidCallback onTap;
  final Color background;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: borderAlpha)),
    );
    return Material(
      color: background,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: Haptics.wrap(onTap),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: _sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final String icon; // svg name in assets/svg
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = CircleBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    );
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: Haptics.wrap(onTap),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: SvgIcon(icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }
}

class _BackSkipHeader extends StatelessWidget {
  const _BackSkipHeader({required this.onBack, required this.onSkip});
  final VoidCallback onBack, onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
          icon: 'ic_back',
          tooltip: 'Back',
          onTap: onBack,
        ),
        const Spacer(),
        _PillButton(
          label: 'Skip',
          onTap: onSkip,
          background: Colors.white.withValues(alpha: 0.06),
        ),
      ],
    );
  }
}

/// Soft breathing glow shared by the Next and Get Started buttons.
List<BoxShadow> _glow(double t) {
  final k = _wave(t, 2.4);
  return [
    BoxShadow(
      color: Color.lerp(
        _violet.withValues(alpha: 0.5),
        _lightPink.withValues(alpha: 0.9),
        k,
      )!,
      blurRadius: 30 + 16 * k,
      offset: const Offset(0, 10),
    ),
  ];
}

const _buttonGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_violet, _lightViolet],
);

class _Dots extends StatelessWidget {
  const _Dots({required this.t, required this.active});
  final double t;
  final int active;

  @override
  Widget build(BuildContext context) {
    final grow = _prog(t, 0.7, 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: i == active ? 8 + 20 * grow : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? _pink : Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}

class _ControlsRow extends StatelessWidget {
  const _ControlsRow({
    required this.t,
    required this.active,
    required this.onNext,
  });
  final double t;
  final int active;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Dots(t: t, active: active),
        Semantics(
          button: true,
          label: 'Next',
          child: GestureDetector(
            onTap: Haptics.wrap(onNext),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _buttonGradient,
                boxShadow: _glow(t),
              ),
              child: Transform.translate(
                offset: Offset(4 * _wave(t, 1.6), 0),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.t, required this.onTap});
  final double t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: Haptics.wrap(onTap),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(29),
            gradient: _buttonGradient,
            boxShadow: _glow(t),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Get Started',
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
    );
  }
}

class _OnlineChip extends StatelessWidget {
  const _OnlineChip({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final ping = (t % 1.6) / 1.6; // ring expands and fades
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: _darkPurple.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _extraLightViolet.withValues(alpha: 0.3)),
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
            'Online now',
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.selected = false, this.large = false});
  final String label;
  final bool selected, large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? _violet.withValues(alpha: large ? 0.25 : 0.22)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(large ? 16 : 14),
        border: Border.all(
          color: selected
              ? (large ? _lightViolet : _lightViolet.withValues(alpha: 0.4))
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: _sans,
          fontSize: large ? 13 : 12,
          fontWeight: FontWeight.w600,
          color: selected ? (large ? Colors.white : _extraLightViolet) : _gray,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.fromMe,
    required this.maxWidth,
  });
  final String text;
  final bool fromMe;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: fromMe ? null : _darkPurple.withValues(alpha: 0.88),
          gradient: fromMe
              ? const LinearGradient(colors: [_lightPink, _violet])
              : null,
          border: fromMe
              ? null
              : Border.all(color: _extraLightViolet.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(fromMe ? 20 : 6),
            bottomRight: Radius.circular(fromMe ? 6 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: fromMe
                  ? _violet.withValues(alpha: 0.45)
                  : const Color(0xFF0D0706).withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: _sans,
            fontSize: 14,
            height: 1.45,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _darkPurple.withValues(alpha: 0.88),
        border: Border.all(color: _extraLightViolet.withValues(alpha: 0.25)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Builder(
              builder: (_) {
                final k = _wave(t - i * 0.15, 1.2);
                return Transform.translate(
                  offset: Offset(0, -3 * k),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _extraLightViolet.withValues(alpha: 0.3 + 0.7 * k),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Faded side card that fans out from behind the main card.
class _FanCard extends StatelessWidget {
  const _FanCard({
    required this.t,
    required this.direction,
    required this.image,
  });
  final double t;
  final int direction; // -1 = left (tilts left), 1 = right
  final String image;

  @override
  Widget build(BuildContext context) {
    final p = _prog(t, 0.5, 0.9);
    return Opacity(
      opacity: 0.55 * p,
      child: Transform.translate(
        offset: Offset(-direction * 70 * (1 - p), 0),
        child: Transform.rotate(
          angle: direction * 6 * math.pi / 180 * p,
          child: Container(
            width: 220,
            height: 300,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _extraLightViolet.withValues(alpha: 0.2),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final check = _prog(t, 1.1, 0.5, Curves.easeOutBack);
    return Container(
      width: 240,
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _lightViolet, width: 2),
        boxShadow: [
          BoxShadow(
            color: _violet.withValues(alpha: 0.45),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/onboard3.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _darkPurple.withValues(alpha: 0),
                      _darkPurple.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your character',
                          style: TextStyle(
                            fontFamily: _serif,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Caring · Witty · Curious',
                          style: TextStyle(
                            fontFamily: _sans,
                            fontSize: 12,
                            color: _extraLightViolet,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: check.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: check,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: _pink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptPill extends StatelessWidget {
  const _PromptPill({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: _darkPurple.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _extraLightViolet.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D0706).withValues(alpha: 0.7),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF7A2533), Color(0xFFB4505C)],
              ),
            ),
            child: Transform.rotate(
              angle: 2 * math.pi * (t % 6) / 6,
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '“Sunset at the beach, golden hour”',
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
