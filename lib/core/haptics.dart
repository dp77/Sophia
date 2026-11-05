import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide haptic feedback. Users can turn it off in Settings.
class Haptics {
  Haptics._();

  static const _key = 'haptics_enabled';

  /// On by default. Listen to this to rebuild the Settings switch.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_key) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    if (value) HapticFeedback.selectionClick(); // let the user feel it's on
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  /// Buttons and taps.
  static void tap() {
    if (enabled.value) HapticFeedback.lightImpact();
  }

  /// Switches, pickers, page swipes.
  static void selection() {
    if (enabled.value) HapticFeedback.selectionClick();
  }

  /// Something good happened (purchase, created, credits earned).
  static void success() {
    if (enabled.value) HapticFeedback.mediumImpact();
  }

  /// Something went wrong.
  static void error() {
    if (enabled.value) HapticFeedback.heavyImpact();
  }

  /// Adds a tap haptic to a button callback. Keeps `null` (disabled) as is.
  static VoidCallback? wrap(VoidCallback? onTap) {
    if (onTap == null) return null;
    return () {
      tap();
      onTap();
    };
  }
}
