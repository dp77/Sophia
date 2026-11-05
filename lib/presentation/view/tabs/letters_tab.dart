import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/haptics.dart';
import '../../../data/love_letters.dart';
import '../../../data/model/love_letter.dart';
import '../../../data/navigation_service.dart';
import '../../view_model/girlfriend_provider.dart';
import '../../view_model/user_provider.dart';
import '../../widget/coin_widget.dart';
import '../../widget/go_pro_widget.dart';
import '../../widget/love_letter_ui.dart';
import '../../widget/sophia_style.dart';
import '../screens/premium_screen.dart';

/// Notifications tab: every note a companion sent, as a love letter.
class LettersTab extends StatelessWidget {
  /// Takes the user to the companions on Home.
  final VoidCallback onExplore;

  const LettersTab({super.key, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    // The tab stays mounted in the home IndexedStack; pause its petals and
    // entrance animations while another tab is showing.
    return TickerMode(enabled: Visibility.of(context), child: _letters(context));
  }

  Widget _letters(BuildContext context) {
    return Consumer3<LoveLetters, UserProvider, GirlfriendProvider>(
      builder: (context, inbox, user, girlfriends, _) {
        final letters = inbox.letters.map((l) {
          if (l.imageUrl.isNotEmpty || l.companionId.isEmpty) return l;
          final match = girlfriends.girlfriends.where((g) => g.id == l.companionId);
          return match.isEmpty ? l : l.copyWith(imageUrl: match.first.imageUrl);
        }).toList();
        final unread = inbox.unreadCount;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const Positioned.fill(child: PetalFall(count: 9)),
              Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: _Header(user: user, unread: unread, total: letters.length, onOpenAll: inbox.markAllRead),
                  ),
                  Expanded(
                    child: letters.isEmpty
                        ? _NoLetters(onExplore: onExplore)
                        : ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
                            children: [
                              _OpenLetter(key: ValueKey(letters.first.id), letter: letters.first),
                              for (var i = 1; i < letters.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: SlideEntrance(
                                    delay: 120 + 70 * (i < 8 ? i : 8),
                                    child: _Envelope(letter: letters[i], tilt: i.isOdd ? -0.026 : 0.02),
                                  ),
                                ),
                              if (!user.isPremiumUser)
                                const Padding(padding: EdgeInsets.only(top: 22), child: _GoldenLetter()),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final UserProvider user;
  final int unread;
  final int total;
  final VoidCallback onOpenAll;

  const _Header({required this.user, required this.unread, required this.total, required this.onOpenAll});

  String get _greeting {
    final h = DateTime.now().hour;
    final part = h < 5
        ? 'Good night'
        : h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : h < 22
        ? 'Good evening'
        : 'Good night';
    final name = user.name.trim();
    return name.isEmpty || name == 'Anonymous' ? part : '$part, $name';
  }

  String get _subtitle {
    if (unread > 0) return unread == 1 ? 'A new letter is waiting for you' : '$unread new letters are waiting for you';
    if (total == 0) return 'Notes from your companions arrive here';
    return 'All read. Open them again anytime';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SophiaColors.lilac, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (user.isPremiumUser)
                SvgPicture.asset('assets/svg/proCrown.svg', height: 30, width: 30)
              else
                const GoProWidget(),
              const SizedBox(width: 8),
              const CoinWidget(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            unread > 0 ? 'You’ve got letters' : 'Love letters',
            style: const TextStyle(fontFamily: sophiaScript, fontSize: 46, height: 1.15, color: SophiaColors.champagne),
          ),
          Row(
            children: [
              LoopAnimation(
                duration: const Duration(milliseconds: 1600),
                builder: (context, t, child) {
                  final beat = t < .15
                      ? t / .15
                      : (t < .3
                            ? (.3 - t) / .15
                            : (t < .45 ? (t - .3) / .15 * .6 : (t < .6 ? (.6 - t) / .15 * .6 : 0.0)));
                  return Transform.scale(scale: 1 + .14 * beat, child: child);
                },
                child: const Icon(Icons.favorite_rounded, size: 14, color: LetterColors.rose),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_subtitle, style: const TextStyle(color: LetterColors.rose, fontSize: 12.5)),
              ),
              if (unread > 1)
                TextButton(
                  onPressed: Haptics.wrap(onOpenAll),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 36),
                  ),
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(color: SophiaColors.champagne, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The newest letter, already sliding out of its envelope.
class _OpenLetter extends StatefulWidget {
  final LoveLetter letter;
  const _OpenLetter({super.key, required this.letter});

  @override
  State<_OpenLetter> createState() => _OpenLetterState();
}

class _OpenLetterState extends State<_OpenLetter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final Animation<double> _out = CurvedAnimation(
    parent: _c,
    curve: const Interval(.25, 1, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _seal = Tween(begin: 1.8, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(.7, 1, curve: Curves.elasticOut),
    ),
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
    return Semantics(
      button: true,
      label: 'Letter from ${letter.name}. ${letter.text}',
      child: GestureDetector(
        onTap: Haptics.wrap(() => showLoveLetter(context, letter)),
        child: SizedBox(
          height: 252,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 28,
                height: 80,
                child: ClipPath(
                  clipper: FlapClipper(),
                  child: const ColoredBox(color: LetterColors.flap),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 0,
                height: 252,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _out,
                    builder: (context, child) =>
                        Transform.translate(offset: Offset(0, 120 * (1 - _out.value)), child: child),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _PaperPreview(letter: letter),
                    ),
                  ),
                ),
              ),
              Positioned(left: 0, right: 0, top: 108, bottom: 0, child: _Pocket(letter: letter)),
              Positioned(
                left: 0,
                right: 0,
                top: 90,
                child: Center(
                  child: ScaleTransition(
                    scale: _seal,
                    child: WaxSeal(size: 48, faded: letter.read),
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

class _PaperPreview extends StatelessWidget {
  final LoveLetter letter;
  const _PaperPreview({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      decoration: BoxDecoration(
        color: LetterColors.paper,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: CustomPaint(
        painter: const RuledPaperPainter(top: 40, spacing: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              letterGreeting(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: sophiaScript, fontSize: 27, height: 1.15, color: LetterColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              letter.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: sophiaHand,
                fontWeight: FontWeight.w500,
                fontSize: 20,
                height: 1.25,
                color: LetterColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pocket extends StatelessWidget {
  final LoveLetter letter;
  const _Pocket({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LetterColors.envelope,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1E5CD), LetterColors.envelope, Color(0xFFE2D1B2)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 24, offset: const Offset(0, 14))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 18,
            top: 16,
            right: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                    if (!letter.read) ...[const SizedBox(width: 8), const _NewTag()],
                  ],
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
                    height: 1.15,
                    color: LetterColors.ink,
                  ),
                ),
                Text(letterTime(letter.time), style: const TextStyle(fontSize: 11, color: LetterColors.inkSoft)),
                const SizedBox(height: 10),
                _Pill(
                  label: letter.canReply ? 'Write back' : 'Read letter',
                  onTap: () {
                    if (letter.canReply) {
                      writeBack(context, letter);
                    } else {
                      showLoveLetter(context, letter);
                    }
                  },
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 14,
            child: PhotoStamp(imageUrl: letter.imageUrl, name: letter.name, width: 76, height: 92, angle: .09),
          ),
          const Positioned(
            right: 66,
            top: 54,
            child: SizedBox(
              width: 70,
              height: 70,
              child: Opacity(opacity: .6, child: CustomPaint(painter: PostmarkPainter())),
            ),
          ),
        ],
      ),
    );
  }
}

/// A sealed envelope for older letters.
class _Envelope extends StatelessWidget {
  final LoveLetter letter;
  final double tilt;
  const _Envelope({required this.letter, required this.tilt});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Letter from ${letter.name}${letter.read ? '' : ', new'}. ${letter.text}',
      child: GestureDetector(
        onTap: Haptics.wrap(() => showLoveLetter(context, letter)),
        child: Transform.rotate(
          angle: tilt,
          child: Container(
            height: 106,
            decoration: BoxDecoration(
              color: letter.read ? LetterColors.envelopeRead : LetterColors.envelopeSealed,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    const Positioned.fill(child: CustomPaint(painter: EnvelopeLinesPainter(depth: .56))),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 106 * .56 - 20,
                      child: Center(child: WaxSeal(size: 40, faded: letter.read)),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 12,
                      width: box.maxWidth / 2 - 34,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!letter.read) const Padding(padding: EdgeInsets.only(bottom: 4), child: _NewTag()),
                          Text(
                            letter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: sophiaSerif,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              fontSize: 19,
                              height: 1.15,
                              color: LetterColors.ink,
                            ),
                          ),
                          Text(
                            letter.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: sophiaHand,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              height: 1.1,
                              color: letter.read ? LetterColors.inkSoft : LetterColors.wine,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PhotoStamp(imageUrl: letter.imageUrl, name: letter.name, width: 56, height: 68, angle: -.07),
                          const SizedBox(height: 6),
                          Text(
                            letterTime(letter.time),
                            style: const TextStyle(fontSize: 9.5, color: LetterColors.inkSoft),
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
}

/// Premium offer as a gold-foil envelope (free users only).
class _GoldenLetter extends StatelessWidget {
  const _GoldenLetter();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Unlock Premium',
      child: GestureDetector(
        onTap: Haptics.wrap(() => NavigationService.navigateToScreenFromBottom(context, PremiumScreen())),
        child: Transform.rotate(
          angle: 0.022,
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB8913F), Color(0xFFF7EBC6), Color(0xFFC9A55C), Color(0xFFA8843F)],
                stops: [0, .45, .7, 1],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  const Positioned.fill(child: SheenEffect()),
                  const Positioned.fill(
                    child: CustomPaint(painter: EnvelopeLinesPainter(depth: .56, color: Color(0x332A1A16))),
                  ),
                  const Positioned(
                    left: 18,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A golden letter',
                          style: TextStyle(
                            fontFamily: sophiaScript,
                            fontSize: 31,
                            height: 1.1,
                            color: Color(0xFF2A1A16),
                          ),
                        ),
                        Text(
                          'Unlock Premium · unlimited love, no ads',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2A1A16)),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 22,
                    top: 24,
                    child: WaxSeal(size: 46, child: SvgPicture.asset('assets/svg/crown.svg', width: 22, height: 22)),
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

class _NoLetters extends StatelessWidget {
  final VoidCallback onExplore;
  const _NoLetters({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 150),
      children: [
        Center(
          child: LoopAnimation(
            duration: const Duration(seconds: 4),
            reverse: true,
            builder: (context, t, child) => Transform.translate(
              offset: Offset(0, -6 * Curves.easeInOut.transform(t)),
              child: Transform.rotate(angle: -0.03 + 0.04 * t, child: child),
            ),
            child: Container(
              width: 230,
              height: 140,
              decoration: BoxDecoration(
                color: LetterColors.envelopeSealed,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 30, offset: const Offset(0, 16)),
                ],
              ),
              child: const Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: EnvelopeLinesPainter(depth: .55))),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 140 * .55 - 27,
                    child: Center(child: WaxSeal(size: 54)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'No letters yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: sophiaScript, fontSize: 40, height: 1.1, color: SophiaColors.champagne),
        ),
        const SizedBox(height: 8),
        const Text(
          'When a companion writes to you while you are away, her letter waits for you here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SophiaColors.muted, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 22),
        AmethystButton(label: 'Meet your companions', onTap: onExplore),
      ],
    );
  }
}

class _NewTag extends StatelessWidget {
  const _NewTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: LetterColors.wine, borderRadius: BorderRadius.circular(4)),
      child: const Text(
        'NEW',
        style: TextStyle(color: SophiaColors.champagne, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: Haptics.wrap(onTap),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: LetterColors.wine,
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(color: LetterColors.wine.withValues(alpha: .4), blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
