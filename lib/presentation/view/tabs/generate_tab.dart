import 'dart:math' as math;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/data/model/charcter_model.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view_model/user_character_provider.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/widget/coin_widget.dart';
import 'package:girlfriend/presentation/widget/go_pro_widget.dart';
import 'package:girlfriend/presentation/widget/loading_indicator.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:provider/provider.dart';
import '../../widget/sophia_style.dart';
import '../screens/chat_screen.dart';
import '../screens/create_girlfriend_flow_screen.dart';

class GenerateTab extends StatefulWidget {
  const GenerateTab({super.key});

  @override
  State<GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends State<GenerateTab> {
  void _openCreate() {
    NavigationService.navigateToScreen(
      context,
      const CreateGirlfriendFlowScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: SophiaColors.background),
      child: Consumer<UserCharacterProvider>(
        builder: (context, provider, _) {
          final characters = provider.characterList;
          final showEmpty = !provider.loading && characters.isEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SlideEntrance(delay: 50, child: _Header()),
              if (!showEmpty && !provider.loading)
                SlideEntrance(
                  delay: 180,
                  child: _CreateCard(onTap: _openCreate),
                ),
              Expanded(
                child: SlideEntrance(
                  delay: 320,
                  child: _Panel(
                    margin: EdgeInsets.only(top: showEmpty ? 0 : 20),
                    child: provider.loading
                        ? const LoadingIndicator(isLoading: true)
                        : showEmpty
                        ? _EmptyState(onCreate: _openCreate)
                        : _PartnerGrid(
                            characters: characters,
                            onAdd: _openCreate,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header (same structure as Home tab) ────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final isPremium = context.select<UserProvider, bool>(
      (p) => p.isPremiumUser,
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'YOUR AI PARTNERS',
                  style: TextStyle(
                    color: SophiaColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                if (isPremium)
                  SvgPicture.asset(
                    'assets/svg/proCrown.svg',
                    height: 30,
                    width: 30,
                  )
                else
                  const GoProWidget(),
                const SizedBox(width: 8),
                const CoinWidget(),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Customize Your AI Partner',
              style: TextStyle(
                color: SophiaColors.lavender,
                fontSize: 31,
                fontWeight: FontWeight.w400,
                fontFamily: sophiaScript,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create card ────────────────────────────────────────────────────────────
class _CreateCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: SophiaColors.amethyst,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8C2F3C).withValues(alpha: 0.9),
              blurRadius: 40,
              spreadRadius: -18,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              Positioned(
                right: -58,
                bottom: -86,
                child: LoopAnimation(
                  duration: const Duration(seconds: 26),
                  builder: (_, t, child) =>
                      Transform.rotate(angle: t * 2 * math.pi, child: child),
                  child: CustomPaint(
                    size: const Size(210, 210),
                    painter: _DashedCirclePainter(
                      color: SophiaColors.champagne.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -14,
                bottom: -44,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: SheenEffect()),
              const Positioned(left: 210, top: 14, child: _Twinkle(size: 5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Meet Your Perfect AI Match',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Craft a virtual friend that thinks, talks, and connects exactly how you want.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const _PulsingPlus(size: 45, ringColor: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        _StepChip('Look vibe'),
                        SizedBox(width: 6),
                        _StepChip('Personality'),
                        SizedBox(width: 6),
                        _StepChip('Relationship'),
                      ],
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
}

class _StepChip extends StatelessWidget {
  final String text;
  const _StepChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SophiaColors.bgTop.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Rounded-top panel (same shape as Home tab, refined border) ────────────
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _Panel({required this.child, required this.margin});

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(38),
    topRight: Radius.circular(38),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: _radius,
        border: GradientBoxBorder(
          gradient: LinearGradient(
            colors: [
              SophiaColors.lilac.withValues(alpha: 0),
              SophiaColors.lilac.withValues(alpha: 0.75),
              SophiaColors.lilac.withValues(alpha: 0),
            ],
          ),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SophiaColors.panelTop, SophiaColors.bgBottom],
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
      child: ClipRRect(borderRadius: _radius, child: child),
    );
  }
}

// ── Grid of created partners ───────────────────────────────────────────────
class _PartnerGrid extends StatelessWidget {
  final List<CharacterModel> characters;
  final VoidCallback onAdd;
  const _PartnerGrid({required this.characters, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                LoopAnimation(
                  duration: const Duration(seconds: 3),
                  reverse: true,
                  builder: (_, t, child) =>
                      Opacity(opacity: 0.35 + 0.45 * t, child: child),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: SophiaColors.champagne,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: SophiaColors.champagne,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Your Creations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${characters.length}',
                  style: const TextStyle(
                    color: SophiaColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final delay = 460 + math.min(index, 6) * 90;
              if (index == characters.length) {
                return SlideEntrance(
                  delay: delay,
                  child: _AddPartnerTile(onTap: onAdd),
                );
              }
              return SlideEntrance(
                delay: delay,
                child: _PartnerCard(character: characters[index]),
              );
            }, childCount: characters.length + 1),
          ),
        ),
      ],
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final CharacterModel character;
  const _PartnerCard({required this.character});

  @override
  Widget build(BuildContext context) {
    final traits = character.traits.take(2).toList();
    return Pressable(
      onTap: () => NavigationService.navigateToScreen(
        context,
        ChatScreen(
          imageUrl: character.imageUrl,
          name: character.characterName,
          companionId: character.id,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: SophiaColors.lilac.withValues(alpha: 0.28),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.9),
              blurRadius: 30,
              spreadRadius: -18,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: character.imageUrl,
                alignment: Alignment.topCenter,
                fit: BoxFit.cover,
                progressIndicatorBuilder: (context, child, progress) =>
                    Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Center(
                        child: ExpressiveLoadingIndicator(color: Colors.white),
                      ),
                    ),
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.white.withValues(alpha: 0.05),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 28,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.46, 1],
                      colors: [
                        SophiaColors.panelTop.withValues(alpha: 0),
                        SophiaColors.panelTop.withValues(alpha: 0.5),
                        SophiaColors.panelTop.withValues(alpha: 0.96),
                      ],
                    ),
                  ),
                ),
              ),
              if (character.relationshipType.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: SophiaColors.bgTop.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: SophiaColors.champagne.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 10,
                          color: SophiaColors.champagne,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          character.relationshipType,
                          style: const TextStyle(
                            color: SophiaColors.champagne,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 8,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${character.characterName}, ${character.age}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              fontFamily: sophiaSerif,
                            ),
                          ),
                          if (traits.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                for (final trait in traits)
                                  Flexible(
                                    child: Container(
                                      height: 19,
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        trait,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5E1C27), Color(0xFFA8434F)],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/svg/nav_chat.svg',
                        width: 18,
                        height: 18,
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
}

class _AddPartnerTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPartnerTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: SophiaColors.lilac.withValues(alpha: 0.38),
          radius: 24,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoopAnimation(
                duration: const Duration(seconds: 5),
                reverse: true,
                builder: (_, t, child) => Transform.translate(
                  offset: Offset(0, -6 * Curves.easeInOut.transform(t)),
                  child: child,
                ),
                child: const _PulsingPlus(
                  size: 48,
                  ringColor: SophiaColors.lilac,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Add Partner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'New look, new vibe',
                style: TextStyle(
                  color: SophiaColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 0.7,
          colors: [
            const Color(0xFFA8434F).withValues(alpha: 0.3),
            const Color(0xFFA8434F).withValues(alpha: 0),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 130),
        child: Column(
          children: [
            const SlideEntrance(delay: 340, child: _FloatingCards()),
            const SizedBox(height: 18),
            const SlideEntrance(
              delay: 500,
              child: Column(
                children: [
                  Text(
                    'Meet Your Perfect AI Match',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SophiaColors.lavender,
                      fontSize: 31,
                      fontWeight: FontWeight.w400,
                      fontFamily: sophiaScript,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Craft a virtual friend that thinks, talks, and connects exactly how you want.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SophiaColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SlideEntrance(
              delay: 640,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _NumberedStep(1, 'Look vibe'),
                  _NumberedStep(2, 'Personality'),
                  _NumberedStep(3, 'Relationship'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SlideEntrance(
              delay: 800,
              child: Pressable(
                onTap: onCreate,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: SophiaColors.amethyst,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8C2F3C).withValues(alpha: 0.95),
                        blurRadius: 34,
                        spreadRadius: -14,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: const Stack(
                      children: [
                        Positioned.fill(child: SheenEffect(widthFactor: 0.3)),
                        Center(
                          child: Text(
                            'Create Your Partner',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
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
      ),
    );
  }
}

class _FloatingCards extends StatelessWidget {
  const _FloatingCards();

  Widget _ghost() => CustomPaint(
    painter: _DashedRRectPainter(
      color: SophiaColors.lilac.withValues(alpha: 0.38),
      radius: 24,
    ),
    child: Container(
      width: 118,
      height: 166,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );

  Widget _float({
    required double baseAngle,
    required double extraAngle,
    required double lift,
    required int ms,
    required Widget child,
  }) {
    return LoopAnimation(
      duration: Duration(milliseconds: ms),
      reverse: true,
      builder: (_, t, c) {
        final e = Curves.easeInOut.transform(t);
        return Transform.translate(
          offset: Offset(0, -lift * e),
          child: Transform.rotate(
            angle: (baseAngle + extraAngle * e) * math.pi / 180,
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 236,
      child: Stack(
        children: [
          const Positioned(left: 8, top: 8, child: _Twinkle(size: 5)),
          const Positioned(
            right: 14,
            top: 40,
            child: _Twinkle(
              size: 4,
              color: SophiaColors.lavender,
              delayFraction: 0.3,
            ),
          ),
          const Positioned(
            right: 60,
            bottom: 6,
            child: _Twinkle(size: 5, delayFraction: 0.6),
          ),
          Positioned(
            left: 22,
            top: 26,
            child: _float(
              baseAngle: -10,
              extraAngle: -2,
              lift: 8,
              ms: 3000,
              child: _ghost(),
            ),
          ),
          Positioned(
            right: 22,
            top: 26,
            child: _float(
              baseAngle: 10,
              extraAngle: 2,
              lift: 8,
              ms: 3400,
              child: _ghost(),
            ),
          ),
          Positioned(
            left: 77,
            top: 0,
            child: _float(
              baseAngle: 0,
              extraAngle: 0,
              lift: 10,
              ms: 2500,
              child: Container(
                width: 146,
                height: 206,
                decoration: BoxDecoration(
                  gradient: SophiaColors.amethyst,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8C2F3C).withValues(alpha: 0.95),
                      blurRadius: 50,
                      spreadRadius: -18,
                      offset: const Offset(0, 26),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: const Stack(
                    children: [
                      Positioned.fill(child: SheenEffect(widthFactor: 0.45)),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulsingPlus(size: 56, ringColor: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Your partner',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
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
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String text;
  const _NumberedStep(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.only(left: 4, right: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: SophiaColors.lilac.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SophiaColors.champagne.withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: SophiaColors.champagne,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Motion helpers ─────────────────────────────────────────────────────────

/// The app's plus.svg with a soft ring pulsing outward.
class _PulsingPlus extends StatelessWidget {
  final double size;
  final Color ringColor;
  const _PulsingPlus({required this.size, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LoopAnimation(
            duration: const Duration(milliseconds: 2400),
            builder: (_, t, _) => Transform.scale(
              scale: 1 + 0.45 * Curves.easeOut.transform(t),
              child: Opacity(
                opacity: 0.55 * (1 - t),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            ),
          ),
          SvgPicture.asset('assets/svg/plus.svg', width: size, height: size),
        ],
      ),
    );
  }
}

class _Twinkle extends StatelessWidget {
  final double size;
  final Color color;
  final double delayFraction;
  const _Twinkle({
    required this.size,
    this.color = SophiaColors.champagne,
    this.delayFraction = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LoopAnimation(
      duration: const Duration(milliseconds: 1300),
      reverse: true,
      initial: delayFraction,
      builder: (_, t, child) => Opacity(
        opacity: 0.25 + 0.75 * t,
        child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 10)],
        ),
      ),
    );
  }
}

// ── Painters ───────────────────────────────────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    const dashes = 60;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(0.5), i * sweep, sweep * 0.5, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
