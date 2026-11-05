import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/presentation/widget/sophia_dialog.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:grokbot_widget/grokbot_widget.dart';
import 'package:girlfriend/data/remote_config_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/colors.dart';

class UpdateDialogManager {
  static final UpdateDialogManager _instance = UpdateDialogManager._internal();
  factory UpdateDialogManager() => _instance;
  UpdateDialogManager._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  PackageInfo? _packageInfo;
  String? _currentVersion;
  String? _latestAndroidVersion;
  String? _latestIosVersion;
  bool _isUpdateDialogShown = false;

  // Getters
  String? get currentVersion => _currentVersion;
  String? get latestAndroidVersion => _latestAndroidVersion;
  String? get latestIosVersion => _latestIosVersion;
  bool get isUpdateDialogShown => _isUpdateDialogShown;

  // Initialize the update manager
  Future<void> initialize() async {
    await _loadPackageInfo();
    await _loadRemoteConfig();
  }

  // Load package info
  Future<void> _loadPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = _packageInfo?.buildNumber;
  }

  // Load remote config values
  Future<void> _loadRemoteConfig() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero, // always fetch fresh (for debug)
        ),
      );
      await _remoteConfig.fetchAndActivate();
      _latestAndroidVersion = _remoteConfig.getString('android_version');
      _latestIosVersion = _remoteConfig.getString('ios_version');
      debugPrint("VERSION $_latestAndroidVersion");
    } catch (e) {
      debugPrint('Error loading remote config for update: $e');
    }
  }

  bool isUpdateAvailable() {
    if (_currentVersion == null) return false;
    String? latestVersion;
    if (Platform.isAndroid) {
      latestVersion = _latestAndroidVersion;
    } else if (Platform.isIOS) {
      latestVersion = _latestIosVersion;
    }
    if (latestVersion == null || latestVersion.isEmpty) return false;

    return _compareBuildNumbers(_currentVersion!, latestVersion) < 0;
  }

  int _compareBuildNumbers(String current, String latest) {
    try {
      int currentBuild = int.parse(current);
      int latestBuild = int.parse(latest);

      if (currentBuild < latestBuild) return -1;
      if (currentBuild > latestBuild) return 1;
      return 0;
    } catch (e) {
      debugPrint('Error comparing build numbers: $e');
      return 0;
    }
  }

  Future<bool> showUpdateDialogIfNeeded(BuildContext context) async {
    if (_isUpdateDialogShown) return false;
    if (!isUpdateAvailable()) return false;

    _isUpdateDialogShown = true;
    return await _showUpdateDialog(context);
  }

  Future<bool> _showUpdateDialog(BuildContext context) async {
    return await showSophiaDialog<bool>(
          context: context,
          dismissible: false,
          canPop: false,
          barrierColor: Colors.black.withValues(alpha: 0.75),
          builder: (BuildContext context) {
            return SophiaDialog(
              hero: const SophiaMascotHero(state: GrokBotState.working),
              title: 'Update Available',
              message: RemoteConfigService().forceUpdate['description'] ??
                  'A new version of the app is available and must be installed to continue using the app.',
              body: SophiaNote(
                icon: Icons.new_releases_rounded,
                text: RemoteConfigService().forceUpdate['title'] ?? 'Update Required',
              ),
              actions: [
                AmethystButton(
                  label: 'Update Now',
                  leading: const Icon(Icons.system_update_rounded, color: SophiaColors.champagne, size: 18),
                  onTap: () async {
                    _launchUpdateUrl();
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _launchUpdateUrl() async {
    String url;

    if (Platform.isAndroid) {
      url = RemoteConfigService().forceUpdate['playStoreLink'];
    } else if (Platform.isIOS) {
      url = RemoteConfigService().forceUpdate['appStoreLink'];
    } else {
      url = "https://onelink.to/pckan5";
    }

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch update URL: $url');
      }
    } catch (e) {
      debugPrint('Error launching update URL: $e');
    }
  }

  Future<bool> forceShowUpdateDialog(BuildContext context) async {
    _isUpdateDialogShown = false;
    return await _showUpdateDialog(context);
  }

  void resetUpdateDialogState() {
    _isUpdateDialogShown = false;
  }

  Future<bool> checkAndShowUpdateDialog(BuildContext context) async {
    await initialize();
    return await showUpdateDialogIfNeeded(context);
  }
}
