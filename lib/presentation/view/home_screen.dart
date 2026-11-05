import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_upgrade_version/flutter_upgrade_version.dart';
import 'package:girlfriend/data/update_dialog_manager.dart';
import 'package:girlfriend/presentation/view/screens/premium_screen.dart';
import 'package:girlfriend/presentation/view/tabs/chat_tab.dart';
import 'package:girlfriend/presentation/view/tabs/generate_tab.dart';
import 'package:girlfriend/presentation/view/tabs/home_tab.dart';
import 'package:girlfriend/presentation/view/tabs/letters_tab.dart';
import 'package:girlfriend/presentation/widget/app_background.dart';
import 'package:girlfriend/presentation/widget/navbar_widget.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../data/api_service/api_caller.dart';
import 'package:girlfriend/presentation/view/tabs/settings_tab.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/view/screens/about_you_screen.dart';
import 'package:provider/provider.dart';
import '../../data/analytics/analytics_service.dart';
import '../../data/love_letters.dart';
import '../../data/navigation_service.dart';
import '../../data/rate_prompt.dart';
import '../widget/navbar_notch_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  final UpdateDialogManager _updateDialogManager = UpdateDialogManager();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.screen(
      screenName: 'HomeScreen',
      innerScreenName: 'HomeTab',
      context: 'main_navigation',
    );
    RatePrompt.recordSession();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _checkName();
        await _registerOneSignal();
        await _checkForUpdate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Premium can expire or be cancelled while the app is in the background
  /// (e.g. from the Play Store / App Store). Re-sync with the server on resume
  /// so the UI switches without a restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<UserProvider>().refreshProfile();
      RatePrompt.onResumed();
    } else if (state == AppLifecycleState.paused) {
      RatePrompt.onPaused();
    }
  }

  void _showPremiumSuggestion() {
    final userProvider = context.read<UserProvider>();
    if (userProvider.isPremiumUser) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        NavigationService.navigateToScreenFromBottom(context, PremiumScreen());
      }
    });
  }

  Future<void> _registerOneSignal() async {
    try {
      final playerId = OneSignal.User.pushSubscription.id ?? '';
      if (playerId.isEmpty) return;

      final userProvider = context.read<UserProvider>();
      if (!userProvider.isLoggedIn) return;

      final apiCaller = ApiCaller();
      final result = await apiCaller.registerOneSignal(
        userProvider.id,
        playerId,
      );
      result.fold(
        (failure) =>
            debugPrint('OneSignal register failed: ${failure.errMessage}'),
        (response) =>
            debugPrint('OneSignal registered: ${response.statusCode}'),
      );
    } catch (e) {
      debugPrint('OneSignal register error: $e');
    }
  }

  Future<void> _checkName() async {
    final userProvider = context.read<UserProvider>();
    // One "About you" flow (name, age, gender, chat language) replaces the
    // separate name and language sheets.
    if (userProvider.needsAboutYou) {
      await AboutYouScreen.open(context, isOnboarding: true);
    }
    if (!mounted) return;
    if (!userProvider.needsAboutYou) {
      _showPremiumSuggestion();
    }
  }

  Future<void> _checkForUpdate() async {
    OneSignal.Notifications.clearAll();
    await _updateDialogManager.checkAndShowUpdateDialog(context);
    if (Platform.isAndroid) {
      InAppUpdateManager manager = InAppUpdateManager();
      AppUpdateInfo? appUpdateInfo = await manager.checkForUpdate();
      if (appUpdateInfo == null) return;
      if (appUpdateInfo.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        await manager.startAnUpdate(type: AppUpdateType.immediate);
      } else if (appUpdateInfo.updateAvailability ==
          UpdateAvailability.updateAvailable) {
        if (appUpdateInfo.immediateAllowed) {
          debugPrint('Start an immediate update');
          await manager.startAnUpdate(type: AppUpdateType.immediate);
        } else if (appUpdateInfo.flexibleAllowed) {
          debugPrint('Start an flexible update');
          await manager.startAnUpdate(type: AppUpdateType.flexible);
        } else {
          debugPrint(
            'Update available. Immediate & Flexible Update Flow not allow',
          );
        }
      }
    } else if (Platform.isIOS) {
      await PackageManager.getPackageInfo();
    }
  }
  void _selectTab(int index, String innerScreenName) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    AnalyticsService.instance.screen(
      screenName: 'HomeScreen',
      innerScreenName: innerScreenName,
      context: 'main_navigation',
    );
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AppBackground(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(child: _buildContent()),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PremiumFloatingNavBar(
                  onTap: () => _selectTab(2, 'ChatTab'),
                  child: Row(
                    spacing: 4,
                    children: [
                      NavbarWidget(
                        image: _selectedIndex == 0 ? 'nav_home_fill' : 'nav_home',
                        isActive: _selectedIndex == 0,
                        onTap: () => _selectTab(0, 'HomeTab'),
                      ),
                      NavbarWidget(
                        image: _selectedIndex == 3
                            ? 'heart_edit'
                            : 'heart_edit_outline',
                        isActive: _selectedIndex == 3,
                        onTap: () => _selectTab(3, 'GenerateTab'),
                      ),
                      Spacer(),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          NavbarWidget(
                            image: _selectedIndex == 1 ? 'nav_letter_fill' : 'nav_letter',
                            isActive: _selectedIndex == 1,
                            onTap: () => _selectTab(1, 'LettersTab'),
                          ),
                          Consumer<LoveLetters>(
                            builder: (context, inbox, _) {
                              final unread = inbox.unreadCount;
                              if (unread == 0) return const SizedBox.shrink();
                              return Positioned(
                                top: 8,
                                right: 6,
                                child: IgnorePointer(
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 17),
                                    height: 17,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB4505C),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: const Color(0xFF1A0F0D), width: 1.5),
                                    ),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      NavbarWidget(
                        image: _selectedIndex == 4 ? 'nav_profile_fill' : 'nav_profile',
                        isActive: _selectedIndex == 4,
                        onTap: () => _selectTab(4, 'SettingsTab'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // bottomNavigationBar: BannerAdWidget(),
      ),
    );
  }

  Widget _buildContent() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        HomeTab(),
        LettersTab(onExplore: () => _selectTab(0, 'HomeTab')),
        ChatTab(),
        GenerateTab(),
        SettingsTab(
          onOpenDrawer: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
