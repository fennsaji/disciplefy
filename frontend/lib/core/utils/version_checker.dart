import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/system_config_service.dart';
import '../../shared/widgets/popup.dart';
import '../constants/app_fonts.dart';
import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';
import '../theme/reader_palette.dart';
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
        child: AppUpdateDialog(
          icon: Icons.system_update_alt_rounded,
          tone: PopupTone.gold,
          title: dialogContext.tr(TranslationKeys.appChromeUpdateRequiredTitle),
          body: dialogContext.tr(TranslationKeys.appChromeUpdateRequiredBody),
          currentVersion: currentVersion,
          targetLabel:
              dialogContext.tr(TranslationKeys.appChromeUpdateRequiredVersion),
          targetVersion: minVersion,
          hint: dialogContext.tr(TranslationKeys.appChromeUpdateRequiredHint),
          primaryLabel:
              dialogContext.tr(TranslationKeys.appChromeUpdateUpdateNow),
          onPrimary: () => _openAppStore(platform),
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
      builder: (dialogContext) => AppUpdateDialog(
        icon: Icons.new_releases_outlined,
        tone: PopupTone.accent,
        title: dialogContext.tr(TranslationKeys.appChromeUpdateAvailableTitle),
        body: dialogContext.tr(TranslationKeys.appChromeUpdateAvailableBody),
        currentVersion: currentVersion,
        targetLabel:
            dialogContext.tr(TranslationKeys.appChromeUpdateLatestVersion),
        targetVersion: minVersion,
        primaryLabel: dialogContext.tr(TranslationKeys.appChromeUpdateUpdate),
        onPrimary: () {
          Navigator.pop(dialogContext);
          _openAppStore(platform);
        },
        secondaryLabel: dialogContext.tr(TranslationKeys.appChromeUpdateLater),
        onSecondary: () => Navigator.pop(dialogContext),
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

/// Update prompt in the popup style: tinted icon, gold eyebrow, Poppins
/// title, version panel and pill actions.
/// Public so it can be widget-tested; shown only by [VersionChecker].
class AppUpdateDialog extends StatelessWidget {
  final IconData icon;
  final PopupTone tone;
  final String title;
  final String body;
  final String currentVersion;
  final String targetLabel;
  final String targetVersion;
  final String? hint;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AppUpdateDialog({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.currentVersion,
    required this.targetLabel,
    required this.targetVersion,
    required this.primaryLabel,
    required this.onPrimary,
    this.hint,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    Widget versionRow(String label, String value) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppFonts.inter(fontSize: 13, color: palette.muted),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ],
        );

    return PopupDialog(
      children: [
        PopupHeader(
          icon: PopupIconCircle(icon: icon, tone: tone),
          eyebrow: context.tr(TranslationKeys.appChromeUpdateEyebrow),
          title: title,
          body: body,
        ),
        const SizedBox(height: 18),
        PopupPanel(
          child: Column(
            children: [
              versionRow(
                context.tr(TranslationKeys.appChromeUpdateCurrentVersion),
                currentVersion,
              ),
              const SizedBox(height: 8),
              versionRow(targetLabel, targetVersion),
            ],
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 12),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 12.5,
              color: palette.muted,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 20),
        PopupPrimaryButton(
          label: primaryLabel,
          icon: Icons.download_rounded,
          onPressed: onPrimary,
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 4),
          PopupTextButton(label: secondaryLabel!, onPressed: onSecondary),
        ],
      ],
    );
  }
}
