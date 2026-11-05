import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/api_service/api_caller.dart';

class UserProvider with ChangeNotifier {
  String _id = '';
  int _credits = 0;
  String _email = '';
  String _name = '';
  String _firebaseUid = '';
  String _loginMethod = 'anonymous';
  String _photoUrl = '';
  bool _canClaimDailyCredits = false;
  DateTime? _createdAt;
  bool _isPremiumUser = false;
  String _chatLanguage = '';
  int _age = 0; // 0 = not set yet
  String _gender = ''; // '' = not set yet

  // Getters
  String get id => _id;
  int get credits => _credits;
  String get email => _email;
  String get name => _name;
  String get firebaseUid => _firebaseUid;
  String get loginMethod => _loginMethod;
  String get photoUrl => _photoUrl;
  bool get canClaimDailyCredits => _canClaimDailyCredits;
  DateTime? get createdAt => _createdAt;
  bool get isPremiumUser => _isPremiumUser;
  String get chatLanguage => _chatLanguage;
  int get age => _age;
  String get gender => _gender;

  /// True until the user has finished the "About you" setup.
  bool get needsAboutYou => _name.isEmpty || _name == 'Anonymous' || _age == 0 || _chatLanguage.isEmpty;

  /// Check if user is logged in (has backend user_id)
  bool get isLoggedIn => _id.isNotEmpty;

  /// Check if user is anonymous (not linked with Google/Apple)
  bool get isAnonymous => _loginMethod == 'anonymous';

  /// Check if user has a social account linked
  bool get hasLinkedAccount => _loginMethod == 'google' || _loginMethod == 'apple';

  /// Check if user has a profile photo
  bool get hasProfilePhoto => _photoUrl.isNotEmpty;

  /// Check if user can send message (1 credit cost)
  bool get canSendMessage => _credits >= 1;

  bool get canGenerateImage => _credits >= 20;

  bool get canGenerateVideo => _credits >= 30;

  /// Get display name - returns name if available, else "Guest User" for anonymous
  String get displayName {
    if (_name.isNotEmpty) return _name;
    if (_email.isNotEmpty) return _email.split('@').first;
    if (isAnonymous) return 'Guest User';
    return 'User';
  }

  Future<void> setPremium(bool isPremium) async {
    _isPremiumUser = isPremium;
    notifyListeners();
    await saveToLocal();
  }

  Future<void> setUserData({
    String? id,
    int? credits,
    String? email,
    String? name,
    String? firebaseUid,
    String? loginMethod,
    String? photoUrl,
    bool? canClaimDailyCredits,
    String? createdAt,
    bool? isPremiumUser,
    String? chatLanguage,
  }) async {
    if (id != null) _id = id;
    if (credits != null) _credits = credits;
    if (email != null) _email = email;
    if (name != null) _name = name;
    if (firebaseUid != null) _firebaseUid = firebaseUid;
    if (loginMethod != null) _loginMethod = loginMethod;
    if (photoUrl != null) _photoUrl = photoUrl;
    if (canClaimDailyCredits != null) _canClaimDailyCredits = canClaimDailyCredits;
    if (createdAt != null) _createdAt = DateTime.tryParse(createdAt);
    if (isPremiumUser != null) _isPremiumUser = isPremiumUser;
    if (chatLanguage != null) _chatLanguage = chatLanguage;

    notifyListeners();
    await saveToLocal();
  }

