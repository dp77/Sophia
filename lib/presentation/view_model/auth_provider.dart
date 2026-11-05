import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:girlfriend/data/api_service/api_caller.dart';
import 'package:girlfriend/data/chat_language_storage.dart';
import 'package:girlfriend/presentation/view_model/chat_list_provider.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:google_one_tap_sign_in/google_one_tap_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:persistent_device_id/persistent_device_id.dart';
import 'package:provider/provider.dart';
import '../../data/api_service/api_initializer.dart';
import '../../data/db/database_helper.dart';
import '../../data/navigation_service.dart';
import 'user_character_provider.dart';

class BackendAuthFailure implements Exception {
  final String message;
  BackendAuthFailure(this.message);
  @override
  String toString() => message;
}

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _firebaseUser;
  bool _isSigningIn = false;
  bool _isInitialized = false;
  String? _errorMessage;
  UserProvider? _userProvider;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  User? get firebaseUser => _firebaseUser;
  bool get isSigningIn => _isSigningIn;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated {
    if (_firebaseUser != null) return true;
    final u = _userProvider;
    if (u == null) return false;
    return u.isLoggedIn && !u.isAnonymous;
  }

  bool get isAnonymous {
    if (_firebaseUser != null) return _firebaseUser!.isAnonymous;
    final u = _userProvider;
    if (u == null) return true;
    return u.isAnonymous;
  }

  String? get firebaseUid => _firebaseUser?.uid;
  String? get errorMessage => _errorMessage;
  bool get hasLinkedAccount =>
      _firebaseUser != null && !_firebaseUser!.isAnonymous;
  String? get displayName => _firebaseUser?.displayName;
  String? get email => _firebaseUser?.email;
  String? get photoURL => _firebaseUser?.photoURL;

  AuthProvider() {
    _initAuthState();
  }

  /// Set UserProvider reference for auth state changes
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  void _initAuthState() {
    _firebaseUser = _auth.currentUser;
    _auth.authStateChanges().listen((User? user) {
      _firebaseUser = user;
      // Sync profile fields only when backend auth is already established.
      if (_userProvider != null &&
          user != null &&
          _userProvider!.isLoggedIn &&
          !_userProvider!.isAnonymous) {
        syncAllUserDataToUserProvider(_userProvider!);
      }
      notifyListeners();
    });
  }

  Future<bool> initializeAuth({
    required UserProvider userProvider,
    required ChatListProvider chatListProvider,
  }) async {
    try {
      debugPrint('AuthProvider: Initializing auth...');

      // Set UserProvider reference for auth state changes
      setUserProvider(userProvider);

      // 1. Try to load user from local storage
      final bool hasLocalUser = await userProvider.loadFromLocal();

      if (hasLocalUser) {
        debugPrint('AuthProvider: Local user found - ID: ${userProvider.id}');

        // Sync ID with API client
        if (ApiInitializer.secureApiClient != null) {
          ApiInitializer.secureApiClient!.updateUserBackendId(userProvider.id);
        }

        // Refresh profile from API in background to ensure data is up to date
        // (This satisfies the requirement to get name/credits from getProfile)
        userProvider.refreshProfile();

        await syncAllUserDataToUserProvider(userProvider);
        chatListProvider.refresh(userProvider.id);

        _isInitialized = true;
        notifyListeners();
        return true;
      }

      // 2. No local user, check for Firebase user or use Device ID
      if (_auth.currentUser != null) {
        _firebaseUser = _auth.currentUser;
        debugPrint(
          'AuthProvider: Firebase user found - UID: ${_firebaseUser?.uid}',
        );

        // Determine sync type
        String syncType = 'device_id';
        for (final provider in _firebaseUser!.providerData) {
          if (provider.providerId == 'google.com') {
            syncType = 'google';
            break;
          } else if (provider.providerId == 'apple.com') {
            syncType = 'apple';
            break;
          }
        }

        await _syncRegisterLogin(
          type: syncType,
          user: _firebaseUser,
          userProvider: userProvider,
          chatListProvider: chatListProvider,
        );
      } else {
        // No Firebase user - Use Device ID
        debugPrint(
          'AuthProvider: No user found, using device-based authentication...',
        );
        await _syncRegisterLogin(
          type: 'device_id',
          userProvider: userProvider,
          chatListProvider: chatListProvider,
        );
      }

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthProvider: Error initializing auth: $e');
      _errorMessage = 'Failed to initialize authentication';
      _isInitialized = true;
      notifyListeners();
      return false;
    }
  }

  Future<void> signInWithGoogle({
    required String? webClientId,
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
    Function(String)? onSuccess,
    Function(String)? onError,
  }) async {
    if (Platform.isAndroid) {
      await _signInWithGoogleOneTap(
        webClientId: webClientId,
        userProvider: userProvider,
        chatListProvider: chatListProvider,
        onSuccess: onSuccess,
        onError: onError,
      );
    } else if (Platform.isIOS) {
      await _signInWithGoogleStandard(
        userProvider: userProvider,
        chatListProvider: chatListProvider,
        onSuccess: onSuccess,
        onError: onError,
      );
    } else {
      _errorMessage = 'Google Sign-In not supported on this platform';
      onError?.call(_errorMessage!);
    }
  }

  Future<void> _signInWithGoogleOneTap({
    required String? webClientId,
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
    Function(String)? onSuccess,
    Function(String)? onError,
  }) async {
    setSigningIn(true);
    _errorMessage = null;

    try {
      if (webClientId == null || webClientId.isEmpty) {
        _errorMessage = 'Web Client ID not configured';
        setSigningIn(false);
        onError?.call(_errorMessage!);
        return;
      }

      final result = await GoogleOneTapSignIn.handleSignIn(
        webClientId: webClientId,
      );

      if (result.isTemporaryBlock) {
        _errorMessage = 'Sign-in temporarily blocked. Please try again later.';
        setSigningIn(false);
        onError?.call(_errorMessage!);
        return;
      }

      if (result.isCanceled) {
        _errorMessage = 'Sign-in was canceled';
        setSigningIn(false);
        onError?.call(_errorMessage!);
        return;
      }

      if (result.isFail) {
        _errorMessage = 'Sign-in failed. Please try again.';
        setSigningIn(false);
        onError?.call(_errorMessage!);
        return;
      }

      if (result.isOk && result.data != null) {
        final idToken = result.data!.idToken;
        final email = result.data!.username;

        if (idToken != null && idToken.isNotEmpty) {
          final credential = GoogleAuthProvider.credential(idToken: idToken);

          UserCredential userCredential;

          if (_firebaseUser != null && _firebaseUser!.isAnonymous) {
            try {
              debugPrint(
                'AuthProvider: Linking anonymous account with Google...',
              );
              userCredential = await _firebaseUser!.linkWithCredential(
                credential,
              );
              debugPrint('AuthProvider: Account linked successfully');
            } on FirebaseAuthException catch (e) {
              if (e.code == 'credential-already-in-use') {
                debugPrint(
                  'AuthProvider: Credential already in use, signing in directly...',
                );
                userCredential = await _auth.signInWithCredential(credential);
              } else {
                rethrow;
              }
            }
          } else {
            userCredential = await _auth.signInWithCredential(credential);
          }

          _firebaseUser = userCredential.user;

          try {
            await _syncRegisterLogin(
              type: 'google',
              user: userCredential.user,
              userProvider: userProvider,
              chatListProvider: chatListProvider,
            );
          } on BackendAuthFailure catch (e) {
            await _rollbackAfterBackendFailure(
              userProvider: userProvider,
              chatListProvider: chatListProvider,
            );
            _errorMessage = e.message;
            setSigningIn(false);
            onError?.call(_errorMessage!);
            return;
          }

          setSigningIn(false);
          final successMessage =
              'Signed in as ${userCredential.user?.displayName ?? email ?? "User"} (Google)';
          onSuccess?.call(successMessage);
        } else {
          _errorMessage = 'Failed to get ID token from Google Sign-In';
          setSigningIn(false);
          onError?.call(_errorMessage!);
        }
      } else {
        setSigningIn(false);
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      setSigningIn(false);
      debugPrint('AuthProvider: Google One Tap Firebase error: ${e.code}');
      onError?.call(_errorMessage!);
    } catch (e) {
      _errorMessage = 'Error signing in with Google: ${e.toString()}';
      setSigningIn(false);
      debugPrint('AuthProvider: Google One Tap error: $e');
      onError?.call(_errorMessage!);
    }
  }

  Future<void> _signInWithGoogleStandard({
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
    Function(String)? onSuccess,
    Function(String)? onError,
  }) async {
    setSigningIn(true);
    _errorMessage = null;

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _errorMessage = 'Sign-in was canceled';
        setSigningIn(false);
        onError?.call(_errorMessage!);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;

      if (_firebaseUser != null && _firebaseUser!.isAnonymous) {
        try {
          debugPrint('AuthProvider: Linking anonymous account with Google...');
          userCredential = await _firebaseUser!.linkWithCredential(credential);
          debugPrint('AuthProvider: Account linked successfully');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            debugPrint(
              'AuthProvider: Credential already in use, signing in directly...',
            );
            userCredential = await _auth.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        userCredential = await _auth.signInWithCredential(credential);
      }

      _firebaseUser = userCredential.user;

      try {
        await _syncRegisterLogin(
          type: 'google',
          user: userCredential.user,
          userProvider: userProvider,
          chatListProvider: chatListProvider,
        );
      } on BackendAuthFailure catch (e) {
        await _rollbackAfterBackendFailure(
          userProvider: userProvider,
          chatListProvider: chatListProvider,
        );
        _errorMessage = e.message;
        setSigningIn(false);
        onError?.call(_errorMessage!);
        return;
      }

      setSigningIn(false);
      final successMessage =
          'Signed in as ${userCredential.user?.displayName ?? userCredential.user?.email ?? "User"} (Google)';
      onSuccess?.call(successMessage);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      setSigningIn(false);
      debugPrint('AuthProvider: Google Sign-In Firebase error: ${e.code}');
      onError?.call(_errorMessage!);
    } catch (e) {
      _errorMessage = 'Error signing in with Google: ${e.toString()}';
      setSigningIn(false);
      debugPrint('AuthProvider: Google Sign-In error: $e');
      onError?.call(_errorMessage!);
    }
  }

  Future<void> signInWithApple({
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
    Function(String)? onSuccess,
    Function(String)? onError,
  }) async {
    if (!Platform.isIOS) {
      _errorMessage = 'Apple Sign-In is only available on iOS';
      onError?.call(_errorMessage!);
      return;
    }

    setSigningIn(true);
    _errorMessage = null;

    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      UserCredential userCredential;

      if (_firebaseUser != null && _firebaseUser!.isAnonymous) {
        try {
          debugPrint('AuthProvider: Linking anonymous account with Apple...');
          userCredential = await _firebaseUser!.linkWithProvider(appleProvider);
          debugPrint('AuthProvider: Account linked successfully');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            debugPrint(
              'AuthProvider: Credential already in use, signing in directly...',
            );
            userCredential = await _auth.signInWithProvider(appleProvider);
          } else {
            rethrow;
          }
        }
      } else {
        userCredential = await _auth.signInWithProvider(appleProvider);
      }

      if (userCredential.user != null) {
        _firebaseUser = userCredential.user;

        try {
          await _syncRegisterLogin(
            type: 'apple',
            user: userCredential.user,
            userProvider: userProvider,
            chatListProvider: chatListProvider,
          );
        } on BackendAuthFailure catch (e) {
          await _rollbackAfterBackendFailure(
            userProvider: userProvider,
            chatListProvider: chatListProvider,
          );
          _errorMessage = e.message;
          setSigningIn(false);
          onError?.call(_errorMessage!);
          return;
        }

        setSigningIn(false);
        final user = userCredential.user!;
        final successMessage =
            'Signed in as ${user.displayName ?? user.email ?? "User"} (Apple)';
        onSuccess?.call(successMessage);
      } else {
        _errorMessage = 'Apple sign-in failed. Please try again.';
        setSigningIn(false);
        onError?.call(_errorMessage!);
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      setSigningIn(false);
      debugPrint('AuthProvider: Apple sign-in Firebase error: ${e.code}');
      onError?.call(_errorMessage!);
    } catch (e) {
      _errorMessage = 'Error signing in with Apple: ${e.toString()}';
      setSigningIn(false);
      debugPrint('AuthProvider: Apple sign-in error: $e');
      onError?.call(_errorMessage!);
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
    Function(String)? onSuccess,
    Function(String)? onError,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();

    if (normalizedEmail.isEmpty) {
      _errorMessage = 'Email is required';
      onError?.call(_errorMessage!);
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      _errorMessage = 'Enter a valid email';
      onError?.call(_errorMessage!);
      return;
    }
    if (normalizedPassword.isEmpty) {
      _errorMessage = 'Password is required';
      onError?.call(_errorMessage!);
      return;
    }
    if (normalizedPassword.length < 8) {
      _errorMessage = 'Password must be at least 8 characters';
      onError?.call(_errorMessage!);
      return;
    }

    setSigningIn(true);
    _errorMessage = null;

    try {
      await _syncRegisterLogin(
        type: 'email_password',
        email: normalizedEmail,
        password: normalizedPassword,
        userProvider: userProvider,
        chatListProvider: chatListProvider,
      );
      setSigningIn(false);
      onSuccess?.call('Signed in as $normalizedEmail');
    } on BackendAuthFailure catch (e) {
      _errorMessage = e.message;
      setSigningIn(false);
      onError?.call(_errorMessage!);
    } catch (e) {
      _errorMessage = 'Error signing in with email/password: ${e.toString()}';
      setSigningIn(false);
      onError?.call(_errorMessage!);
    }
  }

  Future<void> _syncRegisterLogin({
    required String type,
    User? user,
    String? email,
    String? password,
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
  }) async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';
      final deviceId = await PersistentDeviceId.getDeviceId();
      final onesignalId = await _resolveOneSignalId();
      final TimezoneInfo currentTimeZone =
          await FlutterTimezone.getLocalTimezone();
      Map<String, dynamic> payload;
      if (type == 'device_id') {
        payload = {
          'type': 'device_id',
          'device_id': deviceId,
          'name': 'Anonymous',
          'email': '',
          'onesignal_id': onesignalId,
          'photo_url': '',
          'platform': platform,
          'timezone': currentTimeZone.identifier,
        };
      } else if (type == 'google' && user != null) {
        final googleUid = _getProviderUid(user, 'google.com') ?? user.uid;
        payload = {
          'type': 'google',
          'google_id': googleUid,
          'name': user.displayName ?? 'Anonymous',
          'email': user.email ?? '',
          'onesignal_id': onesignalId,
          'photo_url': user.photoURL ?? '',
          'platform': platform,
          'timezone': currentTimeZone.identifier,
        };
      } else if (type == 'apple' && user != null) {
        final appleUid = _getProviderUid(user, 'apple.com') ?? user.uid;
        payload = {
          'type': 'apple',
          'apple_id': appleUid,
          'name': user.displayName ?? user.email ?? 'Anonymous',
          'email': user.email ?? '',
          'platform': 'ios',
          'onesignal_id': onesignalId,
          'photo_url': user.photoURL ?? '',
          'timezone': currentTimeZone.identifier,
        };
      } else if (type == 'email_password' &&
          email != null &&
          password != null) {
        payload = {
          'type': 'email_password',
          'email': email,
          'password': password,
          'onesignal_id': onesignalId,
          'platform': platform,
          'timezone': currentTimeZone.identifier,
        };
      } else {
        throw BackendAuthFailure('Invalid authentication payload');
      }

      final apiCaller = ApiCaller();
      final result = await apiCaller.registerLogin(payload);

      await result.fold(
        (failure) async {
          throw BackendAuthFailure(failure.errMessage);
        },
        (response) async {
          final data = response.data;
          if (data['status'] != true) {
            throw BackendAuthFailure(
              (data['message'] ?? 'Authentication failed').toString(),
            );
          }
          if (data is Map<String, dynamic>) {
            final userData = data['user'] ?? data;
            final userId =
                data['user_id']?.toString() ?? userData['id']?.toString();

            if (userId == null || userId.isEmpty) {
              throw BackendAuthFailure('Authentication failed');
            }

            chatListProvider?.clear();
            await DatabaseHelper().clearAllData();
            final credits = userData['credits'];
            final int? creditsValue = credits != null
                ? (credits is int ? credits : int.tryParse(credits.toString()))
                : null;

            await userProvider.setUserData(
              id: userId,
              credits: creditsValue,
              name: userData['name'],
              email: userData['email'],
              loginMethod: type == 'device_id' ? 'anonymous' : type,
              photoUrl: userData['photo_url'],
              canClaimDailyCredits:
                  userData['can_daily_claim'] ??
                  userData['can_claim_daily_credits'],
              isPremiumUser: userData['is_premium'] ?? false,
              chatLanguage: userData['chat_language'] ?? '',
            );

            ApiInitializer.secureApiClient?.updateUserBackendId(userId);

            final serverChatLanguage = (userData['chat_language'] ?? '').toString().trim();
            if (serverChatLanguage.isEmpty) {
              if (type == 'google' || type == 'apple') {
                await _applyGuestChatLanguageSilently(userProvider);
              }
            }

            await userProvider.refreshProfile();
            await _syncOneSignalForUser(userId);

            if (chatListProvider != null && userId.isNotEmpty) {
              await chatListProvider.refresh(userId);
            }
            await _refreshCompanions();

            debugPrint(
              'AuthProvider: User synchronization complete for ID: $userId',
            );
          }
        },
      );
    } on BackendAuthFailure {
      rethrow;
    } catch (e) {
      debugPrint('AuthProvider: _syncRegisterLogin error: $e');
      throw BackendAuthFailure('Authentication failed. Please try again.');
    }
  }

  Future<void> _applyGuestChatLanguageSilently(UserProvider userProvider) async {
    try {
      await ChatLanguageStorage.instance.ensureLoaded();
      final storedCode = ChatLanguageStorage.instance.code.trim();
      final code = storedCode.isEmpty ? ChatLanguageStorage.defaultCode : storedCode;
      final option = ChatLanguageStorage.options.firstWhere(
        (o) => o.code == code,
        orElse: () => ChatLanguageStorage.options.firstWhere((o) => o.code == ChatLanguageStorage.defaultCode),
      );
      final language = option?.englishName ?? 'English';

      final msg = await userProvider.updateChatLanguage(language);
      if (msg != null) return;
    } catch (_) {}

    try {
      await userProvider.setUserData(chatLanguage: 'English');
      await userProvider.updateChatLanguage('English');
    } catch (_) {}
    try {
      await ChatLanguageStorage.instance.setCode(ChatLanguageStorage.defaultCode);
    } catch (_) {}
  }

  Future<String> _resolveOneSignalId({int maxAttempts = 5}) async {
    for (int i = 0; i < maxAttempts; i++) {
      final id = (OneSignal.User.pushSubscription.id ?? '').trim();
      if (id.isNotEmpty) return id;
      await Future.delayed(Duration(milliseconds: 350 * (i + 1)));
    }
    return '';
  }

  Future<void> _syncOneSignalForUser(String userId) async {
    if (userId.isEmpty) return;
    final oneSignalId = await _resolveOneSignalId();
    if (oneSignalId.isEmpty) return;
    final apiCaller = ApiCaller();
    await apiCaller.registerOneSignal(userId, oneSignalId);
  }

  Future<void> _rollbackAfterBackendFailure({
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
  }) async {
    final previousName = userProvider.name.trim();
    final previousEmail = userProvider.email.trim();
    final previousPhotoUrl = userProvider.photoUrl.trim();
    final previousCredits = userProvider.credits;
    final hadLocalUser = userProvider.isLoggedIn;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
    _firebaseUser = null;
    if (hadLocalUser) {
      await userProvider.setUserData(
        name: previousName.isNotEmpty ? previousName : 'Guest User',
        email: previousEmail,
        photoUrl: previousPhotoUrl,
        credits: previousCredits,
        loginMethod: 'anonymous',
      );
      return;
    }
    await userProvider.clearUserData();
    chatListProvider?.clear();
    await DatabaseHelper().clearAllData();
    ApiInitializer.secureApiClient?.updateUserBackendId(null);
    try {
      await _syncRegisterLogin(
        type: 'device_id',
        userProvider: userProvider,
        chatListProvider: chatListProvider,
      );
    } catch (_) {
      await userProvider.setUserData(
        name: previousName.isNotEmpty ? previousName : 'Guest User',
        email: previousEmail,
        photoUrl: previousPhotoUrl,
        credits: previousCredits,
        loginMethod: 'anonymous',
      );
    }
  }

  String? _getProviderUid(User user, String providerId) {
    for (final p in user.providerData) {
      if (p.providerId == providerId) return p.uid;
    }
    return null;
  }

  Future<void> syncDeviceAuth(
    UserProvider userProvider, {
    ChatListProvider? chatListProvider,
  }) async {
    if (_firebaseUser != null) return;
    await _syncRegisterLogin(
      type: 'device_id',
      userProvider: userProvider,
      chatListProvider: chatListProvider,
    );
  }

  // Future<bool> _syncWithBackend(User? user, {required UserProvider userProvider}) async {
  //   // Note: user can be null for device-based auth
  //
  //   try {
  //     final apiCaller = ApiCaller();
  //     final result = await apiCaller.firebaseAuth(
  //       firebaseUid: user?.uid, // Can be null now
  //       email: user?.email,
  //       name: user?.displayName,
  //       photoUrl: user?.photoURL,
  //       isAnonymous: user?.isAnonymous ?? true, // Default to true if user is null (device auth)
  //     );
  //
  //     return result.fold(
  //       (failure) {
  //         debugPrint('AuthProvider: Backend sync error: ${failure.errMessage}');
  //         return false;
  //       },
  //       (response) async {
  //         debugPrint('AuthProvider: Backend sync success: ${response.statusCode}');
  //         if (response.data != null) {
  //           try {
  //             final responseData = response.data;
  //             if (responseData is Map<String, dynamic> &&
  //                 responseData['status'] == true &&
  //                 responseData['user'] != null) {
  //               final userData = responseData['user'] as Map<String, dynamic>;
  //               userProvider.setUserData(
  //                 id: userData['id']?.toString(),
  //                 credits: userData['credits'] as int?,
  //                 email: userData['email'] as String?,
  //                 name: userData['name'] as String?,
  //                 firebaseUid: userData['firebase_uid'] as String?,
  //                 loginMethod: (user?.isAnonymous ?? true) ? 'anonymous' : _getLoginMethod(user!),
  //                 photoUrl: userData['photo_url'] as String?,
  //                 createdAt: userData['created_at'] as String?,
  //                 canClaimDailyCredits: userData['can_claim_daily_credits'] as bool?,
  //                 isPremiumUser: userData['is_premium'] ?? false,
  //               );
  //
  //               // CRITICAL: Save User Backend ID for headers
  //               if (userData['id'] != null) {
  //                 final userId = userData['id'].toString();
  //                 final prefs = await SharedPreferences.getInstance();
  //                 await prefs.setString('user_backend_id', userId);
  //
  //                 if (ApiInitializer.secureApiClient != null) {
  //                   ApiInitializer.secureApiClient!.updateUserBackendId(userId);
  //                 }
  //               }
  //
  //               debugPrint('AuthProvider: User data stored in provider');
  //               return true;
  //             }
  //           } catch (e) {
  //             debugPrint('AuthProvider: Error parsing user data: $e');
  //           }
  //         }
  //         return false;
  //       },
  //     );
  //   } catch (e) {
  //     debugPrint('AuthProvider: Error syncing with backend: $e');
  //     return false;
  //   }
  // }

  // String _getLoginMethod(User user) {
  //   for (final provider in user.providerData) {
  //     if (provider.providerId == 'google.com') return 'google';
  //     if (provider.providerId == 'apple.com') return 'apple';
  //   }
  //   return 'anonymous';
  // }

  // Future<bool> syncCurrentUser(UserProvider userProvider) async {
  //   // Allow sync even if _firebaseUser is null (for device-based auth)
  //   // return _syncWithBackend(_firebaseUser, userProvider: userProvider);
  // }

  Future<void> signOut({
    required UserProvider userProvider,
    ChatListProvider? chatListProvider,
  }) async {
    try {
      if (_firebaseUser != null) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          debugPrint('AuthProvider: Google sign out error (non-critical): $e');
        }

        await _auth.signOut();
      }

      _firebaseUser = null;

      debugPrint('AuthProvider: Reverting to device-based authentication...');
      await userProvider.clearUserData();
      chatListProvider?.clear();
      await DatabaseHelper().clearAllData();

      if (ApiInitializer.secureApiClient != null) {
        ApiInitializer.secureApiClient!.updateUserBackendId(null);
      }
      await _syncRegisterLogin(
        type: 'device_id',
        userProvider: userProvider,
        chatListProvider: chatListProvider,
      );
      await _refreshCompanions();

      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: Error signing out: $e');
      rethrow;
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-verification-code':
        return 'Invalid verification code.';
      case 'invalid-verification-id':
        return 'Invalid verification ID.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different user account.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  void setSigningIn(bool value) {
    _isSigningIn = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sync photo URL from Firebase to UserProvider
  Future<void> syncPhotoUrlToUserProvider(UserProvider userProvider) async {
    final firebasePhotoUrl = _firebaseUser?.photoURL;
    if (firebasePhotoUrl != null && firebasePhotoUrl != userProvider.photoUrl) {
      await userProvider.updatePhotoUrl(firebasePhotoUrl);
      debugPrint(
        'AuthProvider: Photo URL synced to UserProvider: $firebasePhotoUrl',
      );
    }
  }

  /// Sync email from Firebase to UserProvider
  Future<void> syncEmailToUserProvider(UserProvider userProvider) async {
    final firebaseEmail = _firebaseUser?.email;
    if (firebaseEmail != null && firebaseEmail != userProvider.email) {
      await userProvider.setUserData(email: firebaseEmail);
      debugPrint('AuthProvider: Email synced to UserProvider: $firebaseEmail');
    }
  }

  /// Sync display name from Firebase to UserProvider
  Future<void> syncDisplayNameToUserProvider(UserProvider userProvider) async {
    final firebaseDisplayName = _firebaseUser?.displayName;
    if (firebaseDisplayName != null &&
        firebaseDisplayName != userProvider.name) {
      await userProvider.setUserData(name: firebaseDisplayName);
      debugPrint(
        'AuthProvider: Display name synced to UserProvider: $firebaseDisplayName',
      );
    }
  }

  /// Sync all user data from Firebase to UserProvider
  Future<void> syncAllUserDataToUserProvider(UserProvider userProvider) async {
    await Future.wait([
      syncPhotoUrlToUserProvider(userProvider),
      syncEmailToUserProvider(userProvider),
      syncDisplayNameToUserProvider(userProvider),
    ]);
  }

  Future<void> _refreshCompanions() async {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    try {
      await context.read<UserCharacterProvider>().fetchCompanions();
    } catch (_) {}
  }
}
