import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Refined plum / amethyst / champagne palette used by the redesigned
/// Customize tab and Create Character flow.
class SophiaColors {
  SophiaColors._();

  static const bgTop = Color(0xFF140B0A);
  static const bgBottom = Color(0xFF1F1311);
  static const panelTop = Color(0xFF1A0F0D);
  static const lavender = Color(0xFFF2E8D5);
  static const lilac = Color(0xFFEBD9C4);
  static const muted = Color(0xFFB8A48A);
  static const champagne = Color(0xFFE6CF97);
  static const orchid = Color(0xFFA8434F);
  static const amethystMid = Color(0xFF8C2F3C);

  static const amethyst = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A1A24), Color(0xFF8C2F3C), Color(0xFFB4505C)],
    stops: [0, 0.55, 1],
  );

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );
}

const sophiaSerif = 'PlayfairDisplay';

/// Script face for large titles. Its lowercase runs small, so set it about
/// 1.24x the size the serif would use.
const sophiaScript = 'GreatVibes';

/// Handwriting face for letter text.
const sophiaHand = 'Caveat';

/// Repeating animation driver; holds still when the OS asks to reduce motion.
class LoopAnimation extends StatefulWidget {
  final Duration duration;
  final bool reverse;
  final double initial;
  final Widget? child;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  const LoopAnimation({
    super.key,
    required this.duration,
    required this.builder,
    this.reverse = false,
    this.initial = 0,
    this.child,
  });

  @override
  State<LoopAnimation> createState() => _LoopAnimationState();
}

class _LoopAnimationState extends State<LoopAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.initial,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _started = false;
    } else if (!_started) {
      _c.repeat(reverse: widget.reverse);
      _started = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _c.value, child),
    );
  }
}

/// Slide-up entrance after [delay] ms. Content stays visible; only position animates.
class SlideEntrance extends StatefulWidget {
  final int delay;
  final double distance;
  final Widget child;

  const SlideEntrance({super.key, required this.delay, required this.child, this.distance = 18});

  @override
  State<SlideEntrance> createState() => _SlideEntranceState();
}

class _SlideEntranceState extends State<SlideEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, widget.distance * (1 - _curve.value)), child: child),
    );
  }
}

/// Diagonal light sweep across a surface every few seconds. Place inside a clipped Stack.
class SheenEffect extends StatelessWidget {
  final double widthFactor;
  const SheenEffect({super.key, this.widthFactor = 0.38});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth * widthFactor;
          return LoopAnimation(
            duration: const Duration(milliseconds: 4800),
            builder: (_, t, child) {
              if (t < 0.62) return const SizedBox.shrink();
              final p = Curves.easeInOut.transform((t - 0.62) / 0.38);
              final x = -w * 1.4 + (box.maxWidth + w * 2.8) * p;
              return Transform.translate(offset: Offset(x, 0), child: child);
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform(
                transform: Matrix4.skewX(-0.32),
                child: Container(
                  width: w,
                  height: box.maxHeight * 1.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Scales down slightly while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, required this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: Haptics.wrap(widget.onTap),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Amethyst gradient pill button with the light sweep.
class AmethystButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final Widget? leading;
  final Widget? trailing;

  const AmethystButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 52,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.6 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: SophiaColors.amethyst,
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: SophiaColors.amethystMid.withValues(alpha: 0.9),
                blurRadius: 30,
                spreadRadius: -14,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                const Positioned.fill(child: SheenEffect(widthFactor: 0.3)),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 8)],
                      Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon from assets/svg, tinted like a normal [Icon].
class SvgIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const SvgIcon(this.name, {super.key, this.size = 24, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/svg/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
