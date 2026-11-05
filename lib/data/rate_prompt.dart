import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/view_model/user_provider.dart';

/// Asks for a store review with the system's own review sheet, inside the
/// chat, once the user has sent [_messagesPerSession] messages this session
/// and her reply has arrived. Only if:
///  • they haven't rated yet (the Settings "Rate Us" flow also counts),
///  • it hasn't been asked this session, nor in the last [_cooldown],
///  • it has been asked fewer than [_maxPrompts] times in total,
///  • they aren't a free user who just ran out of credits,
///  • they aren't in the middle of typing their next message.
class RatePrompt {
  static const _messagesPerSession = 5;
  static const _maxPrompts = 3;
  static const _cooldown = Duration(days: 7);
  static const _newSessionAfter = Duration(minutes: 30);

  static const _kRated = 'rate_dialog_shown'; // set by the Settings rate dialog
  static const _kPromptCount = 'rate_prompt_count';
  static const _kLastPrompt = 'rate_last_prompt_ms';

  static int _sentThisSession = 0;
  static bool _doneThisSession = false;
  static bool _checking = false;
  static DateTime? _pausedAt;

  /// Call when the main screen opens: starts a fresh session.
  static Future<void> recordSession() async {
    _sentThisSession = 0;
    _doneThisSession = false;
  }

  static void onPaused() => _pausedAt = DateTime.now();

  /// Coming back after a long break counts as a new session.
  static Future<void> onResumed() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null || DateTime.now().difference(pausedAt) < _newSessionAfter) return;
    await recordSession();
  }

  /// Call after each message the user sends. True when it's time to try asking.
  static bool recordMessageSent() {
    _sentThisSession++;
    return _sentThisSession >= _messagesPerSession && !_doneThisSession && !_checking;
  }

  /// Shows the review sheet over the chat if every rule allows it.
  /// [isBusy] is checked last: her reply still typing, or the user typing.
  static Future<void> maybePromptInChat(BuildContext context, {required bool Function() isBusy}) async {
    if (_doneThisSession || _checking) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final promptCount = prefs.getInt(_kPromptCount) ?? 0;
      final lastMs = prefs.getInt(_kLastPrompt);
      final inCooldown = lastMs != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) < _cooldown;
      if ((prefs.getBool(_kRated) ?? false) || promptCount >= _maxPrompts || inCooldown) {
        _doneThisSession = true; // won't change this session
        return;
      }
      final review = InAppReview.instance;
      if (!await review.isAvailable()) {
        _doneThisSession = true;
        return;
      }

      // Below this point a "no" is temporary: we try again on the next message.
      if (!context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return; // a dialog or other screen is on top
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      final user = Provider.of<UserProvider>(context, listen: false);
      if (!user.isPremiumUser && !user.canSendMessage) return;
      if (isBusy()) return;

      _doneThisSession = true;
      await prefs.setInt(_kPromptCount, promptCount + 1);
      await prefs.setInt(_kLastPrompt, DateTime.now().millisecondsSinceEpoch);
      try {
        await review.requestReview();
      } catch (e) {
        debugPrint('RatePrompt: requestReview failed: $e');
      }
    } finally {
      _checking = false;
    }
  }
}
