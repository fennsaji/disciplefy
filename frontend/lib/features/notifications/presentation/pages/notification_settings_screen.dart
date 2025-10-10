// ============================================================================
// Notification Settings Screen
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';
import '../widgets/notification_preference_card.dart';

/// Screen that displays and manages user notification preferences.
///
/// Allows users to view their current notification settings, check OS permission
/// status, and configure which types of notifications they want to receive
/// (daily verse, recommended topics). Uses [NotificationBloc] to load and
/// update preferences, and checks actual device-level notification permissions.
///
/// The screen automatically loads notification preferences on initialization.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<NotificationBloc>()..add(const LoadNotificationPreferences()),
      child: const _NotificationSettingsView(),
    );
  }
}

class _NotificationSettingsView extends StatelessWidget {
  const _NotificationSettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listener: (context, state) {
          if (state is NotificationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is NotificationPreferencesUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Preferences updated'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Reload preferences after update
            context
                .read<NotificationBloc>()
                .add(const LoadNotificationPreferences());
          } else if (state is NotificationPermissionResult) {
            if (state.granted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Notification permissions granted'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Notification permissions denied'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        },
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is NotificationPreferencesLoaded) {
            return _buildPreferencesView(context, state);
          }

          if (state is NotificationError) {
            return _buildErrorView(context, state.message);
          }

          return const Center(
            child: Text('Loading notification settings...'),
          );
        },
      ),
    );
  }

  Widget _buildPreferencesView(
    BuildContext context,
    NotificationPreferencesLoaded state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Permission Status Card
          _buildPermissionCard(context, state.permissionsGranted),

          const SizedBox(height: 24),

          // Preferences Section
          Text(
            'Notification Preferences',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Daily Verse Notification
          NotificationPreferenceCard(
            title: 'Daily Verse',
            description:
                'Receive inspirational Bible verses every morning at 6 AM',
            icon: Icons.book_outlined,
            enabled: state.preferences.dailyVerseEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(dailyVerseEnabled: value),
                  );
            },
          ),

          const SizedBox(height: 12),

          // Recommended Topic Notification
          NotificationPreferenceCard(
            title: 'Recommended Topics',
            description: 'Get personalized study topic suggestions at 8 AM',
            icon: Icons.lightbulb_outline,
            enabled: state.preferences.recommendedTopicEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                      recommendedTopicEnabled: value,
                    ),
                  );
            },
          ),

          const SizedBox(height: 32),

          // Info Section
          _buildInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(BuildContext context, bool permissionsGranted) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  permissionsGranted ? Icons.check_circle : Icons.warning_amber,
                  color: permissionsGranted ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Permission',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        permissionsGranted
                            ? 'Enabled - You will receive notifications'
                            : 'Disabled - Enable to receive notifications',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!permissionsGranted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<NotificationBloc>().add(
                          const RequestNotificationPermissions(),
                        );
                  },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Enable Notifications'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'About Notifications',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Notifications are sent based on your timezone\n'
            '• You can customize which notifications you receive\n'
            '• Tap on a notification to view the content directly\n'
            '• You can disable notifications anytime',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue[900],
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<NotificationBloc>().add(
                      const LoadNotificationPreferences(),
                    );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
