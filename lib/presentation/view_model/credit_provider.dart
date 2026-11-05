import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreditProvider with ChangeNotifier {
  static const String _creditKey = 'user_credits';
  static const int _initialCredits = 10;
  static const int _adRewardCredits = 10;
  static const int _messageCost = 1;

  int _credits = 0;
  bool _isLoading = true;

  int get credits => _credits;
  bool get isLoading => _isLoading;

  CreditProvider() {
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_creditKey)) {
      _credits = _initialCredits;
      await prefs.setInt(_creditKey, _initialCredits);
    } else {
      _credits = prefs.getInt(_creditKey) ?? _initialCredits;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCredits(int amount) async {
    _credits += amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_creditKey, _credits);
  }

  Future<void> deductCredit() async {
    if (_credits >= _messageCost) {
      _credits -= _messageCost;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_creditKey, _credits);
    }
  }

  bool get canSendMessage => _credits >= _messageCost;

  Future<void> rewardAdCredits() async {
    await addCredits(_adRewardCredits);
  }
}
