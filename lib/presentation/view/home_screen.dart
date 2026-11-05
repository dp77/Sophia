import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_upgrade_version/flutter_upgrade_version.dart';
import 'package:girlfriend/data/update_dialog_manager.dart';
import 'package:girlfriend/presentation/view/screens/premium_screen.dart';
import 'package:girlfriend/presentation/view/tabs/chat_tab.dart';
import 'package:girlfriend/presentation/view/tabs/generate_tab.dart';
import 'package:girlfriend/presentation/view/tabs/home_tab.dart';
import 'package:girlfriend/presentation/widget/app_background.dart';
import 'package:girlfriend/presentation/widget/sophia_skeleton.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/presentation/widget/navbar_widget.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../data/api_service/api_caller.dart';
import 'package:girlfriend/presentation/view/tabs/settings_tab.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/view/screens/about_you_screen.dart';
import 'package:provider/provider.dart';
import '../../data/model/reel_model.dart';
import '../../data/analytics/analytics_service.dart';
import '../../data/navigation_service.dart';
import '../../data/rate_prompt.dart';
import '../widget/navbar_notch_painter.dart';
import 'tabs/reel_tab.dart';

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

  ReelsData? reelsData;
  bool isLoading = false;

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
    initReels();
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

  Future<void> initReels() async {
    setState(() {
      isLoading = true;
    });
    const minDuration = Duration(milliseconds: 600);
    final minimumDelayFuture = Future.delayed(minDuration);
    final getReelFuture = ReelsData.getReelsData();
    final List<dynamic> results;
    try {
      results = await Future.wait([getReelFuture, minimumDelayFuture]);
    } catch (e) {
      // Failed request: stop loading so the Reels tab shows the retry card.
      debugPrint('initReels failed: $e');
      if (mounted) setState(() => isLoading = false);
      return;
    }
    if (!mounted) return;
    ReelsData dataApi = results[0];
    setState(() {
      reelsData = dataApi;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      isLoading = false;
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
                      NavbarWidget(
                        image: _selectedIndex == 1 ? 'nav_reel_fill' : 'nav_reel',
                        isActive: _selectedIndex == 1,
                        onTap: () => _selectTab(1, 'ReelsTab'),
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
        if (reelsData == null || reelsData!.reels.isEmpty) ...[
          isLoading
              ? const ReelSkeleton()
              : Container(
                  decoration: const BoxDecoration(
                    gradient: SophiaColors.background,
                  ),
                  child: SophiaRetryCard(
                    title: "Couldn't load reels",
                    onRetry: initReels,
                  ),
                ),
        ] else ...[
          ReelTab(reelsData: reelsData!),
        ],
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
