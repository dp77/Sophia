import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/haptics.dart';
import '../../data/love_letters.dart';
import '../../data/model/love_letter.dart';
import '../../data/navigation_service.dart';
import '../view/screens/chat_screen.dart';
import '../view_model/user_provider.dart';
import 'sophia_style.dart';

/// Paper, wax and ink tones for the love-letter pieces.
class LetterColors {
  LetterColors._();

  static const paper = Color(0xFFF7EEDC);
  static const envelope = Color(0xFFEADBC0);
  static const envelopeSealed = Color(0xFFE6D5B8);
  static const envelopeRead = Color(0xFFDCD0BA);
  static const flap = Color(0xFFDCC7A3);
  static const ink = Color(0xFF3A1F1A);
  static const inkSoft = Color(0xFF6B4A3C);
  static const wine = Color(0xFF8C2F3C);
  static const wineLight = Color(0xFFC25A66);
  static const wineDeep = Color(0xFF5A1A24);
  static const sealHeart = Color(0xFF6A1F2B);
  static const rose = Color(0xFFD99A98);
  static const roseLight = Color(0xFFE8B9B2);
  static const stampFrame = Color(0xFFFBF6EA);
  static const stampDots = Color(0xFFCDB896);
}

String letterTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${DateUtilsHelper.formatChatDate(d)}, $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "My dear Alex," or just "My dear," when the name is unknown.
String letterGreeting(BuildContext context) {
  final name = context.read<UserProvider>().name.trim();
  return name.isEmpty || name == 'Anonymous' ? 'My dear,' : 'My dear $name,';
}

/// Red wax seal with an embossed heart (or any [child]).
class WaxSeal extends StatelessWidget {
  final double size;
  final Widget? child;
  final bool faded;

  const WaxSeal({super.key, this.size = 46, this.child, this.faded = false});

  @override
  Widget build(BuildContext context) {
    final seal = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.elliptical(size * .48, size * .55),
          topRight: Radius.elliptical(size * .52, size * .45),
          bottomRight: Radius.elliptical(size * .5, size * .55),
          bottomLeft: Radius.elliptical(size * .5, size * .45),
        ),
        border: Border.all(color: const Color(0x22000000), width: size * .06),
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [LetterColors.wineLight, LetterColors.wine, LetterColors.wineDeep],
          stops: [0, .55, 1],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child:
          child ??
          Icon(
            Icons.favorite_rounded,
            size: size * .44,
            color: LetterColors.sealHeart,
            shadows: const [Shadow(color: Color(0x66FFDCDC), offset: Offset(0, -0.8))],
          ),
    );
    return faded ? Opacity(opacity: .55, child: seal) : seal;
  }
}

