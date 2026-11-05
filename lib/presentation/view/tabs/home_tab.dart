import 'package:girlfriend/core/haptics.dart';
import 'dart:io';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/data/model/girlfriend.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/premium_screen.dart';
import 'package:girlfriend/presentation/view_model/auth_provider.dart';
import 'package:girlfriend/presentation/view_model/girlfriend_provider.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/widget/go_pro_widget.dart';
import 'package:girlfriend/presentation/widget/tag_conatiner.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:provider/provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import '../../../core/colors.dart';
import '../../widget/coin_widget.dart';
import '../../widget/sophia_skeleton.dart';
import '../../widget/sophia_style.dart';
import '../screens/chat_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, this.extraSlotBuilder});

  final Widget Function(BuildContext context)? extraSlotBuilder;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const int _extraSlotGridIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Consumer3<GirlfriendProvider, UserProvider, AuthProvider>(
      builder: (context, gfProvider, userProvider, authProvider, _) {
        final girlfriends = gfProvider.girlfriends;
        final loading = gfProvider.loading;
        final name = userProvider.name;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Hello, $name 👋',
                            style: TextStyle(
                              color: white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Spacer(),
                          if (userProvider.isPremiumUser) ...[
                            SvgPicture.asset(
                              'assets/svg/proCrown.svg',
                              height: 30,
                              width: 30,
                            ),
                          ] else ...[
                            GoProWidget(),
                          ],
                          SizedBox(width: 8),
                          CoinWidget(),
                        ],
                      ),
                      Text(
                        'Welcome Back Baby,',
                        style: TextStyle(
                          color: extraLightViolet,
                          fontSize: 31,
                          fontWeight: FontWeight.w400,
                          fontFamily: sophiaScript,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: GradientBoxBorder(
                      gradient: LinearGradient(
                        colors: [darkBlue, extraLightViolet, darkBlue],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [darkBlue.withValues(alpha: 0.4), darkPurple],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(38),
                      topLeft: Radius.circular(38),
                    ),
                    boxShadow: [
                      BoxShadow(color: white.withValues(alpha: 0.2)),
                      BoxShadow(
                        color: darkBlue,
                        spreadRadius: 0.0,
                        blurRadius: 17.0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(38),
                      topLeft: Radius.circular(38),
                    ),
                    child: girlfriends.isEmpty
                        ? (loading
                              ? const HomeGridSkeleton()
                              : SophiaRetryCard(
                                  title: "Couldn't load companions",
                                  onRetry: gfProvider.fetchCompanions,
                                ))
                        : MasonryGridView.count(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: 14,
                              right: 14,
                              top: 14,
                              bottom: 120,
                            ),
                            cacheExtent: 2000,
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            // Premium users don't see the "Go Pro" promo slot.
                            itemCount: userProvider.isPremiumUser
                                ? girlfriends.length
                                : girlfriends.length + 1,
                            itemBuilder: (context, index) {
                              if (userProvider.isPremiumUser) {
                                return _buildImageCard(girlfriends[index]);
                              }
                              if (index == _extraSlotGridIndex) {
                                return widget.extraSlotBuilder?.call(context) ??
                                    _buildDefaultExtraSlot(context);
                              }
                              return _buildGirlfriendTile(
                                context,
                                index,
                                girlfriends,
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGirlfriendTile(
    BuildContext context,
    int gridIndex,
    List<Girlfriend> girlfriends,
  ) {
    final gfIndex = gridIndex < _extraSlotGridIndex ? gridIndex : gridIndex - 1;
    if (gfIndex < 0 || gfIndex >= girlfriends.length) {
      return Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      );
    }
    return _buildImageCard(girlfriends[gfIndex]);
  }

  Widget _buildDefaultExtraSlot(BuildContext context) {
    return GestureDetector(
      onTap: Haptics.wrap(() => NavigationService.navigateToScreenFromBottom(
        context,
        PremiumScreen(),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Shimmer(
          child: Image.asset('assets/images/proad.png', fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildImageCard(Girlfriend girlfriend) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: GestureDetector(
        onTap: Haptics.wrap(() {
          NavigationService.navigateToScreen(
            context,
            ChatScreen(
              imageUrl: girlfriend.imageUrl,
              name: girlfriend.name,
              companionId: girlfriend.id,
            ),
          );
        }),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: white.withValues(alpha: 0.2), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: girlfriend.imageUrl,
                  alignment: Alignment.topCenter,
                  fit: BoxFit.cover,
                  placeholder: (context, url) {
                    return Container(
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Shimmer(
                        child: Center(
                          child: ExpressiveLoadingIndicator(color: white),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, url, error) {
                    return Container(
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 28,
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ClipRRect(
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.46, 1.0],
                          colors: [
                            shadow.withValues(alpha: 0),
                            shadow.withValues(alpha: 0.4),
                            shadow.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${girlfriend.name}, ${girlfriend.age}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (Platform.isAndroid) ...[
                            SizedBox(height: 5),
                            SizedBox(
                              height: 19,
                              width: double.infinity,
                              child: ListView.builder(
                                itemCount: girlfriend.tags.length,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  final e = girlfriend.tags[index];
                                  return TagContainer(text: e);
                                },
                              ),
                            ),
                          ],
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
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
