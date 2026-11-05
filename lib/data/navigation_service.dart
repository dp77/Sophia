import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
class NavigationService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static OverlayState? get overlay => navigatorKey.currentState?.overlay;
  static void navigateToScreen(BuildContext context, Widget screen) {
    if (Platform.isAndroid) {
      Navigator.push(context, ScreenTransition(screen));
    } else {
      Navigator.push(
        context,
        CupertinoPageRoute(
          settings: RouteSettings(name: analyticsRouteName(screen)),
          builder: (context) => screen,
        ),
      );
    }
  }

  static void navigateToScreenAndReplace(BuildContext context, Widget screen) {
    if (Platform.isAndroid) {
      Navigator.pushReplacement(context, ScreenTransition(screen));
    } else {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => screen),
      );
    }
  }

  static void navigateToScreenFromBottom(BuildContext context, Widget screen) {
    if (Platform.isAndroid) {
      Navigator.push(context, BottomScreenTransition(screen));
    } else {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => screen));
    }
  }

  static Future<void> navigateToScreenAndBackEvent(
    BuildContext context,
    Widget screen,
  ) async {
    if (Platform.isAndroid) {
      await Navigator.push(context, ScreenTransition(screen));
    } else {
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => screen),
      );
    }
  }

  static Future<dynamic> navigateToImage(
    BuildContext context,
    Widget screen,
  ) async {
    if (Platform.isAndroid) {
      return Navigator.push(
        context,
        ScreenTransition(screen),
      ); // Return the result of Navigator.push
    } else {
      return Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => screen),
      ); // Return the result of Navigator.push
    }
  }

  static void navigateToScreenAndRemoveUntil(
    BuildContext context,
    Widget screen,
  ) {
    if (Platform.isAndroid) {
      Navigator.pushAndRemoveUntil(
        context,
        ScreenTransition(screen),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(builder: (context) => screen),
        (route) => false,
      );
    }
  }

  static void navigateToScreenAndRemoveUntilFromKey(Widget screen) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    if (Platform.isAndroid) {
      navigator.pushAndRemoveUntil(ScreenTransition(screen), (route) => false);
    } else {
      navigator.pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => screen),
        (route) => false,
      );
    }
  }
}

class ScreenTransition extends PageRouteBuilder {
  final Widget page;

  ScreenTransition(this.page)
    : super(
        settings: RouteSettings(name: analyticsRouteName(page)),
        pageBuilder: (context, animation, anotherAnimation) => page,
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, anotherAnimation, child) {
          animation = CurvedAnimation(
            curve: Curves.fastLinearToSlowEaseIn,
            parent: animation,
            reverseCurve: Curves.fastOutSlowIn,
          );
          return SlideTransition(
            position: Tween(
              begin: const Offset(1.0, 0.0),
              end: const Offset(0.0, 0.0),
            ).animate(animation),
            child: page,
          );
        },
      );
}

class BottomScreenTransition extends PageRouteBuilder {
  final Widget page;

  BottomScreenTransition(this.page)
    : super(
        settings: RouteSettings(name: analyticsRouteName(page)),
        pageBuilder: (context, animation, anotherAnimation) => page,
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, anotherAnimation, child) {
          animation = CurvedAnimation(
            curve: Curves.fastLinearToSlowEaseIn,
            parent: animation,
            reverseCurve: Curves.fastOutSlowIn,
          );
          return SlideTransition(
            position: Tween(
              begin: const Offset(0.0, 1.0), // Slide up from bottom
              end: const Offset(0.0, 0.0),
            ).animate(animation),
            child: child,
          );
        },
      );
}