/// Her photo framed like a postage stamp.
class PhotoStamp extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double width;
  final double height;
  final double angle;

  const PhotoStamp({
    super.key,
    required this.imageUrl,
    required this.name,
    this.width = 60,
    this.height = 72,
    this.angle = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: LetterColors.wine,
      alignment: Alignment.center,
      child: name.isEmpty
          ? Icon(Icons.favorite_rounded, size: height * .35, color: SophiaColors.champagne)
          : Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                fontFamily: sophiaScript,
                fontSize: height * .5,
                color: SophiaColors.champagne,
                height: 1,
              ),
            ),
    );
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        foregroundPainter: _PerforationPainter(),
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.all(width * .075),
          decoration: BoxDecoration(
            color: LetterColors.stampFrame,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: imageUrl.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
        ),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = LetterColors.stampDots;
    const step = 5.0, r = 1.0, inset = 1.6;
    for (double x = inset; x <= size.width - inset; x += step) {
      canvas.drawCircle(Offset(x, inset), r, paint);
      canvas.drawCircle(Offset(x, size.height - inset), r, paint);
    }
    for (double y = inset + step; y <= size.height - inset - step; y += step) {
      canvas.drawCircle(Offset(inset, y), r, paint);
      canvas.drawCircle(Offset(size.width - inset, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The two fold lines of a closed envelope flap.
class EnvelopeLinesPainter extends CustomPainter {
  final double depth;
  final Color color;

  const EnvelopeLinesPainter({this.depth = .56, this.color = const Color(0x2E3A1F1A)});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height * depth)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant EnvelopeLinesPainter old) => old.depth != depth || old.color != color;
}

/// Open flap seen behind the letter.
class FlapClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height)
    ..lineTo(size.width / 2, 0)
    ..lineTo(size.width, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Faint ruled lines on letter paper.
class RuledPaperPainter extends CustomPainter {
  final double top;
  final double spacing;

  const RuledPaperPainter({this.top = 40, this.spacing = 25});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LetterColors.wine.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (double y = top; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant RuledPaperPainter old) => old.top != top || old.spacing != spacing;
}

/// Round "with love" postmark.
class PostmarkPainter extends CustomPainter {
  const PostmarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = LetterColors.wine
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r - 1, paint..strokeWidth = 1.6);
    canvas.drawCircle(c, r * .72, paint..strokeWidth = 1);
    final wave = Path();
    for (var i = 0; i < 3; i++) {
      final y = c.dy - 8 + i * 8.0;
      wave.moveTo(c.dx - r * 1.9, y);
      for (var k = 0; k < 4; k++) {
        final x = c.dx - r * 1.9 + k * 10;
        wave.quadraticBezierTo(x + 2.5, y - 3, x + 5, y);
        wave.quadraticBezierTo(x + 7.5, y + 3, x + 10, y);
      }
    }
    canvas.drawPath(wave, paint..strokeWidth = 1.2);
    final heart = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.favorite_rounded.codePoint),
        style: TextStyle(
          color: LetterColors.wine,
          fontSize: 13,
          fontFamily: Icons.favorite_rounded.fontFamily,
          package: Icons.favorite_rounded.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    heart.paint(canvas, c - Offset(heart.width / 2, heart.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rose petals drifting down. Holds still when the OS asks to reduce motion.
class PetalFall extends StatelessWidget {
  final int count;
  const PetalFall({super.key, this.count = 12});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: LoopAnimation(
          duration: const Duration(seconds: 16),
          builder: (context, t, _) => CustomPaint(painter: _PetalPainter(t, count), size: Size.infinite),
        ),
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  final double t;
  final int count;
  _PetalPainter(this.t, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < count; i++) {
      final laps = 1 + i % 2; // whole laps per cycle keep the loop seamless
      final phase = (i * 0.137) % 1;
      final p = (t * laps + phase) % 1;
      final w = 9.0 + (i % 4) * 3;
      final h = w * 1.3;
      final sway = math.sin(2 * math.pi * (t * laps * 2 + phase)) * 18;
      final x = ((i * 61 + 17) % 97) / 97 * size.width + sway + p * 40;
      final y = -30 + p * (size.height + 60);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(2 * math.pi * (t * laps + phase * 3));
      final path = Path()
        ..moveTo(0, -h / 2)
        ..cubicTo(w * .62, -h * .42, w * .5, h * .42, 0, h / 2)
        ..cubicTo(-w * .5, h * .42, -w * .62, -h * .42, 0, -h / 2);
      final opacity = 0.5 + (i % 3) * 0.15;
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(-w / 2, -h / 2),
            Offset(w / 2, h / 2),
            [
              LetterColors.roseLight.withValues(alpha: opacity),
              const Color(0xFFB4505C).withValues(alpha: opacity),
              LetterColors.wine.withValues(alpha: opacity),
            ],
            [0, .6, 1],
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter old) => old.t != t || old.count != count;
}

/// Keeps a companion's note in the Letters tab and slides it in as a letter.
class LoveLetterPost {
  LoveLetterPost._();

  static Future<void> deliver({
    String? id,
    required String companionId,
    required String name,
    required String imageUrl,
    required String text,
    bool announce = true,
  }) async {
    final letter = await LoveLetters.instance.add(
      id: id,
      companionId: companionId,
      name: name,
      imageUrl: imageUrl,
      text: text.trim().isEmpty ? 'Sent you a new message.' : text,
    );
    if (letter != null && announce) LoveLetterBanner.show(letter);
  }

  /// Reads a OneSignal push. Returns null when it doesn't name a companion in its
  /// additional data (companion_id or companion_name), so other pushes stay as they are.
  static ({String companionId, String name, String imageUrl, String text})? fromPush(OSNotification n) {
    final data = n.additionalData ?? const <String, dynamic>{};
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
      }
      return '';
    }

    final companionId = pick(const ['companion_id', 'companionId', 'gf_id', 'gfid', 'girlfriend_id']);
    final companionName = pick(const ['companion_name', 'companionName', 'girlfriend_name', 'gf_name']);
    if (companionId.isEmpty && companionName.isEmpty) return null;
    final image = pick(const ['image_url', 'imageUrl', 'companion_image', 'avatar']);
    return (
      companionId: companionId,
      name: companionName.isNotEmpty ? companionName : (n.title ?? ''),
      imageUrl: image.isNotEmpty ? image : (n.largeIcon ?? n.bigPicture ?? ''),
      text: n.body ?? '',
    );
  }
}

/// An envelope that drops in from the top when a companion writes.
class LoveLetterBanner {
  LoveLetterBanner._();

  static OverlayEntry? _entry;

  static void show(LoveLetter letter) {
    final overlay = NavigationService.overlay;
    if (overlay == null) return;
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _LetterBannerView(
        letter: letter,
        onDone: _remove,
        onOpen: () {
          _remove();
          final ctx = NavigationService.navigatorKey.currentContext;
          if (ctx != null) showLoveLetter(ctx, letter);
        },
      ),
    );
    overlay.insert(_entry!);
    Haptics.success();
  }

  static void _remove() {
    _entry?.remove();
    _entry = null;
  }
}

