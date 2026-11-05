import 'dart:async';
import 'package:flutter/material.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
import 'package:girlfriend/data/api_service/api_caller.dart';
import 'package:girlfriend/data/notification/notification_service.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
enum GenerationStatus { idle, loading, completed, failed }

class GenerationProvider extends ChangeNotifier {
  GenerationStatus _status = GenerationStatus.idle;
  String? _imageUrl;
  String? _errorMessage;
  Timer? _timer;
  bool _isLoadingScreenActive = false; // tracks if user is on LoadingScreen

  // Store reference to UserProvider to avoid context access issues
  UserProvider? _userProvider;

  GenerationStatus get status => _status;
  String? get imageUrl => _imageUrl;
  String? get errorMessage => _errorMessage;
  bool get isGenerating => _status == GenerationStatus.loading;

  final ApiCaller _apiCaller = ApiCaller();

  /// Set UserProvider reference (call this during app initialization)
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  /// Call this when LoadingScreen is mounted
  void onLoadingScreenEntered() {
    _isLoadingScreenActive = true;
  }

  /// Call this when LoadingScreen is disposed (user navigated away)
  void onLoadingScreenExited() {
    _isLoadingScreenActive = false;
  }

  Future<void> generateImage(String prompt, String userId, String gfId) async {
    AnalyticsService.instance.event(
      'image_generation_started',
      screenName: 'CreateGirlfriendFlowScreen',
      innerScreenName: 'ImageGenerationStep',
      context: 'character_creation',
    );
    _status = GenerationStatus.loading;
    _imageUrl = null;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiCaller.generateImage(prompt, userId, gfId);
    result.fold(
      (failure) {
        _status = GenerationStatus.failed;
        _errorMessage = failure.errMessage;
        // Only show notification if user is NOT on loading screen
        if (!_isLoadingScreenActive) {
          _showNotification('❌ Generation Failed', _errorMessage!);
        }
        notifyListeners();
      },
      (response) {
        final data = response.data;
        if (data['status'] == true) {
          _checkStatus(data['request_id']);
        } else {
          _status = GenerationStatus.failed;
          _errorMessage = data['message'];
          // Only show notification if user is NOT on loading screen
          if (!_isLoadingScreenActive) {
            _showNotification('❌ Generation Failed', _errorMessage!);
          }
          notifyListeners();
        }
      },
    );
  }

  void _checkStatus(String requestId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final result = await _apiCaller.generateImageStatus(requestId);
      result.fold(
        (failure) {
          timer.cancel();
          _status = GenerationStatus.failed;
          _errorMessage = failure.errMessage;
          // Only show notification if user is NOT on loading screen
          if (!_isLoadingScreenActive) {
            _showNotification('❌ Generation Failed', _errorMessage!);
          }
          notifyListeners();
        },
        (response) {
          final data = response.data;
          if (data['status_field'] == 'completed') {
            timer.cancel();
            _status = GenerationStatus.completed;
            _imageUrl = data['image_url'];
            // Update credits if available in response
            _updateCreditsFromResponse(data);
            if (!_isLoadingScreenActive) {
              _showNotification('✨ Image Ready!', data['message'] ?? 'Your image has been generated successfully!');
            }
            notifyListeners();
          } else if (data['status_field'] == 'failed') {
            timer.cancel();
            _status = GenerationStatus.failed;
            _errorMessage = data['message'] ?? 'Generation failed';
            if (!_isLoadingScreenActive) {
              _showNotification('❌ Generation Failed', _errorMessage!);
            }
            notifyListeners();
          }
        },
      );
    });
  }

  Future<void> _showNotification(String title, String message) async {
    await NotificationService.instance.show(title, message);
  }

  void _updateCreditsFromResponse(Map<String, dynamic> data) {
    if (_userProvider != null && data.containsKey('credits')) {
      final credits = data['credits'];
      if (credits != null) {
        try {
          final creditValue = credits is int ? credits : int.tryParse(credits.toString());
          if (creditValue != null) {
            _userProvider!.updateCredits(creditValue);
            debugPrint('GenerationProvider: Credits updated from API response: $creditValue');
          }
        } catch (e) {
          debugPrint('GenerationProvider: Failed to parse credits: $e');
        }
      } else {
        // Credits are null, refresh profile to get updated credits
        _refreshUserProfile();
      }
    }
  }

  Future<void> _refreshUserProfile() async {
    if (_userProvider != null) {
      try {
        await _userProvider!.refreshProfile();
        debugPrint('GenerationProvider: User profile refreshed successfully');
      } catch (e) {
        debugPrint('GenerationProvider: Failed to refresh user profile: $e');
      }
    }
  }

  void reset() {
    _timer?.cancel();
    _status = GenerationStatus.idle;
    _imageUrl = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
