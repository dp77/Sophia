import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Centralized, privacy-safe analytics facade.
///
/// Screen names are stable product names, not Dart class names. This keeps
/// Firebase reports readable for non-developers and prevents refactors from
/// splitting historical data.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? get _analytics {
    try {
      Firebase.app();
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> screen({
    required String screenName,
    required String innerScreenName,
    String? context,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;

    final parameters = _clean({
      'screen_name': screenName,
      'inner_screen_name': innerScreenName,
      'screen_context': context,
    });

    try {
      await analytics.logScreenView(
        screenName: '$screenName/$innerScreenName',
        screenClass: innerScreenName,
      );
      await analytics.logEvent(
        name: 'app_screen_view',
        parameters: parameters,
      );
    } catch (_) {
      // Analytics must never affect the user experience.
    }
  }

  Future<void> event(
    String name, {
    String? screenName,
    String? innerScreenName,
    String? context,
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;

    final merged = <String, Object>{
      if (screenName != null) 'screen_name': screenName,
      if (innerScreenName != null) 'inner_screen_name': innerScreenName,
      if (context != null) 'screen_context': context,
      ...?parameters,
    };

    try {
      await analytics.logEvent(name: name, parameters: _clean(merged));
    } catch (_) {
      // Analytics must never affect the user experience.
    }
  }

  Map<String, Object> _clean(Map<String, Object?> values) => {
        for (final entry in values.entries)
          if (entry.value != null && entry.value.toString().isNotEmpty)
            entry.key: entry.value!,
      };
}

class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this.analytics);

  final AnalyticsService analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _track(newRoute);
  }

  void _track(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    analytics.screen(screenName: name, innerScreenName: 'Page');
  }
}

String analyticsRouteName(Widget screen) {
  switch (screen.runtimeType.toString()) {
    case 'HomeScreen':
      return 'HomeScreen';
    case 'PremiumScreen':
      return 'PremiumScreen';
    case 'ChatScreen':
      return 'ChatScreen';
    case 'CreateGirlfriendFlowScreen':
      return 'CreateGirlfriendFlowScreen';
    case 'WatchEarnScreen':
      return 'WatchEarnScreen';
    case 'ImageFullScreen':
      return 'ImageFullScreen';
    case 'LoginScreen':
      return 'LoginScreen';
    case 'AboutYouScreen':
      return 'AboutYouScreen';
    case 'AboutUsScreen':
      return 'AboutUsScreen';
    case 'OnboardingScreen':
      return 'OnboardingScreen';
    case 'SplashScreen':
      return 'SplashScreen';
    default:
      return screen.runtimeType.toString();
  }
}
