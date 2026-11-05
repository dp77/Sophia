import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:persistent_device_id/persistent_device_id.dart';

class SecureApiClient {
  late final String apiKey;
  String? _userAgent;
  String? androidVersion;
  String? iosVersion;
  String? platform;
  String? onesignalId;
  String? deviceId;

  SecureApiClient({required this.apiKey});

  Future<void> init() async {
    _userAgent = await _buildUserAgent();
  }

  /// Get current Firebase UID (can change after account linking)
  String? get firebaseUid => FirebaseAuth.instance.currentUser?.uid;

  Future<String> _buildUserAgent() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    String osVersion, model;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      platform = 'Android';
      osVersion = androidInfo.version.release;
      model = androidInfo.model;
      androidVersion = packageInfo.version;
    } else {
      final iosInfo = await deviceInfo.iosInfo;
      platform = 'iOS';
      osVersion = iosInfo.systemVersion;
      model = iosInfo.model;
      iosVersion = packageInfo.version;
    }

    deviceId = await PersistentDeviceId.getDeviceId();

    return '${packageInfo.appName}/${packageInfo.version} (build:${packageInfo.buildNumber}) [$platform $osVersion; $model]';
  }

  String _generateSignature(String apiKey, String timestamp, String body) {
    final message = '$apiKey$timestamp$body';
    final key = utf8.encode(apiKey);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  String? userBackendId;

  void updateUserBackendId(String? id) {
    userBackendId = id;
  }

  Map<String, String> getSecureHeaders({String body = '', Map<String, String>? extraHeaders}) {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final signature = _generateSignature(apiKey, timestamp.toString(), body);

    // Get OneSignal ID for push notifications
    // final currentOnesignalId = OneSignal.User.pushSubscription.id ?? '';

    final headers = <String, String>{
      'X-Timestamp': timestamp.toString(),
      'X-Signature': signature,
      'User-Agent': _userAgent ?? 'App/1.0',
    };
    // 'X-Firebase-UID': currentFirebaseUid,
    // 'X-User-ID': userBackendId ?? '',
    // 'X-OneSignal-ID': currentOnesignalId,
    // 'X-Device-ID': deviceId ?? '',
    // 'X-Platform': platform ?? (Platform.isAndroid ? 'Android' : 'iOS'),
    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Interceptor createInterceptor() {
    return SecureHeadersInterceptor(this);
  }

  static Future<String> getApiKey() async {
    try {
      if (Platform.isAndroid) {
        final xmlContent = await rootBundle.loadString('android/app/src/main/res/values/secrets.xml');
        final regex = RegExp(r'<string name="api_key">(.*?)</string>');
        final match = regex.firstMatch(xmlContent);
        if (match != null) {
          return match.group(1) ?? "";
        }
      } else {
        final plist = await rootBundle.loadString('ios/Runner/Secrets.plist');
        final regex = RegExp(r'<key>api_key</key>\s*<string>(.*?)</string>');
        final match = regex.firstMatch(plist);
        if (match != null) {
          return match.group(1) ?? "";
        }
      }
    } catch (e) {
      debugPrint("Error loading API key from assets: $e");
    }
    return "";
  }
}

class SecureHeadersInterceptor extends Interceptor {
  final SecureApiClient secureApiClient;

  SecureHeadersInterceptor(this.secureApiClient);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final body = options.data is String
        ? options.data as String
        : (options.data != null ? jsonEncode(options.data) : '');

    final headers = secureApiClient.getSecureHeaders(body: body);
    options.headers.addAll(headers);

    super.onRequest(options, handler);
  }
}
