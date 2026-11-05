import 'dart:math' as math;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/chat_screen.dart';
import 'package:girlfriend/presentation/view_model/chat_list_provider.dart';
import 'package:girlfriend/data/db/database_helper.dart';
import 'package:girlfriend/presentation/widget/coin_widget.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:provider/provider.dart';

import '../../view_model/user_provider.dart';
import '../../widget/go_pro_widget.dart';
import '../../widget/sophia_skeleton.dart';
import '../../widget/sophia_style.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  static const _panelRadius = BorderRadius.only(
    topLeft: Radius.circular(38),
    topRight: Radius.circular(38),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: SophiaColors.background),
      child: Stack(
        children: [
          const Positioned.fill(child: _AmbientOrbs()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SlideEntrance(
                delay: 50,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'YOUR CONVERSATIONS',
                              style: TextStyle(
                                color: SophiaColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const Spacer(),
                            Selector<UserProvider, bool>(
                              selector: (_, userProvider) =>
                                  userProvider.isPremiumUser,
                              builder: (context, isPremiumUser, _) {
                                return isPremiumUser
                                    ? SvgPicture.asset(
                                        'assets/svg/proCrown.svg',
                                        height: 30,
                                        width: 30,
                                      )
                                    : const GoProWidget();
                              },
                            ),
                            const SizedBox(width: 8),
                            const CoinWidget(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const _ShimmerTitle('Chats'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SlideEntrance(
                  delay: 180,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: _panelRadius,
                      border: GradientBoxBorder(
                        gradient: LinearGradient(
                          colors: [
                            SophiaColors.lilac.withValues(alpha: 0),
                            SophiaColors.lilac.withValues(alpha: 0.75),
                            SophiaColors.lilac.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          SophiaColors.panelTop.withValues(alpha: 0.88),
                          SophiaColors.bgBottom.withValues(alpha: 0.94),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: -10,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: _panelRadius,
                      child: Consumer<ChatListProvider>(
                        builder: (context, chatList, _) {
                          final chats = chatList.chats;
                          if (chatList.loading && chats.isEmpty) {
                            return const ChatListSkeleton();
                          }
                          if (chats.isEmpty) {
                            return const _EmptyChats();
                          }
                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: chats.length,
                            cacheExtent: 2000,
                            padding: const EdgeInsets.fromLTRB(14, 18, 14, 120),
                            itemBuilder: (context, index) {
                              final chat = chats[index];
                              final name = chat.girlfriendName;
                              final lastText = chat.lastText;
                              final imageUrl = chat.imageUrl.isNotEmpty
                                  ? chat.imageUrl
                                  : null;
                              return _RowEntrance(
                                delay: 260 + math.min(index, 8) * 70,
                                child: FutureBuilder<String?>(
                                  future: DatabaseHelper().getCachedLastMessageRole(
                                    chat.companionId,
                                  ),
                                  builder: (context, snap) {
                                    final showTick =
                                        snap.data?.toLowerCase() == 'user';
                                    return ChatTile(
                                      gfId: chat.companionId,
                                      name: name,
                                      lastMessage: lastText.isEmpty
                                          ? 'Start chatting now!'
                                          : lastText,
                                      imageUrl: imageUrl,
                                      showSentTick: showTick,
                                      time: chat.time,
                                      isLatest: index == 0,
                                      onTap: () {
                                        NavigationService.navigateToScreen(
                                          context,
                                          ChatScreen(
                                            imageUrl:
                                                imageUrl ??
                                                ChatTile.placeholderImageUrl,
                                            name: name,
                                            companionId: chat.companionId,
                                          ),
                                        );
                                      },
                                      isLast:
                                          index == chats.length - 1,
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatTile extends StatelessWidget {
  final String gfId;
  final String name;
  final String lastMessage;
  final String? imageUrl;
  final bool showSentTick;
  final VoidCallback onTap;
  final bool isLast;
  final int time;
  final bool isLatest;

  const ChatTile({
    super.key,
    required this.gfId,
    required this.name,
    required this.lastMessage,
    this.imageUrl,
    required this.onTap,
    this.showSentTick = false,
    required this.isLast,
    this.time = 0,
    this.isLatest = false,
  });

  static const String placeholderImageUrl =
      'https://sin1.contabostorage.com/292910c350ea4c699a44f11998b096be:my-storage-bucket/ai_companion/app/gallery/1.webp';

  /// [epochSeconds] → "now", "5m", "3h", "Yesterday", weekday, or "12 Oct".
  static String _formatTime(int epochSeconds) {
    if (epochSeconds <= 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final days = today.difference(day).inDays;
    if (days == 0) return '${diff.inHours}h';
    if (days == 1) return 'Yesterday';
    if (days < 7)
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday -
          1];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${t.day} ${months[t.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(time);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isLatest ? 0.07 : 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLatest
                  ? SophiaColors.champagne.withValues(alpha: 0.35)
                  : SophiaColors.lilac.withValues(alpha: 0.16),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isLatest)
                  const Positioned.fill(child: SheenEffect(widthFactor: 0.25)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _Avatar(imageUrl: imageUrl, glowing: isLatest),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: sophiaSerif,
                                    ),
                                  ),
                                ),
                                if (timeLabel.isNotEmpty)
                                  Text(
                                    timeLabel,
                                    style: TextStyle(
                                      color: isLatest
                                          ? SophiaColors.champagne
                                          : SophiaColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (showSentTick) ...[
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 450),
                                    curve: Curves.easeOutBack,
                                    builder: (_, v, child) =>
                                        Transform.scale(scale: v, child: child),
                                    child: const Icon(
                                      Icons.done_all_rounded,
                                      color: SophiaColors.lilac,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: SophiaColors.muted,
                                      fontSize: 12.5,
                                      height: 1.3,
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final bool glowing;
  const _Avatar({required this.imageUrl, required this.glowing});

  @override
  Widget build(BuildContext context) {
    final photo = Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: glowing
            ? Colors.transparent
            : SophiaColors.lilac.withValues(alpha: 0.25),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: SophiaColors.panelTop,
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: (imageUrl != null && imageUrl!.isNotEmpty)
                ? imageUrl!
                : ChatTile.placeholderImageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (_, _) => Container(
              color: Colors.white.withValues(alpha: 0.05),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SophiaColors.lilac,
                  ),
                ),
              ),
            ),
            errorBuilder: (_, _, _) => Container(
              color: Colors.white.withValues(alpha: 0.05),
              child: const Icon(
                Icons.person_rounded,
                color: SophiaColors.muted,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
    if (!glowing) return photo;
    final ringed = Stack(
      alignment: Alignment.center,
      children: [
        LoopAnimation(
          duration: const Duration(seconds: 4),
          builder: (_, t, child) =>
              Transform.rotate(angle: t * 2 * math.pi, child: child),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  SophiaColors.champagne,
                  SophiaColors.orchid,
                  SophiaColors.lilac,
                  SophiaColors.champagne,
                ],
              ),
            ),
          ),
        ),
        photo,
      ],
    );
    return LoopAnimation(
      duration: const Duration(seconds: 3),
      reverse: true,
      builder: (_, t, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: SophiaColors.champagne.withValues(alpha: 0.15 + 0.25 * t),
              blurRadius: 12 + 8 * t,
            ),
          ],
        ),
        child: child,
      ),
      child: ringed,
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 0.7,
          colors: [
            SophiaColors.orchid.withValues(alpha: 0.28),
            SophiaColors.orchid.withValues(alpha: 0),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
          child: Column(
            children: [
              SlideEntrance(
                delay: 300,
                child: SizedBox(
                  width: 200,
                  height: 150,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: 30,
                        child: _bubble(
                          width: 96,
                          height: 56,
                          left: true,
                          faded: true,
                          ms: 3400,
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 4,
                        child: _bubble(
                          width: 110,
                          height: 62,
                          left: false,
                          faded: false,
                          ms: 2800,
                        ),
                      ),
                      Positioned(left: 44, bottom: 0, child: _typingBubble()),
                      const Positioned(
                        right: 30,
                        bottom: 26,
                        child: _Twinkle(size: 5),
                      ),
                      const Positioned(
                        left: 6,
                        top: 6,
                        child: _Twinkle(size: 4, phase: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SlideEntrance(
                delay: 440,
                child: Column(
                  children: [
                    Text(
                      'Start Your First Conversation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SophiaColors.lavender,
                        fontSize: 25,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        fontFamily: sophiaSerif,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Your AI companion is waiting to meet you!\nStart chatting and build an amazing connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SophiaColors.muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bubble({
    required double width,
    required double height,
    required bool left,
    required bool faded,
    required int ms,
  }) {
    return LoopAnimation(
      duration: Duration(milliseconds: ms),
      reverse: true,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(t)),
        child: child,
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: faded ? null : SophiaColors.amethyst,
          color: faded ? Colors.white.withValues(alpha: 0.05) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(left ? 6 : 22),
            bottomRight: Radius.circular(left ? 22 : 6),
          ),
          border: Border.all(
            color: faded
                ? SophiaColors.lilac.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.3),
          ),
          boxShadow: faded
              ? null
              : [
                  BoxShadow(
                    color: SophiaColors.amethystMid.withValues(alpha: 0.9),
                    blurRadius: 30,
                    spreadRadius: -12,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 6,
              width: width * 0.6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: faded ? 0.18 : 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 7),
            Container(
              height: 6,
              width: width * 0.38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: faded ? 0.12 : 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _typingBubble() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SophiaColors.champagne.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            LoopAnimation(
              duration: const Duration(milliseconds: 1200),
              initial: i / 3,
              builder: (_, t, child) {
                final y = math.sin(t * 2 * math.pi);
                return Transform.translate(
                  offset: Offset(0, -3 * math.max(0.0, y)),
                  child: Opacity(
                    opacity: 0.45 + 0.55 * math.max(0.0, y),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: SophiaColors.champagne,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Twinkle extends StatelessWidget {
  final double size;
  final double phase;
  const _Twinkle({required this.size, this.phase = 0});

  @override
  Widget build(BuildContext context) {
    return LoopAnimation(
      duration: const Duration(milliseconds: 1300),
      reverse: true,
      initial: phase,
      builder: (_, t, child) => Opacity(opacity: 0.25 + 0.75 * t, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: SophiaColors.champagne,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: SophiaColors.champagne, blurRadius: size * 2),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a chat row in from the right.
class _RowEntrance extends StatefulWidget {
  final int delay;
  final Widget child;
  const _RowEntrance({required this.delay, required this.child});

  @override
  State<_RowEntrance> createState() => _RowEntranceState();
}

class _RowEntranceState extends State<_RowEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

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
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(40 * (1 - _curve.value), 0),
          child: child,
        ),
      ),
    );
  }
}

/// Title with a slow champagne light passing through the letters.
class _ShimmerTitle extends StatelessWidget {
  final String text;
  const _ShimmerTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return LoopAnimation(
      duration: const Duration(milliseconds: 3600),
      builder: (_, t, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) {
          final x = -1.0 + 3.0 * t;
          return LinearGradient(
            begin: Alignment(x - 0.6, 0),
            end: Alignment(x + 0.6, 0),
            colors: const [
              SophiaColors.lavender,
              SophiaColors.champagne,
              SophiaColors.lavender,
            ],
          ).createShader(rect);
        },
        child: child,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          fontFamily: sophiaSerif,
        ),
      ),
    );
  }
}

/// Two soft orchid glows drifting slowly behind the screen.
class _AmbientOrbs extends StatelessWidget {
  const _AmbientOrbs();

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final topOrb = _orb(260, SophiaColors.orchid.withValues(alpha: 0.28));
    final bottomOrb = _orb(
      220,
      SophiaColors.amethystMid.withValues(alpha: 0.18),
    );
    return IgnorePointer(
      child: LoopAnimation(
        duration: const Duration(seconds: 12),
        reverse: true,
        builder: (_, t, _) {
          final e = Curves.easeInOut.transform(t);
          return Stack(
            children: [
              Positioned(
                right: -80 + 40 * e,
                top: -60 + 50 * e,
                child: topOrb,
              ),
              Positioned(
                left: -100 + 30 * e,
                top: 260 - 40 * e,
                child: bottomOrb,
              ),
            ],
          );
        },
      ),
    );
  }
}