class _LetterBannerView extends StatefulWidget {
  final LoveLetter letter;
  final VoidCallback onDone;
  final VoidCallback onOpen;

  const _LetterBannerView({required this.letter, required this.onDone, required this.onOpen});

  @override
  State<_LetterBannerView> createState() => _LetterBannerViewState();
}

class _LetterBannerViewState extends State<_LetterBannerView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _slide = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, .6, curve: Curves.easeOutBack),
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _seal = Tween(begin: 1.8, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(.45, 1, curve: Curves.elasticOut),
    ),
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 5600), _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _c.animateBack(0, duration: const Duration(milliseconds: 320));
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final top = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -(top + 120) * (1 - _slide.value)),
          child: Transform.rotate(angle: -0.012 * _slide.value, child: child),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            onTap: _closing ? null : widget.onOpen,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -150) _close();
            },
            child: Semantics(
              button: true,
              label: 'Letter from ${letter.name}: ${letter.text}',
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF4E9D3), LetterColors.envelopeSealed],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 26, offset: const Offset(0, 12)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CustomPaint(painter: EnvelopeLinesPainter(depth: .5))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                        child: Row(
                          children: [
                            ScaleTransition(scale: _seal, child: const WaxSeal(size: 46)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'A letter from ${letter.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: sophiaScript,
                                      fontSize: 25,
                                      height: 1.15,
                                      color: LetterColors.ink,
                                    ),
                                  ),
                                  Text(
                                    letter.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: sophiaHand,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      color: LetterColors.wine,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            PhotoStamp(imageUrl: letter.imageUrl, name: letter.name, width: 50, height: 60, angle: .1),
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
      ),
    );
  }
}

/// Opens a letter: the paper slides out of its envelope. Marks it read.
Future<void> showLoveLetter(BuildContext context, LoveLetter letter) {
  LoveLetters.instance.markRead(letter.id);
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close letter',
    barrierColor: const Color(0xD90A0504),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, _) => _LetterView(letter: letter),
    transitionBuilder: (ctx, anim, _, child) => BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 6 * anim.value, sigmaY: 6 * anim.value),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}

/// Opens her chat from a letter.
void writeBack(BuildContext context, LoveLetter letter) {
  NavigationService.navigateToScreen(
    context,
    ChatScreen(imageUrl: letter.imageUrl, name: letter.name, companionId: letter.companionId),
  );
}

