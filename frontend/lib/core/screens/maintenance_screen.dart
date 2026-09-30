import 'package:flutter/material.dart';

import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/popup.dart';
import '../constants/app_fonts.dart';
import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';
import '../services/system_config_service.dart';
import '../theme/reader_palette.dart';
import '../utils/logger.dart';
import '../widgets/status_message_view.dart';

/// Maintenance Screen
///
/// Full-screen overlay displayed when app is in maintenance mode.
/// Shows maintenance message and retry button.
///
/// Features:
/// - Non-dismissible (no back button)
/// - Custom maintenance message from server
/// - Retry button to re-check status
/// - Responsive design
///
/// Usage:
/// ```dart
/// Navigator.pushReplacement(
///   context,
///   MaterialPageRoute(
///     builder: (context) => MaintenanceScreen(
///       configService: sl<SystemConfigService>(),
///     ),
///   ),
/// );
/// ```
class MaintenanceScreen extends StatefulWidget {
  final SystemConfigService configService;

  const MaintenanceScreen({
    super.key,
    required this.configService,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      // Force refresh config from backend
      await widget.configService.fetchSystemConfig(forceRefresh: true);

      // Check if maintenance mode is still active
      if (!widget.configService.isMaintenanceModeActive) {
        // Maintenance mode disabled - navigate back to app
        if (mounted) {
          // Pop maintenance screen - router will handle redirect
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Error fetching config - show snackbar but keep on maintenance screen
      Logger.error('[MaintenanceScreen] Status check failed', error: e);
      if (mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.appStatusMaintenanceCheckFailed),
          tone: AppSnackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back button from dismissing maintenance screen
      canPop: false,
      child: Scaffold(
        backgroundColor: ReaderPalette.of(context).page,
        body: StatusMessageView(
          icon: Icons.build_circle_outlined,
          tone: PopupTone.gold,
          eyebrow: context.tr(TranslationKeys.appStatusMaintenanceEyebrow),
          title: context.tr(TranslationKeys.appStatusMaintenanceTitle),
          detail: StatusDetailCard(
            widget.configService.maintenanceModeMessage,
          ),
          actions: [
            PopupPrimaryButton(
              key: const Key('maintenance_check_status'),
              label: _isRetrying
                  ? context.tr(TranslationKeys.appStatusMaintenanceChecking)
                  : context.tr(TranslationKeys.appStatusMaintenanceCheck),
              icon: _isRetrying ? null : Icons.refresh_rounded,
              onPressed: _isRetrying ? null : _handleRetry,
            ),
            Text(
              context.tr(TranslationKeys.appStatusMaintenanceBackSoon),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 13,
                color: ReaderPalette.of(context).muted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
