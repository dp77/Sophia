import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/api_service/api_caller.dart';
import 'user_provider.dart';

class WatchEarnStatusProvider extends ChangeNotifier {
  final ApiCaller apiCaller = ApiCaller();

  /// Credits one rewarded ad gives, as set by the backend (`credits_per_watch`).
  /// Null until the first status call returns.
  int? creditsPerWatch;

  Future<int?> watchAndEarnStatus(String userId) async {
    final result = await apiCaller.watchAndEarnStatus(userId);
    return result.fold(
      (failure) => null,
      (response) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final perWatch = int.tryParse(data['credits_per_watch']?.toString() ?? '');
          if (perWatch != null && perWatch != creditsPerWatch) {
            creditsPerWatch = perWatch;
            notifyListeners();
          }
          final remaining = data['remaining_today'];
          if (remaining is int) return remaining;
          final parsed = int.tryParse(remaining?.toString() ?? '');
          return parsed;
        }
        return null;
      },
    );
  }
}
