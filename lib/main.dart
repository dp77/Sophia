import 'package:girlfriend/core/haptics.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:girlfriend/data/notification/notification_service.dart';
import 'package:girlfriend/presentation/view/onboarding/splash_screen.dart';
import 'package:girlfriend/presentation/view_model/user_character_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'core/firebase_strings.dart';
import 'data/analytics/analytics_service.dart';
import 'data/api_service/api_initializer.dart';
import 'data/chat_language_storage.dart';
import 'core/colors.dart';
import 'data/love_letters.dart';
import 'data/navigation_service.dart';
import 'data/notification_helper.dart';
import 'presentation/widget/love_letter_ui.dart';
import 'presentation/view_model/chat_list_provider.dart';
import 'presentation/view_model/generation_provider.dart';
import 'presentation/view_model/girlfriend_provider.dart';
import 'presentation/view_model/user_provider.dart';
import 'presentation/view_model/auth_provider.dart';
import 'presentation/view_model/message_provider.dart';
import 'presentation/view_model/watch_earn_status.dart';
import 'core/ads_code.dart';
import 'data/ad_service/ad_cooldown.dart';
import 'data/remote_config_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ChatLanguageStorage.instance.ensureLoaded();
  } catch (e) {
    debugPrint('ChatLanguageStorage load error: $e');
  }
  OneSignal.initialize("00eb476c-6151-4bea-9af4-5fe9429c9439");
  MobileAds.instance.initialize();
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
      ),
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Firebase initialization timeout - continuing anyway');
        throw TimeoutException('Firebase initialization timeout');
      },
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  try {
    await ApiInitializer.initialize();
  } catch (e) {
    debugPrint('ApiInitializer error: $e');
  }
  _initConsent();
  await _initializeServices();
  await Haptics.init();
  await NotificationService.instance.init();
  await LoveLetters.instance.load();
  _listenForLetters();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatListProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => GirlfriendProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WatchEarnStatusProvider()),
        ChangeNotifierProvider(create: (_) => UserCharacterProvider()),
        ChangeNotifierProvider.value(value: LoveLetters.instance),
        ChangeNotifierProvider(
          create: (context) {
            final generationProvider = GenerationProvider();
            final userProvider = context.read<UserProvider>();
            generationProvider.setUserProvider(userProvider);
            return generationProvider;
          },
        ),
      ],
      child: MyApp(),
    ),
  );
}

/// A companion's push becomes a love letter: while the app is open it slides in
/// as the letter banner instead of a system notification, and a tapped one
/// waits in the Letters tab. Pushes that don't name a companion are untouched.
void _listenForLetters() {
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    final push = LoveLetterPost.fromPush(event.notification);
    if (push == null) return;
    event.preventDefault();
    LoveLetterPost.deliver(
      id: event.notification.notificationId,
      companionId: push.companionId,
      name: push.name,
      imageUrl: push.imageUrl,
      text: push.text,
      announce: NotificationHelper.currentCompanionId != push.companionId,
    );
  });
  OneSignal.Notifications.addClickListener((event) {
    final push = LoveLetterPost.fromPush(event.notification);
    if (push == null) return;
    LoveLetterPost.deliver(
      id: event.notification.notificationId,
      companionId: push.companionId,
      name: push.name,
      imageUrl: push.imageUrl,
      text: push.text,
      announce: false,
    );
  });
}

Future<void> _initConsent() async {
  try {
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        debugPrint('Consent info update completed');

        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          debugPrint('Consent form is available, loading...');
          await ConsentForm.loadAndShowConsentFormIfRequired((
            loadAndShowError,
          ) {
            if (loadAndShowError != null) {
              debugPrint('Consent form error: $loadAndShowError');
            }
          });
          debugPrint('Consent form process completed');
        } else {
          debugPrint('Consent form is not available');
        }

        if (await ConsentInformation.instance.canRequestAds()) {
          debugPrint('Can request ads, initializing Mobile Ads');
          await MobileAds.instance.initialize();
          debugPrint('Mobile Ads initialized successfully');
        } else {
          debugPrint('Cannot request ads due to consent status');
        }
      },
      (error) {
        debugPrint('Error requesting consent info update: $error');
        // Initialize ads anyway in case of consent error to avoid breaking the app
        try {
          MobileAds.instance.initialize();
        } catch (initError) {
          debugPrint('Error initializing Mobile Ads: $initError');
        }
      },
    );
  } catch (e) {
    debugPrint('Error in consent initialization: $e');
    // Initialize ads anyway in case of any error to avoid breaking the app
    try {
      await MobileAds.instance.initialize();
    } catch (initError) {
      debugPrint('Error initializing Mobile Ads: $initError');
    }
  }
}

Future<void> _initializeServices() async {
  try {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    } catch (e) {
      debugPrint('Crashlytics setup error: $e');
    }
  } catch (e, stackTrace) {
    debugPrint('Error during initialization: $e');
    if (kDebugMode) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _wasInBackground = false;
  bool _isShowingAppOpenAd = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state: $state');
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      unawaited(_showAppOpenAd());
    }
  }

  Future<void> _showAppOpenAd() async {
    final remoteConfig = RemoteConfigService();
    if (_isShowingAppOpenAd) {
      debugPrint('App Open skipped: another App Open ad is active');
      return;
    }
    if (!remoteConfig.showAppOpen) {
      debugPrint('App Open skipped: Remote Config disabled it');
      return;
    }
    if (AdCooldown.isActive) {
      debugPrint('App Open skipped: full-screen ad cooldown is active');
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        AdCooldown.isActive) {
      return;
    }

    _isShowingAppOpenAd = true;
    await AppOpenAd.load(
      adUnitId: idAppOpenAd,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              AdCooldown.markAdShown();
              _isShowingAppOpenAd = false;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('App-open ad failed to show: $error');
              ad.dispose();
              _isShowingAppOpenAd = false;
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('App-open ad failed to load: $error');
          _isShowingAppOpenAd = false;
        },
      ),
    );
  }

  static FirebaseAnalytics? get analytics {
    try {
      Firebase.app();
      return FirebaseAnalytics.instance;
    } catch (e) {
      return null;
    }
  }

  static FirebaseAnalyticsObserver? get observer {
    final analyticsInstance = analytics;
    if (analyticsInstance != null) {
      return FirebaseAnalyticsObserver(analytics: analyticsInstance);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final observers = <NavigatorObserver>[
      AnalyticsRouteObserver(AnalyticsService.instance),
    ];
    final analyticsObserver = observer;
    if (analyticsObserver != null) {
      observers.add(analyticsObserver);
    }
    return MaterialApp(
      title: 'Sophia: My AI Girlfriend',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      navigatorObservers: observers,
      theme: ThemeData(
        useMaterial3: true,
        textSelectionTheme: TextSelectionThemeData(
          selectionHandleColor: white,
          cursorColor: white,
        ),
        scaffoldBackgroundColor: white,
        fontFamily: 'PlusJakartaSans',
      ),
      builder: (ctx, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