class _LetterView extends StatefulWidget {
  final LoveLetter letter;
  const _LetterView({required this.letter});

  @override
  State<_LetterView> createState() => _LetterViewState();
}

class _LetterViewState extends State<_LetterView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  late final Animation<double> _out = CurvedAnimation(
    parent: _c,
    curve: const Interval(.15, 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final screen = MediaQuery.sizeOf(context);
    const pocketH = 118.0, overlap = 64.0, flapH = 78.0;
    // Paper fits the message; long ones scroll inside the maximum height.
    final textWidth = math.min(screen.width, 400.0) - 36 - 28 - 38;
    final measure = TextPainter(
      text: TextSpan(text: letter.text, style: _letterBody),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);
    final textH = measure.height;
    measure.dispose();
    final paperH = (16 + 72 + 8 + textH + 46 + overlap + 10)
        .clamp(300.0, math.min(screen.height * .56, 470.0))
        .toDouble();
    final stackH = paperH + pocketH - overlap;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: PetalFall(count: 10)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: stackH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: paperH - overlap - flapH,
                              height: flapH,
                              child: ClipPath(
                                clipper: FlapClipper(),
                                child: const ColoredBox(color: LetterColors.flap),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              top: 0,
                              bottom: pocketH / 2,
                              child: ClipRect(
                                child: AnimatedBuilder(
                                  animation: _out,
                                  builder: (context, child) => Transform.translate(
                                    offset: Offset(0, paperH * .7 * (1 - _out.value)),
                                    child: child,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      height: paperH,
                                      child: _FullPaper(letter: letter, bottomGap: overlap + 10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: pocketH,
                              child: _OpenPocket(letter: letter),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: paperH - overlap - 24,
                              child: const Center(child: WaxSeal(size: 48, faded: true)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (letter.canReply)
                        _WineButton(
                          label: 'Write back',
                          onTap: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            writeBack(nav.context, letter);
                          },
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: SophiaColors.muted, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _letterBody = TextStyle(
  fontFamily: sophiaHand,
  fontWeight: FontWeight.w500,
  fontSize: 22,
  height: 1.3,
  letterSpacing: 0,
  color: LetterColors.ink,
);

class _FullPaper extends StatelessWidget {
  final LoveLetter letter;
  final double bottomGap;
  const _FullPaper({required this.letter, required this.bottomGap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 18, bottomGap),
      decoration: BoxDecoration(
        color: LetterColors.paper,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    letterGreeting(context),
                    style: const TextStyle(
                      fontFamily: sophiaScript,
                      fontSize: 31,
                      height: 1.1,
                      color: LetterColors.ink,
                    ),
                  ),
                ),
              ),
              PhotoStamp(imageUrl: letter.imageUrl, name: letter.name, width: 54, height: 66, angle: .08),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(child: Text(letter.text, style: _letterBody)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— ${letter.name}',
              style: const TextStyle(fontFamily: sophiaScript, fontSize: 28, height: 1.2, color: LetterColors.wine),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenPocket extends StatelessWidget {
  final LoveLetter letter;
  const _OpenPocket({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LetterColors.envelope,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 34, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FROM',
                  style: TextStyle(
                    color: LetterColors.wine,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                Text(
                  letter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: sophiaSerif,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                    color: LetterColors.ink,
                  ),
                ),
                Text(letterTime(letter.time), style: const TextStyle(fontSize: 11.5, color: LetterColors.inkSoft)),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Opacity(opacity: .7, child: CustomPaint(painter: PostmarkPainter())),
          ),
        ],
      ),
    );
  }
}

class _WineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _WineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: Haptics.wrap(onTap),
        child: Container(
          height: 52,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const RadialGradient(
              center: Alignment(-0.4, -0.6),
              radius: 2.2,
              colors: [LetterColors.wineLight, LetterColors.wine],
            ),
            boxShadow: [
              BoxShadow(color: LetterColors.wine.withValues(alpha: .45), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
