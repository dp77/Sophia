import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:grokbot_widget/grokbot_widget.dart';

import 'sophia_style.dart';

/// Shared look for every pop-up in the app: frosted plum card, champagne
/// hairline, a hero on top (mascot or icon badge), Playfair title and
/// stacked buttons. Opens with a blur + soft scale.

enum SophiaTone { normal, danger, gold }

const _rose = Color(0xFFD99A98);
const _roseDeep = Color(0xFF8C2F3C);
const _gold = Color(0xFFC9A55C);

Future<T?> showSophiaDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
  bool canPop = true,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Dialog',
    barrierColor: barrierColor ?? SophiaColors.bgTop.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, _) => PopScope(canPop: canPop, child: builder(ctx)),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8 * anim.value, sigmaY: 8 * anim.value),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(curved), child: child),
        ),
      );
    },
  );
}

class SophiaDialog extends StatelessWidget {
  final Widget hero;
  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;
  final SophiaTone tone;

  const SophiaDialog({
    super.key,
    required this.hero,
    required this.title,
    this.message,
    this.body,
    required this.actions,
    this.tone = SophiaTone.normal,
  });

  Color get _accent => switch (tone) {
    SophiaTone.danger => _rose,
    SophiaTone.gold => _gold,
    SophiaTone.normal => SophiaColors.champagne,
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 330,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF261512), SophiaColors.bgTop],
            ),
            border: Border.all(color: _accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(color: _accent.withValues(alpha: 0.18), blurRadius: 60, spreadRadius: -10),
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(31),
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 260,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [_accent.withValues(alpha: 0.22), _accent.withValues(alpha: 0)]),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      hero,
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: SophiaColors.lavender,
                          fontSize: 25,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          fontFamily: sophiaSerif,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: SophiaColors.muted, fontSize: 13.5, height: 1.45),
                        ),
                      ],
                      if (body != null) ...[const SizedBox(height: 16), body!],
                      const SizedBox(height: 22),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        actions[i],
                      ],
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

/// Turning gradient ring with any child inside.
class _Ring extends StatelessWidget {
  final double size;
  final List<Color> colors;
  final Widget child;
  const _Ring({required this.size, required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: LoopAnimation(
              duration: const Duration(seconds: 6),
              builder: (_, t, c) => Transform.rotate(angle: t * 2 * math.pi, child: c),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: colors),
                  boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 24)],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: Alignment(0, -0.3), colors: [Color(0xFF2E1A16), SophiaColors.panelTop]),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}

List<Color> _ringColors(SophiaTone tone) => switch (tone) {
  SophiaTone.danger => const [_rose, _roseDeep, Color(0xFFEBC3BE), _rose],
  SophiaTone.gold => const [_gold, Color(0xFFF7EBC6), Color(0xFFE6CF97), _gold],
  SophiaTone.normal => const [SophiaColors.champagne, SophiaColors.orchid, SophiaColors.lilac, SophiaColors.champagne],
};

/// The GrokBot mascot as the dialog hero.
class SophiaMascotHero extends StatelessWidget {
  final GrokBotState state;
  final SophiaTone tone;
  const SophiaMascotHero({super.key, required this.state, this.tone = SophiaTone.normal});

  @override
  Widget build(BuildContext context) {
    return _Ring(
      size: 96,
      colors: _ringColors(tone),
      child: GrokBot(
        size: 58,
        shape: GrokBotShape.blob,
        state: state,
        theme: const GrokBotThemeData(bodyColor: SophiaColors.lilac, eyeColor: SophiaColors.bgBottom),
        semanticLabel: 'Sophia mascot',
      ),
    );
  }
}

/// An icon as the dialog hero, with a gentle pulse.
class SophiaIconHero extends StatelessWidget {
  final IconData icon;
  final SophiaTone tone;
  const SophiaIconHero({super.key, required this.icon, this.tone = SophiaTone.normal});

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      SophiaTone.danger => _rose,
      SophiaTone.gold => _gold,
      SophiaTone.normal => SophiaColors.champagne,
    };
    return _Ring(
      size: 88,
      colors: _ringColors(tone),
      child: LoopAnimation(
        duration: const Duration(milliseconds: 1600),
        reverse: true,
        builder: (_, t, c) => Transform.scale(scale: 0.94 + 0.08 * Curves.easeInOut.transform(t), child: c),
        child: Icon(icon, color: color, size: 34),
      ),
    );
  }
}

/// Rose gradient button for destructive actions.
class SophiaDangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final String? svg; // icon from assets/svg
  const SophiaDangerButton({super.key, required this.label, required this.onTap, this.svg});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [_roseDeep, Color(0xFFB4505C)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(color: _roseDeep.withValues(alpha: 0.6), blurRadius: 24, spreadRadius: -10, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (svg != null) ...[SvgIcon(svg!, color: Colors.white, size: 18), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Gold gradient button (premium moments).
class SophiaGoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const SophiaGoldButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [_gold, Color(0xFFE6CF97), _gold]),
          boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              const Positioned.fill(child: SheenEffect(widthFactor: 0.3)),
              Center(
                child: Text(
                  label,
                  style: const TextStyle(color: Color(0xFF1F1311), fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet text button ("Cancel", "Later", "Keep").
class SophiaGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const SophiaGhostButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: SophiaColors.muted, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Small note box inside a dialog (warnings, highlights).
class SophiaNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final SophiaTone tone;
  const SophiaNote({super.key, required this.icon, required this.text, this.tone = SophiaTone.normal});

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      SophiaTone.danger => _rose,
      SophiaTone.gold => _gold,
      SophiaTone.normal => SophiaColors.champagne,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
