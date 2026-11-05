import 'package:girlfriend/core/haptics.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';

// "Sophia Pro" promo card — shared by Watch & Earn and Settings.

const _pink = Color(0xFFD99A98);
const _gold = Color(0xFFC9A55C);
const _goldMid = Color(0xFFE6CF97);
const _ink = Color(0xFF1F1311);
const _soft = Color(0xFFEBD9C4);
const _sans = 'PlusJakartaSans';

const _proPhotos = [
  'assets/images/onboard1.png',
  'assets/images/onboard2.png',
  'assets/images/onboard3.png',
];

double _wave(double t, double period) => (1 - math.cos(2 * math.pi * t / period)) / 2;

/// Self-animating version for screens that don't run their own clock.
class AnimatedProCard extends StatefulWidget {
  const AnimatedProCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<AnimatedProCard> createState() => _AnimatedProCardState();
}

class _AnimatedProCardState extends State<AnimatedProCard> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return ValueListenableBuilder<double>(
      valueListenable: _clock,
      builder: (context, t, _) => ProCard(t: still ? 2.0 : t, onTap: widget.onTap),
    );
  }
}

class ProCard extends StatelessWidget {
  const ProCard({required this.t, required this.onTap});
  final double t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 224,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < _proPhotos.length; i++)
              _ProCyclingPhoto(t: t, index: i),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    darkBlue.withValues(alpha: 0.92),
                    darkBlue.withValues(alpha: 0.7),
                    darkBlue.withValues(alpha: 0.15),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              color: _gold,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'SOPHIA PRO',
                              style: TextStyle(
                                fontFamily: _sans,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                color: _gold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontFamily: _sans,
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(text: 'Skip the ads. '),
                              TextSpan(
                                text: 'Just talk.',
                                style: TextStyle(
                                  fontFamily: sophiaScript,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 31,
                                  color: _pink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Unlimited chats · 4,000 credits · No ads',
                          style: TextStyle(
                            fontFamily: _sans,
                            fontSize: 12,
                            height: 1.5,
                            color: _soft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ProGoButton(t: t, onTap: onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProCyclingPhoto extends StatelessWidget {
  const _ProCyclingPhoto({required this.t, required this.index});
  final double t;
  final int index;

  @override
  Widget build(BuildContext context) {
    const offsets = [0.0, 6.0, 3.0];
    final p = ((t + offsets[index]) % 9) / 9;
    double opacity;
    if (p < 0.33) {
      opacity = 1;
    } else if (p < 0.40) {
      opacity = 1 - (p - 0.33) / 0.07;
    } else if (p < 0.93) {
      opacity = 0;
    } else {
      opacity = (p - 0.93) / 0.07;
    }
    if (opacity == 0) return const SizedBox.shrink();
    final scale = p < 0.40
        ? 1.12 - 0.12 * Curves.easeInOut.transform(p / 0.40)
        : 1.12;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        alignment: const Alignment(0, -0.6),
        child: Image.asset(
          _proPhotos[index],
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.6),
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _ProGoButton extends StatelessWidget {
  const _ProGoButton({required this.t, required this.onTap});
  final double t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = _wave(t, 2.4);
    final sweepK = t < 1.5
        ? -1.0
        : Curves.easeInOut.transform(((t - 1.5) % 3) / 3);
    return Semantics(
      button: true,
      label: 'Go Pro',
      child: GestureDetector(
        onTap: Haptics.wrap(onTap),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(colors: [_gold, _goldMid, _gold]),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  _gold.withValues(alpha: 0.3),
                  _goldMid.withValues(alpha: 0.6),
                  k,
                )!,
                blurRadius: 26 + 14 * k,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  if (sweepK >= 0)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: -100 + (c.maxWidth + 200) * sweepK,
                      child: Transform(
                        transform: Matrix4.skewX(-0.35),
                        child: Container(
                          width: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.8),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Go Pro',
                          style: TextStyle(
                            fontFamily: _sans,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.translate(
                          offset: Offset(4 * _wave(t, 1.6), 0),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: _ink,
                            size: 18,
                          ),
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
    );
  }
}