  Future<void> saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_backend_id', _id);
    await prefs.setInt('user_credits', _credits);
    await prefs.setString('user_email', _email);
    await prefs.setString('user_name', _name);
    await prefs.setString('user_firebase_uid', _firebaseUid);
    await prefs.setString('user_login_method', _loginMethod);
    await prefs.setString('user_photo_url', _photoUrl);
    await prefs.setBool('user_can_claim_daily', _canClaimDailyCredits);
    if (_createdAt != null) {
      await prefs.setString('user_created_at', _createdAt!.toIso8601String());
    }
    await prefs.setBool('user_is_premium', _isPremiumUser);
    await prefs.setString('user_chat_language', _chatLanguage);
    await prefs.setInt('user_age', _age);
    await prefs.setString('user_gender', _gender);
  }

  Future<bool> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _id = prefs.getString('user_backend_id') ?? '';
    if (_id.isEmpty) return false;

    _credits = prefs.getInt('user_credits') ?? 0;
    _email = prefs.getString('user_email') ?? '';
    _name = prefs.getString('user_name') ?? '';
    _firebaseUid = prefs.getString('user_firebase_uid') ?? '';
    _loginMethod = prefs.getString('user_login_method') ?? 'anonymous';
    _photoUrl = prefs.getString('user_photo_url') ?? '';
    _canClaimDailyCredits = prefs.getBool('user_can_claim_daily') ?? false;
    final createdAtStr = prefs.getString('user_created_at');
    if (createdAtStr != null) {
      _createdAt = DateTime.tryParse(createdAtStr);
    }
    _isPremiumUser = prefs.getBool('user_is_premium') ?? false;
    _chatLanguage = prefs.getString('user_chat_language') ?? '';
    _age = prefs.getInt('user_age') ?? 0;
    _gender = prefs.getString('user_gender') ?? '';

    notifyListeners();
    debugPrint('UserProvider: Data loaded from local storage for user: $_id');
    return true;
  }

  Future<void> refreshProfile() async {
    if (_id.isEmpty) return;

    final apiCaller = ApiCaller();
    final result = await apiCaller.getProfile(userId: _id);

    result.fold((failure) => debugPrint('UserProvider: Refresh profile failed: ${failure.errMessage}'), (
      response,
    ) async {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        await setUserData(
          name: data['name'] ?? data['user']?['name'],
          credits: data['credits'] is int ? data['credits'] : int.tryParse(data['credits']?.toString() ?? '0'),
          canClaimDailyCredits: data['can_daily_claim'] ?? data['can_claim_daily_credits'],
          isPremiumUser: _parsePremium(data['is_premium'] ?? data['user']?['is_premium']),
          chatLanguage: data['chat_language'] ?? '',
        );
        debugPrint('UserProvider: Profile refreshed from API');
      }
    });
  }

  /// Backend may send is_premium as bool, 0/1 or "true"/"false".
  /// Returns null when missing so the current value is kept.
  static bool? _parsePremium(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  Future<void> updateCredits(int credits) async {
    _credits = credits;
    notifyListeners();
    await saveToLocal();
  }

  /// Handle watch and earn API response and update credits
  Future<bool> watchAndEarn() async {
    if (_id.isEmpty) {
      debugPrint('UserProvider: Cannot watch and earn - user not logged in');
      return false;
    }

    final apiCaller = ApiCaller();
    final result = await apiCaller.watchAndEarn(_id);

    return result.fold(
      (failure) {
        debugPrint('UserProvider: Watch and earn failed: ${failure.errMessage}');
        return false;
      },
      (response) async {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final successValue = data['success'] ?? data['status'];
          final success = successValue == true ||
              successValue?.toString().toLowerCase() == 'true' ||
              successValue?.toString() == '1';
          if (success) {
            final addedCredits =
                int.tryParse(data['added_credits']?.toString() ?? '') ?? 0;
            final totalCredits =
                int.tryParse(data['total_credits']?.toString() ?? '');

            if (totalCredits != null) {
              await updateCredits(totalCredits);
            }
            // Always fetch the profile after claiming so the provider reflects
            // the server's authoritative balance immediately.
            await refreshProfile();

            debugPrint(
              'UserProvider: Watch and earn successful - '
              'added $addedCredits credits, total: ${_credits}',
            );
            return true;
          } else {
            debugPrint('UserProvider: Watch and earn API returned success: false');
            return false;
          }
        }
        debugPrint('UserProvider: Invalid response data from watch and earn API');
        return false;
      },
    );
  }

  /// Saves age and gender. Stored on the device for now — send them to the
  /// backend here once an endpoint exists.
  Future<void> updateAboutYou({int? age, String? gender}) async {
    if (age != null) _age = age;
    if (gender != null) _gender = gender;
    notifyListeners();
    await saveToLocal();
  }

  Future<bool> updateName(String name) async {
    if (_id.isEmpty) {
      _name = name;
      notifyListeners();
      await saveToLocal();
      return true;
    }

    final apiCaller = ApiCaller();
    final result = await apiCaller.updateUserName(_id, name);

    return result.fold(
      (failure) {
        debugPrint('UserProvider: Update name failed: ${failure.errMessage}');
        return false;
      },
      (response) async {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          await setUserData(
            name: data['name'] ?? name,
            credits: data['credits'] is int ? data['credits'] : int.tryParse(data['credits']?.toString() ?? '0'),
            canClaimDailyCredits: data['can_daily_claim'] ?? data['can_claim_daily_credits'],
          );
          debugPrint('UserProvider: Name updated and profile synced');
          return true;
        }
        return false;
      },
    );
  }

  Future<String?> updateChatLanguage(String language) async {
    if (_id.isEmpty) {
      _chatLanguage = language;
      notifyListeners();
      await saveToLocal();
      return 'Chat language updated locally';
    }

    final apiCaller = ApiCaller();
    final result = await apiCaller.updateChatLanguage(_id, language);

    return result.fold(
      (failure) {
        debugPrint('UserProvider: Update chat language failed: ${failure.errMessage}');
        return null;
      },
      (response) async {
        final data = response.data;
        String? message;
        if (data is Map<String, dynamic>) {
          if (data['chat_language'] != null) {
            _chatLanguage = data['chat_language'];
          } else {
            _chatLanguage = language;
          }
          message = data['message'];
        } else {
          _chatLanguage = language;
        }
        notifyListeners();
        await saveToLocal();
        debugPrint('UserProvider: Chat language updated to: $_chatLanguage');
        return message ?? 'Chat language updated successfully';
      },
    );
  }

  Future<void> updatePhotoUrl(String? photoUrl) async {
    _photoUrl = photoUrl ?? '';
    notifyListeners();
    await saveToLocal();
  }

  Future<void> updateLoginMethod(String loginMethod) async {
    _loginMethod = loginMethod;
    notifyListeners();
    await saveToLocal();
  }

  Future<void> updateCanClaimDailyCredits(bool canClaim) async {
    _canClaimDailyCredits = canClaim;
    notifyListeners();
    await saveToLocal();
  }

  Future<void> checkDailyClaimEligibility() async {
    if (!isLoggedIn) return;

    // 0. Explicit server check (most important)
    if (_canClaimDailyCredits == false) {
      // Server already said NO (likely due to registration date < 1 day)
      notifyListeners();
      return;
    }

    // 1. Check registration date (must be at least 1 day old)
    if (_createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(_createdAt!);
      if (difference.inDays < 1) {
        _canClaimDailyCredits = false;
        notifyListeners();
        return;
      }
    }

    // 2. Check local storage for last claim date
    final prefs = await SharedPreferences.getInstance();
    final lastClaimDateStr = prefs.getString('last_daily_claim_date_$_id');

    if (lastClaimDateStr == null) {
      // Never claimed locally
      _canClaimDailyCredits = true;
    } else {
      final lastClaimDate = DateTime.parse(lastClaimDateStr);
      final now = DateTime.now();

      // Check if it's a different day
      final isDifferentDay =
          lastClaimDate.year != now.year || lastClaimDate.month != now.month || lastClaimDate.day != now.day;

      _canClaimDailyCredits = isDifferentDay;
    }
    notifyListeners();
  }

  final apiCaller = ApiCaller();

  // Future<bool> watchAndEarn(BuildContext context) async {
  //   if (!isLoggedIn) return false;
  //
  //   final completer = Completer<bool>();
  //
  //   await CascadingAdManager.showAd(
  //     context,
  //     onAdClosed: () async {
  //       final result = await apiCaller.watchAndEarn(_id);
  //       result.fold(
  //         (failure) {
  //           debugPrint('Failed to watch and earn: ${failure.errMessage}');
  //           completer.complete(false);
  //         },
  //         (response) {
  //           print(response);
  //         },
  //       );
  //
  //       //   if (!rewardEarned) {
  //       //     debugPrint('No reward earned, skipping claim');
  //       //     completer.complete(false);
  //       //     return;
  //       //   }
  //       //
  //       //   // Ad closed and reward earned, now claim reward
  //       //   final apiCaller = ApiCaller();
  //       //   final result = await apiCaller.claimWatchAndEarn();
  //       //
  //       //   result.fold(
  //       //     (failure) {
  //       //       debugPrint('Failed to claim watch & earn: ${failure.errMessage}');
  //       //       completer.complete(false);
  //       //     },
  //       //     (response) {
  //       //       final success = response.data?['status'] == true;
  //       //       if (success) {
  //       //         // Fetch updated profile to get new credits
  //       //         _refreshProfile();
  //       //         completer.complete(true);
  //       //       } else {
  //       //         completer.complete(false);
  //       //       }
  //       //     },
  //       //   );
  //     },
  //   );
  //
  //   return completer.future;
  // }

  // Future<bool> ensureCredits(BuildContext context, int requiredCredits) async {
  //   if (_credits >= requiredCredits) return true;
  //
  //   int deficit = requiredCredits - _credits;
  //   // Assuming 10 credits per ad reward (adjust if backend changes)
  //   int adsNeeded = (deficit / 10).ceil();
  //   if (adsNeeded < 1) adsNeeded = 1;
  //
  //   // Show confirmation dialog
  //   final bool? confirm = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => AlertDialog(
  //       backgroundColor: AppColors.blackTextColor,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Text(
  //         'Insufficient Credits',
  //         style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor),
  //       ),
  //       content: Text(
  //         'You need $requiredCredits credits but have $_credits.\n'
  //         'Watch $adsNeeded ad${adsNeeded > 1 ? 's' : ''} to earn enough credits?',
  //         style: const TextStyle(fontSize: 16, color: AppColors.textColor),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(false),
  //           child: Text('Cancel', style: TextStyle(color: AppColors.textColor.withValues(alpha: 0.8))),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.of(context).pop(true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: AppColors.primary,
  //             foregroundColor: Colors.white,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //           ),
  //           child: Text('Watch Ads', style: TextStyle(color: AppColors.textColor)),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   if (confirm != true) return false;
  //
  //   for (int i = 0; i < adsNeeded; i++) {
  //     if (_credits >= requiredCredits) return true;
  //
  //     if (i > 0) {
  //       showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (context) => const Dialog(
  //           backgroundColor: Colors.transparent,
  //           elevation: 0,
  //           child: Center(
  //             child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
  //           ),
  //         ),
  //       );
  //
  //       await Future.delayed(const Duration(seconds: 2));
  //       if (context.mounted) {
  //         Navigator.of(context).pop();
  //       }
  //     }
  //
  //     final success = await watchAndEarn();
  //     if (!success) {
  //       return false;
  //     }
  //   }
  //
  //   return _credits >= requiredCredits;
  // }

  Future<void> markDailyClaimed() async {
    _canClaimDailyCredits = false;
    notifyListeners();

    if (isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString('last_daily_claim_date_$_id', now.toIso8601String());
    }
  }

  Future<void> clearUserData() async {
    _id = '';
    _credits = 0;
    _email = '';
    _name = '';
    _firebaseUid = '';
    _loginMethod = 'anonymous';
    _photoUrl = '';
    _canClaimDailyCredits = false;
    _createdAt = null;
    _isPremiumUser = false;
    _age = 0;
    _gender = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_backend_id');
    await prefs.remove('user_credits');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_firebase_uid');
    await prefs.remove('user_login_method');
    await prefs.remove('user_photo_url');
    await prefs.remove('user_can_claim_daily');
    await prefs.remove('user_created_at');
    await prefs.remove('user_is_premium');
    await prefs.remove('user_age');
    await prefs.remove('user_gender');

    notifyListeners();
  }
}
