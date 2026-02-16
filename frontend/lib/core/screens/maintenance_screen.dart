import 'package:flutter/material.dart';
import '../services/system_config_service.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check status: $e'),
            backgroundColor: Colors.red,
          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      // Prevent back button from dismissing maintenance screen
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Maintenance Icon
                  Icon(
                    Icons.build_circle_rounded,
                    size: 100,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Maintenance Mode',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      widget.configService.maintenanceModeMessage,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Retry Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isRetrying ? null : _handleRetry,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isRetrying
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _isRetrying ? 'Checking...' : 'Check Status',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info text
                  Text(
                    'We\'ll be back online shortly. Thank you for your patience!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
