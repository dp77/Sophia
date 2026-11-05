import 'package:girlfriend/core/haptics.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/core/app_config.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/about_us_screen.dart';
import 'package:girlfriend/presentation/view/screens/premium_screen.dart';
import 'package:girlfriend/presentation/view/screens/watch_earn_screen.dart';
import 'package:girlfriend/presentation/view_model/auth_provider.dart';
import 'package:girlfriend/presentation/view_model/chat_list_provider.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/view_model/watch_earn_status.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../../data/ad_service/cascading_ad_manager.dart';
import '../../../data/api_service/api_caller.dart';
import '../../widget/sophia_style.dart';
import '../screens/about_you_screen.dart';
import '../../widget/pro_card.dart';
import '../../widget/sophia_dialog.dart';
import 'package:grokbot_widget/grokbot_widget.dart';
import '../screens/login_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with AutomaticKeepAliveClientMixin {
  final InAppReview inAppReview = InAppReview.instance;

  ApiCaller apiCaller = ApiCaller();
  final _descriptionController = TextEditingController();
  bool _isSendingFeedback = false;
  bool _isWatchAndEarnInProgress = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoFailed = false;
  bool? _pushOptedIn;
  bool _pushToggleBusy = false;

  void _onPushSubscriptionChanged(OSPushSubscriptionChangedState s) {
    if (!mounted || _pushToggleBusy) return;
    final next = s.current.optedIn;
    if (_pushOptedIn == next) return;
    setState(() => _pushOptedIn = next);
  }

  @override
  void initState() {
    super.initState();
    _pushOptedIn = OneSignal.User.pushSubscription.optedIn;
    OneSignal.User.pushSubscription.addObserver(_onPushSubscriptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _pushOptedIn = OneSignal.User.pushSubscription.optedIn);
    });
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset('assets/video/diamond.mp4');
    try {
      await controller.setLooping(true);
      await controller.initialize();
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _isVideoInitialized = true;
        _isVideoFailed = false;
      });
    } catch (_) {
      controller.dispose();
      if (!mounted) return;
      setState(() {
        _videoController = null;
        _isVideoInitialized = false;
        _isVideoFailed = true;
      });
    }
  }

  @override
  void dispose() {
    OneSignal.User.pushSubscription.removeObserver(_onPushSubscriptionChanged);
    _videoController?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handlePushToggle(bool enabled) async {
    if (_pushToggleBusy) return;
    setState(() {
      _pushOptedIn = enabled;
      _pushToggleBusy = true;
    });
    try {
      if (enabled) {
        await OneSignal.User.pushSubscription.optIn();
      } else {
        await OneSignal.User.pushSubscription.optOut();
      }
      if (!mounted) return;
      final synced = OneSignal.User.pushSubscription.optedIn;
      setState(() {
        if (synced != null) _pushOptedIn = synced;
        _pushToggleBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      final reverted = OneSignal.User.pushSubscription.optedIn;
      setState(() {
        if (reverted != null) _pushOptedIn = reverted;
        _pushToggleBusy = false;
      });
      SophiaToast.show(msg: 'Could not update notifications');
    }
  }

  Future<void> _resetOneSignalSession() async {
    try {
      await OneSignal.User.pushSubscription.optOut();
    } catch (_) {}
    try {
      await OneSignal.logout();
    } catch (_) {}
    try {
      await OneSignal.User.pushSubscription.optIn();
    } catch (_) {}
  }

  Future<void> reportReel() async {
    if (_isSendingFeedback) return;
    _isSendingFeedback = true;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final bool isConnected = await InternetConnection().hasInternetAccess;
      if (!isConnected) {
        SophiaToast.show(
          msg:
              "No internet connection. Please check your connection and try again.",
        );
        return;
      }

      final result = await apiCaller.giveFeedback(
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
            SophiaToast.show(
              msg: 'Thank you for your valuable Feedback.',
            );
            Navigator.pop(context);
            _descriptionController.clear();
          }
        },
      );
    } finally {
      _isSendingFeedback = false;
    }
  }

  Future<void> deleteAccount(
    UserProvider userProvider,
    AuthProvider auth,
  ) async {
    final result = await apiCaller.deleteAccount(userProvider.id);
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
            SophiaToast.show(msg: data['message']);
            final chatListProvider = context.read<ChatListProvider>();
            auth.signOut(
              userProvider: userProvider,
              chatListProvider: chatListProvider,
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: SophiaColors.bgTop,
      body: Container(
        decoration: const BoxDecoration(gradient: SophiaColors.background),
        child: SingleChildScrollView(
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ─────────────────────────────────────────────
                const SlideEntrance(
                  delay: 40,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR ACCOUNT',
                          style: TextStyle(
                            color: SophiaColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Settings',
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
                ),

                // ── Profile: avatar + name/plan ────────────────────────
                SlideEntrance(
                  delay: 120,
                  child: Consumer2<UserProvider, AuthProvider>(
                    builder: (context, userProvider, authProvider, _) {
                      final displayName = authProvider.isAuthenticated
                          ? userProvider.name
                          : 'Guest User';
                      final isPremium = userProvider.isPremiumUser;
                      final planColor = isPremium ? gold2 : SophiaColors.lilac;
                      return Pressable(
                        onTap: () {
                          if (authProvider.isAuthenticated) {
                            AboutYouScreen.open(context);
                          } else {
                            NavigationService.navigateToScreen(
                              context,
                              const LoginScreen(),
                            );
                          }
                        },
                        child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: SophiaColors.lilac.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          children: [
                            _ProfileAvatar(
                              photoUrl: userProvider.photoUrl,
                              isPremium: isPremium,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      height: 1.1,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: sophiaScript,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: isPremium
                                          ? gold1.withValues(alpha: 0.12)
                                          : Colors.white.withValues(
                                              alpha: 0.06,
                                            ),
                                      border: Border.all(
                                        color: isPremium
                                            ? gold1.withValues(alpha: 0.6)
                                            : SophiaColors.lilac.withValues(
                                                alpha: 0.25,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPremium
                                              ? Icons.workspace_premium_rounded
                                              : Icons.person_outline_rounded,
                                          size: 14,
                                          color: planColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isPremium
                                              ? 'Premium member'
                                              : (authProvider.isAuthenticated
                                                    ? 'Free plan'
                                                    : 'Not signed in'),
                                          style: TextStyle(
                                            color: planColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
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
                      );
                    },
                  ),
                ),

                // ── Premium + Watch & Earn (free users) ─────────────────
                Selector<UserProvider, bool>(
                  selector: (p0, userProvider) => userProvider.isPremiumUser,
                  builder: (context, isPremiumUser, _) {
                    if (isPremiumUser) return const SizedBox(height: 4);
                    return SlideEntrance(
                      delay: 200,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: AnimatedProCard(
                              onTap: () {
                                NavigationService.navigateToScreen(context, PremiumScreen());
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Pressable(
                            onTap: () => NavigationService.navigateToScreen(
                              context,
                              const WatchEarnScreen(),
                            ),
                            child: Container(
                              height: 116,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: SophiaColors.lilac.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child:
                                          !_isVideoFailed &&
                                              _isVideoInitialized &&
                                              _videoController != null
                                          ? FittedBox(
                                              fit: BoxFit.cover,
                                              child: SizedBox(
                                                width: _videoController!
                                                    .value
                                                    .size
                                                    .width,
                                                height: _videoController!
                                                    .value
                                                    .size
                                                    .height,
                                                child: VideoPlayer(
                                                  _videoController!,
                                                ),
                                              ),
                                            )
                                          : SizedBox.expand(
                                              child: Image.asset(
                                                'assets/images/diamond.png',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.transparent,
                                              SophiaColors.bgTop.withValues(
                                                alpha: 0.35,
                                              ),
                                              SophiaColors.bgTop.withValues(
                                                alpha: 0.75,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 16,
                                          left: 120,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Watch More, Earn More',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                fontStyle: FontStyle.italic,
                                                fontFamily: sophiaSerif,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            const Text(
                                              'Turn your screen time into smart rewards.',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: SophiaColors.lilac,
                                                fontSize: 10.5,
                                                height: 1.3,
                                              ),
                                            ),
                                            const SizedBox(height: 9),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: SophiaColors.amethyst,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35),
                                                  width: 0.6,
                                                ),
                                              ),
                                              child: _isWatchAndEarnInProgress
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .play_circle_fill_rounded,
                                                          size: 14,
                                                          color: SophiaColors
                                                              .champagne,
                                                        ),
                                                        SizedBox(width: 5),
                                                        Text(
                                                          'Watch & Earn Credits',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),

                // ── Sign in (guests) ───────────────────────────────────
                Selector<AuthProvider, bool>(
                  selector: (p0, authProvider) => authProvider.isAuthenticated,
                  builder: (context, isLogin, _) {
                    if (isLogin) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: AmethystButton(
                        label: 'Sign In / Sign Up',
                        height: 54,
                        leading: const SvgIcon('ic_login', color: SophiaColors.champagne, size: 18),
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                // ── Settings panel ─────────────────────────────────────
                SlideEntrance(
                  delay: 280,
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
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [SophiaColors.panelTop, SophiaColors.bgBottom],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: _panelRadius,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _GroupLabel('Personalize'),
                            _SettingsGroup(
                              children: [
                                Consumer<UserProvider>(
                                  builder: (context, up, _) {
                                    final parts = <String>[
                                      if (up.name.isNotEmpty && up.name != 'Anonymous') up.name,
                                      if (up.age > 0) '${up.age}',
                                      if (up.chatLanguage.isNotEmpty) up.chatLanguage,
                                    ];
                                    return _SettingsRow(
                                      svg: 'set_about_you',
                                      title: 'About you',
                                      subtitle: parts.isEmpty ? 'Name, age, gender & chat language' : parts.join(' · '),
                                      onTap: () => AboutYouScreen.open(context),
                                    );
                                  },
                                ),
                                _SettingsRow(
                                  svg: 'set_notification',
                                  title: 'Notifications',
                                  subtitle: 'Push updates from the app',
                                  trailing: RepaintBoundary(
                                    child: CupertinoSwitch(
                                      value: _pushOptedIn == true,
                                      onChanged: (v) {
                                        Haptics.selection();
                                        _handlePushToggle(v);
                                      },
                                      activeTrackColor:
                                          SophiaColors.amethystMid,
                                      thumbColor: _pushOptedIn == true
                                          ? SophiaColors.champagne
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                _SettingsRow(
                                  svg: 'set_haptics',
                                  title: 'Haptics',
                                  subtitle: 'Vibrate on taps & actions',
                                  trailing: ValueListenableBuilder<bool>(
                                    valueListenable: Haptics.enabled,
                                    builder: (context, on, _) => CupertinoSwitch(
                                      value: on,
                                      onChanged: Haptics.setEnabled,
                                      activeTrackColor: SophiaColors.amethystMid,
                                      thumbColor: on ? SophiaColors.champagne : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const _GroupLabel('Support'),
                            _SettingsGroup(
                              children: [
                                _SettingsRow(
                                  svg: 'set_rate_us',
                                  title: 'Rate Us',
                                  subtitle: 'Love the app? Let us know!',
                                  onTap: () {
                                    _showRateDialog(context);
                                  },
                                ),
                                _SettingsRow(
                                  svg: 'set_feedback',
                                  title: 'Send Feedback',
                                  subtitle: 'Share your thoughts with us',
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true, // IMPORTANT
                                      backgroundColor: Colors.transparent,
                                      builder: (context) {
                                        return _FeedbackSheet(
                                          controller: _descriptionController,
                                          onSend: () async {
                                            if (_isSendingFeedback) return;
                                            if (_descriptionController.text.trim().isEmpty) {
                                              SophiaToast.show(msg: 'Please write your feedback.');
                                              return;
                                            }
                                            await reportReel();
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const _GroupLabel('About'),
                            _SettingsGroup(
                              children: [
                                _SettingsRow(
                                  svg: 'set_privacy',
                                  title: 'Privacy Policy',
                                  subtitle: 'Read our privacy policy',
                                  onTap: () {
                                    launchUrl(
                                      Uri.parse(AppConfig.privacyPolicyUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                ),
                                _SettingsRow(
                                  svg: 'set_terms',
                                  title: 'Terms of Service',
                                  subtitle: 'Read our terms of service',
                                  onTap: () {
                                    launchUrl(
                                      Uri.parse(AppConfig.termsOfServiceUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                ),
                                _SettingsRow(
                                  svg: 'set_about_us',
                                  title: 'About Us',
                                  subtitle: 'Read about us',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AboutUsScreen(),
                                      ),
                                    );
                                  },
                                ),
                                FutureBuilder<PackageInfo>(
                                  future: PackageInfo.fromPlatform(),
                                  builder: (context, snapshot) {
                                    return _SettingsRow(
                                      svg: 'set_version',
                                      title: 'App Information',
                                      subtitle: snapshot.hasData
                                          ? 'Version ${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                                          : 'Version …',
                                    );
                                  },
                                ),
                              ],
                            ),
                            Consumer2<AuthProvider, UserProvider>(
                              builder: (context, auth, userProvider, _) {
                                if (!auth.isAuthenticated)
                                  return const SizedBox();
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 22),
                                    Pressable(
                                      onTap: () {
                                        _showSignOutConfirmationDialog(
                                          userProvider,
                                          auth,
                                        );
                                      },
                                      child: Container(
                                        height: 54,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            27,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          border: Border.all(
                                            color: SophiaColors.champagne
                                                .withValues(alpha: 0.55),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SvgIcon('ic_logout', color: SophiaColors.champagne, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Sign Out',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: TextButton.icon(
                                        onPressed: Haptics.wrap(() {
                                          _showDeleteAccountDialog(
                                            userProvider,
                                            auth,
                                          );
                                        }),
                                        icon: const SvgIcon('ic_delete', color: Color(0xFFD99A98), size: 18),
                                        label: const Text(
                                          'Delete Account',
                                          style: TextStyle(
                                            color: Color(0xFFD99A98),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 130),
                          ],
                        ),
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

  static const _panelRadius = BorderRadius.only(
    topLeft: Radius.circular(38),
    topRight: Radius.circular(38),
  );

  void _showRateDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Rate us',
      barrierColor: SophiaColors.bgTop.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, _, _) => _RateUsDialog(
        onLater: () => Navigator.pop(dialogContext),
        onSubmit: (rating) => _submitRating(dialogContext, rating),
      ),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * anim.value, sigmaY: 8 * anim.value),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(curved), child: child),
          ),
        );
      },
    );
  }

  /// Same behaviour as before: needs internet, remembers the dialog was shown,
  /// 4–5 hearts go to the store review, 1–3 just say thanks.
  Future<void> _submitRating(BuildContext dialogContext, int rating) async {
    final bool isConnected = await InternetConnection().hasInternetAccess;
    if (!isConnected) {
      SophiaToast.show(msg: "No internet connection. Please check your connection and try again.");
      return;
    }
    if (dialogContext.mounted) Navigator.pop(dialogContext);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rate_dialog_shown', true);

    if (rating >= 4) {
      final startTime = Stopwatch()..start();
      if (await inAppReview.isAvailable()) {
        try {
          await inAppReview.requestReview();
        } catch (e) {
          debugPrint('Failed to request app review');
        }
      }
      final elapsedMilliseconds = startTime.elapsedMilliseconds;
      if (elapsedMilliseconds > 300) {
        return;
      }

      try {
        await launchUrl(
          Uri.parse(
            Platform.isAndroid
                ? 'https://play.google.com/store/apps/details?id=com.diapp.girlfriend'
                : 'https://apps.apple.com/app/sophia-my-ai-girlfriend/id6759085301',
          ),
        );
      } catch (e) {
        debugPrint('Failed to open app store listing');
      }
    } else {
      SophiaToast.show(msg: 'Thanks for your feedback ❤️');
    }
  }

  void _showDeleteAccountDialog(UserProvider userProvider, AuthProvider auth) {
    showSophiaDialog(
      context: context,
      builder: (dialogContext) => SophiaDialog(
        tone: SophiaTone.danger,
        hero: const SophiaIconHero(icon: Icons.delete_forever_rounded, tone: SophiaTone.danger),
        title: 'Delete Account',
        message: 'Are you sure you want to delete your account? This action cannot be undone.',
        body: const SophiaNote(
          icon: Icons.warning_amber_rounded,
          tone: SophiaTone.danger,
          text: 'All your data, chats, and settings will be permanently removed.',
        ),
        actions: [
          SophiaDangerButton(
            label: 'Delete',
            svg: 'ic_delete',
            onTap: () {
              Navigator.pop(dialogContext);
              deleteAccount(userProvider, auth);
            },
          ),
          SophiaGhostButton(label: 'Cancel', onTap: () => Navigator.pop(dialogContext)),
        ],
      ),
    );
  }

  void _showSignOutConfirmationDialog(UserProvider userProvider, AuthProvider authProvider) {
    showSophiaDialog(
      context: context,
      builder: (dialogContext) => SophiaDialog(
        hero: const SophiaMascotHero(state: GrokBotState.sad),
        title: 'Sign Out',
        message: 'Are you sure you want to sign out?',
        actions: [
          AmethystButton(
            label: 'Sign Out',
            leading: const SvgIcon('ic_logout', color: SophiaColors.champagne, size: 18),
            onTap: () async {
              Navigator.pop(dialogContext);
              final chatListProvider = context.read<ChatListProvider>();
              try {
                await _resetOneSignalSession();
                await authProvider.signOut(userProvider: userProvider, chatListProvider: chatListProvider);
                if (mounted) {
                  SophiaToast.show(msg: 'Signed out');
                }
              } catch (_) {
                if (mounted) {
                  SophiaToast.show(msg: 'Sign out failed');
                }
              }
            },
          ),
          SophiaGhostButton(label: 'Cancel', onTap: () => Navigator.pop(dialogContext)),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ── Settings building blocks ───────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: SophiaColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

/// Glass card holding rows separated by hairlines.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.16)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 66,
                  color: SophiaColors.lilac.withValues(alpha: 0.1),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String? svg;
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsRow({
    this.svg,
    this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    SophiaColors.amethystMid.withValues(alpha: 0.55),
                    SophiaColors.orchid.withValues(alpha: 0.25),
                  ],
                ),
                border: Border.all(
                  color: SophiaColors.lilac.withValues(alpha: 0.22),
                ),
              ),
              alignment: Alignment.center,
              child: svg != null
                  ? SvgPicture.asset(
                      'assets/svg/$svg.svg',
                      height: 19,
                      width: 19,
                      colorFilter: const ColorFilter.mode(
                        SophiaColors.champagne,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(icon, color: SophiaColors.champagne, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SophiaColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: SophiaColors.lilac.withValues(alpha: 0.7),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Profile picture: the user's photo when they have one, otherwise an animated GrokBot,
/// inside a slowly turning ring (gold for premium users).
class _ProfileAvatar extends StatelessWidget {
  final String photoUrl;
  final bool isPremium;
  const _ProfileAvatar({required this.photoUrl, required this.isPremium});

  static const _botTheme = GrokBotThemeData(
    bodyColor: SophiaColors.lilac,
    eyeColor: SophiaColors.bgBottom,
  );

  Widget _bot() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          colors: [Color(0xFF2E1A16), SophiaColors.panelTop],
        ),
      ),
      alignment: Alignment.center,
      child: const GrokBot(
        size: 50,
        shape: GrokBotShape.blob,
        state: GrokBotState.idle,
        autoBlink: true,
        autoExpression: true,
        theme: _botTheme,
        semanticLabel: 'Profile avatar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: LoopAnimation(
              duration: const Duration(seconds: 6),
              builder: (_, t, child) =>
                  Transform.rotate(angle: t * 2 * math.pi, child: child),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: isPremium
                        ? const [
                            gold1,
                            gold3,
                            gold5,
                            SophiaColors.champagne,
                            gold1,
                          ]
                        : const [
                            SophiaColors.champagne,
                            SophiaColors.orchid,
                            SophiaColors.lilac,
                            SophiaColors.champagne,
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isPremium ? gold1 : SophiaColors.orchid)
                          .withValues(alpha: 0.45),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(2.5),
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: SophiaColors.bgTop,
              ),
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        progressIndicatorBuilder:
                            (context, child, loadingProgress) => _bot(),
                        errorBuilder: (context, error, stackTrace) => _bot(),
                      )
                    : _bot(),
              ),
            ),
          ),
          if (isPremium)
            Positioned(
              right: -4,
              bottom: -2,
              child: SvgPicture.asset(
                'assets/svg/proCrown.svg',
                height: 26,
                width: 26,
              ),
            ),
        ],
      ),
    );
  }
}

/// Rate-us dialog: five hearts you can tap or slide across, with the GrokBot
/// mascot reacting to the score (sad → curious → happy → celebrating).
class _RateUsDialog extends StatefulWidget {
  final VoidCallback onLater;
  final ValueChanged<int> onSubmit;
  const _RateUsDialog({required this.onLater, required this.onSubmit});

  @override
  State<_RateUsDialog> createState() => _RateUsDialogState();
}

class _RateUsDialogState extends State<_RateUsDialog> {
  int _rating = 0;
  final GrokBotController _bot = GrokBotController();

  static const _labels = ['Tap or slide to rate', 'Not for me', 'Could be better', "It's nice", 'I love it', 'Absolutely adore it'];
  static const _states = [
    GrokBotState.curious,
    GrokBotState.sad,
    GrokBotState.confused,
    GrokBotState.happy,
    GrokBotState.excited,
    GrokBotState.celebrate,
  ];

  void _set(int r) {
    final v = r.clamp(1, 5);
    if (v == _rating) return;
    setState(() => _rating = v);
    Haptics.selection();
    if (v == 5) _bot.spin(turns: 1, duration: const Duration(milliseconds: 900));
  }

  void _fromDx(double dx, double width) => _set((dx / width * 5).ceil());

  Color get _glow => Color.lerp(SophiaColors.orchid, SophiaColors.champagne, _rating / 5)!;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF261512), SophiaColors.bgTop],
            ),
            border: Border.all(color: SophiaColors.champagne.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(color: _glow.withValues(alpha: 0.25), blurRadius: 60, spreadRadius: -10),
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(31),
            child: Stack(
              children: [
                // soft aura that warms up with the rating
                Positioned(
                  top: -90,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 260,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [_glow.withValues(alpha: 0.35), _glow.withValues(alpha: 0)]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mascot
                      SizedBox(
                        width: 104,
                        height: 104,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: LoopAnimation(
                                duration: const Duration(seconds: 6),
                                builder: (_, t, child) => Transform.rotate(angle: t * 2 * math.pi, child: child),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [SophiaColors.champagne, SophiaColors.orchid, SophiaColors.lilac, SophiaColors.champagne],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: Alignment(0, -0.3),
                                  colors: [Color(0xFF2E1A16), SophiaColors.panelTop],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: GrokBot(
                                size: 64,
                                controller: _bot,
                                shape: GrokBotShape.blob,
                                state: _states[_rating],
                                emphasis: _rating >= 4,
                                theme: const GrokBotThemeData(
                                  bodyColor: SophiaColors.lilac,
                                  eyeColor: SophiaColors.bgBottom,
                                ),
                                semanticLabel: 'Sophia mascot',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Enjoying Sophia?',
                        style: TextStyle(
                          color: SophiaColors.lavender,
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          fontFamily: sophiaScript,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'How was your experience?',
                        style: TextStyle(color: SophiaColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 22),
                      // Hearts: tap one, or slide a finger across
                      LayoutBuilder(
                        builder: (context, box) {
                          final w = box.maxWidth;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _fromDx(d.localPosition.dx, w),
                            onHorizontalDragUpdate: (d) => _fromDx(d.localPosition.dx, w),
                            child: Row(
                              children: List.generate(5, (i) {
                                final on = i < _rating;
                                return Expanded(
                                  child: Semantics(
                                    button: true,
                                    label: '${i + 1} heart${i == 0 ? '' : 's'}',
                                    child: _Heart(on: on, delayMs: on ? i * 60 : 0),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                            child: c,
                          ),
                        ),
                        child: Text(
                          _labels[_rating],
                          key: ValueKey(_rating),
                          style: TextStyle(
                            color: _rating == 0 ? SophiaColors.muted : SophiaColors.champagne,
                            fontSize: _rating == 0 ? 12 : 17,
                            fontWeight: FontWeight.w600,
                            fontStyle: _rating == 0 ? FontStyle.normal : FontStyle.italic,
                            fontFamily: _rating == 0 ? null : sophiaSerif,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      AmethystButton(
                        label: _rating >= 4 ? 'Rate on the store' : 'Submit',
                        height: 50,
                        onTap: _rating == 0 ? null : () => widget.onSubmit(_rating),
                        leading: const Icon(Icons.favorite_rounded, color: SophiaColors.champagne, size: 16),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: Haptics.wrap(widget.onLater),
                        child: const Text(
                          'Maybe later',
                          style: TextStyle(color: SophiaColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
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

/// One heart: pops with a little bounce and glows when filled.
class _Heart extends StatelessWidget {
  final bool on;
  final int delayMs;
  const _Heart({required this.on, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(on),
      tween: Tween(begin: on ? 0.4 : 1.0, end: 1.0),
      duration: Duration(milliseconds: 420 + delayMs),
      curve: on ? const Interval(0, 1, curve: Curves.elasticOut) : Curves.easeOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: on ? [BoxShadow(color: SophiaColors.champagne.withValues(alpha: 0.35), blurRadius: 18)] : null,
        ),
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => (on
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [SophiaColors.champagne, Color(0xFFD99A98)],
                    )
                  : LinearGradient(colors: [SophiaColors.lilac.withValues(alpha: 0.35), SophiaColors.lilac.withValues(alpha: 0.35)]))
              .createShader(r),
          child: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 38, color: Colors.white),
        ),
      ),
    );
  }
}

/// Feedback sheet: the mascot listens while you type, quick-topic chips start
/// the message for you, and the send button shows progress.
class _FeedbackSheet extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;
  const _FeedbackSheet({required this.controller, required this.onSend});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  static const _maxChars = 500;
  static const _topics = [
    (Icons.chat_bubble_outline_rounded, 'Chats', 'About the chats: '),
    (Icons.face_retouching_natural_rounded, 'Companions', 'About the companions: '),
    (Icons.auto_awesome_outlined, 'Features', 'A feature I would love: '),
    (Icons.bug_report_outlined, 'Bug', 'Something is not working: '),
  ];
  final FocusNode _focus = FocusNode();
  String? _topic;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _focus.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  void _pickTopic((IconData, String, String) t) {
    final text = widget.controller.text;
    // Swap the previous starter phrase (if any) for the new one.
    var body = text;
    for (final o in _topics) {
      if (body.startsWith(o.$3)) body = body.substring(o.$3.length);
    }
    final next = _topic == t.$2 ? body : t.$3 + body;
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => _topic = _topic == t.$2 ? null : t.$2);
    _focus.requestFocus();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    await widget.onSend();
    if (mounted) setState(() => _sending = false);
  }

  GrokBotState get _botState {
    if (_sending) return GrokBotState.sending;
    if (widget.controller.text.trim().isNotEmpty) return GrokBotState.writing;
    if (_focus.hasFocus) return GrokBotState.listening;
    return GrokBotState.curious;
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.controller.text.characters.length;
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF261512).withValues(alpha: 0.96), SophiaColors.bgTop],
              ),
              border: Border(top: BorderSide(color: SophiaColors.champagne.withValues(alpha: 0.4))),
            ),
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.paddingOf(context).bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: SophiaColors.lilac.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Header: mascot + title
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: LoopAnimation(
                                duration: const Duration(seconds: 6),
                                builder: (_, t, child) => Transform.rotate(angle: t * 2 * math.pi, child: child),
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
                            Container(
                              margin: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: Alignment(0, -0.3),
                                  colors: [Color(0xFF2E1A16), SophiaColors.panelTop],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: GrokBot(
                                size: 40,
                                shape: GrokBotShape.blob,
                                state: _botState,
                                theme: const GrokBotThemeData(
                                  bodyColor: SophiaColors.lilac,
                                  eyeColor: SophiaColors.bgBottom,
                                ),
                                semanticLabel: 'Sophia mascot',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tell us anything',
                              style: TextStyle(
                                color: SophiaColors.lavender,
                                fontSize: 30,
                                fontWeight: FontWeight.w400,
                                fontFamily: sophiaScript,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'We read every message and use it to make Sophia better for you.',
                              style: TextStyle(color: SophiaColors.muted, fontSize: 12.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Quick topics
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _topics)
                        Pressable(
                          onTap: () => _pickTopic(t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: _topic == t.$2 ? SophiaColors.amethyst : null,
                              color: _topic == t.$2 ? null : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _topic == t.$2
                                    ? SophiaColors.champagne.withValues(alpha: 0.75)
                                    : SophiaColors.lilac.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  t.$1,
                                  size: 15,
                                  color: _topic == t.$2 ? SophiaColors.champagne : SophiaColors.lilac,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.$2,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Message box
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _focus.hasFocus ? 0.07 : 0.04),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _focus.hasFocus
                            ? SophiaColors.champagne.withValues(alpha: 0.7)
                            : SophiaColors.lilac.withValues(alpha: 0.2),
                      ),
                      boxShadow: _focus.hasFocus
                          ? [BoxShadow(color: SophiaColors.champagne.withValues(alpha: 0.12), blurRadius: 20)]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: widget.controller,
                          focusNode: _focus,
                          cursorColor: SophiaColors.champagne,
                          minLines: 4,
                          maxLines: 8,
                          maxLength: _maxChars,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
                          decoration: const InputDecoration(
                            hintText: 'How can we improve?',
                            hintStyle: TextStyle(color: SophiaColors.muted, fontSize: 15),
                            border: InputBorder.none,
                            isDense: true,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: length > _maxChars * 0.9 ? const Color(0xFFD99A98) : SophiaColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          child: Text('$length / $_maxChars'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AmethystButton(
                    label: _sending ? 'Sending…' : 'Send feedback',
                    height: 54,
                    onTap: (!hasText || _sending) ? null : _send,
                    leading: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: SophiaColors.champagne, size: 17),
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