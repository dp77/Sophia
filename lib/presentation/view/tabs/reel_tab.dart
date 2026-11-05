import 'package:girlfriend/core/haptics.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/widget/custom_bottomsheet.dart';
import 'package:girlfriend/presentation/widget/profile_widget.dart';
import 'package:girlfriend/presentation/widget/video_player_widget.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import '../../../data/api_service/api_caller.dart';
import '../../../data/model/reel_model.dart';
import '../../../data/navigation_service.dart';
import '../../view_model/girlfriend_provider.dart';
import '../../widget/coin_widget.dart';
import '../../widget/go_pro_widget.dart';
import '../../widget/sophia_style.dart';
import '../screens/chat_screen.dart';

class ReelTab extends StatefulWidget {
  final ReelsData reelsData;
  const ReelTab({super.key, required this.reelsData});

  @override
  State<ReelTab> createState() => _ReelTabState();
}

class _ReelTabState extends State<ReelTab> {
  final _descriptionController = TextEditingController();
  ReelItem? _currentReel;
  int _index = 0;
  ApiCaller apiCaller = ApiCaller();

  Future<void> reportReel(String reelId, String gfId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bool isConnected = await InternetConnection().hasInternetAccess;
    if (!isConnected) {
      SophiaToast.show(
        msg:
            "No internet connection. Please check your connection and try again.",
      );
      return;
    }
    final result = await apiCaller.reportReels(
      reelId,
      gfId,
      userProvider.id,
      _descriptionController.text.trim(),
    );
    result.fold(
      (failure) {
        if (mounted) {
          SophiaToast.show(msg: failure.errMessage);
          Navigator.pop(context);
        }
      },
      (response) {
        if (mounted) {
          final data = response.data;
          if (data['status'] == true) {
            SophiaToast.show(msg: 'Reel reported successfully');
            Navigator.pop(context);
            _descriptionController.clear();
          } else {
            SophiaToast.show(msg: 'Something went wrong');
          }
        }
      },
    );
  }

  void _openChat(BuildContext context, ReelItem reel) {
    final girlfriendProvider = context.read<GirlfriendProvider>();
    NavigationService.navigateToScreen(
      context,
      ChatScreen(
        imageUrl: girlfriendProvider.getGirlfriendImageUrlById(reel.gfid) ?? '',
        name: girlfriendProvider.getGirlfriendNameById(reel.gfid) ?? '',
        companionId: reel.gfid,
      ),
    );
  }

  void _openReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // IMPORTANT
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CustomBottomSheet(
          title: 'Report',
          subtitle:
              'We\'re committed to improving your experience and would greatly appreciate it if you could share your feedback.',
          hint:
              'Please elaborate your reason for reporting. (E.g. unexpected behaviour, violence, inappropriate content etc.)',
          controller: _descriptionController,
          onTap: () {
            if (_currentReel != null) {
              if (_descriptionController.text.isEmpty) {
                SophiaToast.show(msg: 'Please write your feedback.');
              } else {
                reportReel(_currentReel!.reelId, _currentReel!.gfid);
              }
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.reelsData.reels.length;
    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: total,
          onPageChanged: (index) {
            Haptics.selection();
            setState(() {
              _index = index;
              _currentReel = widget.reelsData.reels[index];
            });
          },
          itemBuilder: (context, index) {
            final reels = widget.reelsData.reels[index];
            if (index == 0) _currentReel ??= reels;
            return _buildReelCard(context, reels);
          },
        ),
        // ── Top bar ────────────────────────────────────────────────────
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            ignoring: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SophiaColors.bgTop.withValues(alpha: 0.85),
                    SophiaColors.bgTop.withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Text(
                        'Reels',
                        style: TextStyle(
                          color: SophiaColors.lavender,
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          fontFamily: sophiaSerif,
                        ),
                      ),
                      const Spacer(),
                      Selector<UserProvider, bool>(
                        selector: (p0, userProvider) =>
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── Swipe-up hint on the first reel ────────────────────────────
        if (_index == 0 && total > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 112,
            child: IgnorePointer(
              child: Center(
                child: LoopAnimation(
                  duration: const Duration(milliseconds: 1400),
                  reverse: true,
                  builder: (_, t, child) => Transform.translate(
                    offset: Offset(0, -6 * Curves.easeInOut.transform(t)),
                    child: Opacity(opacity: 0.5 + 0.5 * t, child: child),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: SophiaColors.champagne,
                        size: 22,
                      ),
                      Text(
                        'Swipe up',
                        style: TextStyle(
                          color: SophiaColors.champagne,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReelCard(BuildContext context, ReelItem reels) {
    final name =
        context.watch<GirlfriendProvider>().getGirlfriendNameById(reels.gfid) ??
        reels.gfid;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayerWidget(videoUrl: reels.video, thumbnailUrl: reels.thumb),
          // Plum fade for legibility
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: Container(
                height: 340,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    stops: const [0, 0.55, 1.0],
                    colors: [
                      SophiaColors.bgBottom.withValues(alpha: 0.0),
                      SophiaColors.bgBottom.withValues(alpha: 0.7),
                      SophiaColors.bgBottom,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          // ── Right action rail ──────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 150,
            child: SlideEntrance(
              key: ValueKey('rail-${reels.reelId}'),
              delay: 120,
              child: Column(
                children: [
                  Pressable(
                    onTap: () => _openChat(context, reels),
                    child: SizedBox(
                      width: 56,
                      height: 64,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          SizedBox(
                            width: 54,
                            height: 54,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: LoopAnimation(
                                    duration: const Duration(seconds: 5),
                                    builder: (_, t, child) => Transform.rotate(
                                      angle: t * 2 * math.pi,
                                      child: child,
                                    ),
                                    child: Container(
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
                                ),
                                ProfileWidget(
                                  gfId: reels.gfid,
                                  size: 48,
                                  borderColor: SophiaColors.bgTop,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SophiaColors.amethyst,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RailButton(
                    icon: Icons.outlined_flag_rounded,
                    label: 'Report',
                    onTap: () => _openReport(context),
                  ),
                ],
              ),
            ),
          ),
          // ── Bottom info ────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 84,
            bottom: 140,
            child: SlideEntrance(
              key: ValueKey('info-${reels.reelId}'),
              delay: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      fontFamily: sophiaSerif,
                    ),
                  ),
                  if (reels.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      reels.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Pressable(
                    onTap: () => _openChat(context, reels),
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: SophiaColors.amethyst,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SophiaColors.amethystMid.withValues(
                              alpha: 0.8,
                            ),
                            blurRadius: 20,
                            spreadRadius: -8,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: const Stack(
                          children: [
                            Positioned.fill(
                              child: SheenEffect(widthFactor: 0.4),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    color: SophiaColors.champagne,
                                    size: 15,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Let’s Talk',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Column(
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SophiaColors.bgTop.withValues(alpha: 0.4),
                  border: Border.all(
                    color: SophiaColors.lilac.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
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
