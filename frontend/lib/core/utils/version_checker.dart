import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/system_config_service.dart';
import '../theme/app_colors.dart';
import '../router/app_router.dart';
import 'logger.dart';

/// Version Checker Utility
///
/// Compares app version with minimum required version from server.
/// Shows update dialogs when version mismatch detected.
///
/// Features:
/// - Platform-specific version checking (Android, iOS, Web)
/// - Force update (blocks app access)
/// - Optional update (dismissible notification)
/// - Semantic version comparison
/// - App store redirection
///
/// Usage:
/// ```dart
/// // In main.dart after system config initialization
/// await VersionChecker.checkVersion(systemConfigService);
/// ```
class VersionChecker {
  /// Check app version against server requirements
  ///
  /// Shows update dialog if current version is below minimum required.
  /// Force update blocks access, optional update is dismissible.
  static Future<void> checkVersion(SystemConfigService configService) async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Determine platform
      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else {
        Logger.debug('[VersionChecker] Unsupported platform');
        return;
      }

      // Get minimum required version for platform
      final minVersion =
          configService.config?.versionControl.minVersion[platform] ?? '1.0.0';

      Logger.debug(
          '[VersionChecker] Current: $currentVersion, Min required: $minVersion, Platform: $platform');

      // Compare versions
      if (_isVersionLessThan(currentVersion, minVersion)) {
        Logger.debug('[VersionChecker] Update required!');

        // Check if force update is enabled
        final forceUpdate =
            configService.config?.versionControl.forceUpdate ?? false;

        if (forceUpdate) {
          _showForceUpdateDialog(currentVersion, minVersion, platform);
        } else {
          _showOptionalUpdateDialog(currentVersion, minVersion, platform);
        }
      } else {
        Logger.debug('[VersionChecker] App version is up to date');
      }
    } catch (e) {
      Logger.debug('[VersionChecker] Error checking version: $e');
      // Don't block app on version check failure
    }
  }

  /// Compare semantic versions
  ///
  /// Returns true if current < required
  /// Supports versions like: 1.0.0, 1.2.3, 2.0.0
  static bool _isVersionLessThan(String current, String required) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final requiredParts = required.split('.').map(int.parse).toList();

      // Ensure both have 3 parts (major.minor.patch)
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (requiredParts.length < 3) {
        requiredParts.add(0);
      }

      // Compare major, minor, patch in order
      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < requiredParts[i]) return true;
        if (currentParts[i] > requiredParts[i]) return false;
      }

      return false; // Versions are equal
    } catch (e) {
      Logger.debug('[VersionChecker] Error comparing versions: $e');
      return false; // On error, assume version is ok
    }
  }

  /// Show force update dialog (non-dismissible)
  ///
  /// User must update to continue using the app.
  static void _showForceUpdateDialog(
      String currentVersion, String minVersion, String platform) {
    // Get navigation context
    final context = _getNavigationContext();
    if (context == null) {
      Logger.debug('[VersionChecker] Cannot show dialog - no context');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss
      builder: (dialogContext) => PopScope(
        canPop: false, // Prevent back button
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update_alt, color: AppColors.warning),
              SizedBox(width: 12),
              Text('Update Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A critical update is required to continue using the app.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Text('Current version: $currentVersion'),
              Text('Required version: $minVersion'),
              const SizedBox(height: 16),
              const Text(
                'Please update from your app store to continue.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => _openAppStore(platform),
              icon: const Icon(Icons.download),
              label: const Text('Update Now'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show optional update dialog (dismissible)
  ///
  /// User can choose to update later.
  static void _showOptionalUpdateDialog(
      String currentVersion, String minVersion, String platform) {
    final context = _getNavigationContext();
    if (context == null) {
      Logger.debug('[VersionChecker] Cannot show dialog - no context');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.new_releases_outlined, color: AppColors.info),
            SizedBox(width: 12),
            Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A new version of the app is available with improvements and bug fixes.',
            ),
            const SizedBox(height: 16),
            Text('Current version: $currentVersion'),
            Text('Latest version: $minVersion'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openAppStore(platform);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Update'),
          ),
        ],
      ),
    );
  }

  /// Get navigation context for showing dialogs
  static BuildContext? _getNavigationContext() {
    try {
      // Use AppRouter's root navigator key to get context
      final navigatorState = AppRouter.rootNavigatorKey.currentState;
      return navigatorState?.context;
    } catch (e) {
      Logger.debug('[VersionChecker] Error getting context: $e');
      return null;
    }
  }

  /// Open app store for updates
  ///
  /// Redirects to:
  /// - Google Play Store (Android)
  /// - Apple App Store (iOS)
  /// - Web URL (for web platform)
  static Future<void> _openAppStore(String platform) async {
    String storeUrl;

    switch (platform) {
      case 'android':
        // TODO: Replace with actual package name
        storeUrl =
            'https://play.google.com/store/apps/details?id=com.disciplefy.bible_study';
        break;
      case 'ios':
        // TODO: Replace with actual app store ID
        storeUrl = 'https://apps.apple.com/app/id123456789';
        break;
      case 'web':
        // For web, reload to get latest version
        storeUrl = Uri.base.toString();
        break;
      default:
        Logger.debug('[VersionChecker] Unknown platform: $platform');
        return;
    }

    try {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Logger.debug('[VersionChecker] Cannot launch URL: $storeUrl');
      }
    } catch (e) {
      Logger.debug('[VersionChecker] Error opening app store: $e');
    }
  }
}
