// ============================================================================
// Notification Settings Screen
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';
import '../utils/time_of_day_extensions.dart';
import '../widgets/notification_preference_card.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Handle Android back button - pop to previous page
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr(TranslationKeys.notificationsSettingsTitle)),
          elevation: 0,
        ),
        body: BlocConsumer<NotificationBloc, NotificationState>(
          listener: (context, state) {
            if (state is NotificationError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(state.message), // Error message already from backend
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is NotificationPreferencesUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr(
                      TranslationKeys.notificationsSettingsPreferencesUpdated)),
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
                  SnackBar(
                    content: Text(context.tr(TranslationKeys
                        .notificationsSettingsPermissionsGranted)),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr(TranslationKeys
                        .notificationsSettingsPermissionsDenied)),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              // Reload preferences to show updated permission status
              context
                  .read<NotificationBloc>()
                  .add(const LoadNotificationPreferences());
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

            return Center(
              child: Text(
                  context.tr(TranslationKeys.notificationsSettingsLoading)),
            );
          },
        ), // BlocConsumer (body)
      ), // Scaffold
    ); // PopScope
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
            context.tr(TranslationKeys.notificationsSettingsPreferencesTitle),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Daily Verse Notification
          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsDailyVerseTitle),
            description: context
                .tr(TranslationKeys.notificationsSettingsDailyVerseDescription),
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
            title: context.tr(
                TranslationKeys.notificationsSettingsRecommendedTopicsTitle),
            description: context.tr(TranslationKeys
                .notificationsSettingsRecommendedTopicsDescription),
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

          const SizedBox(height: 12),

          // Streak Reminder Notification with Time Picker
          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsStreakReminderTitle),
            description: context.tr(
                TranslationKeys.notificationsSettingsStreakReminderDescription),
            icon: Icons.bolt,
            enabled: state.preferences.streakReminderEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                      streakReminderEnabled: value,
                    ),
                  );
            },
            // Time picker for reminder time
            trailing: state.preferences.streakReminderEnabled
                ? TextButton.icon(
                    onPressed: () async {
                      // Convert domain TimeOfDayVO to Flutter TimeOfDay for TimePicker
                      final initialTime = state.preferences.streakReminderTime
                          .toFlutterTimeOfDay();

                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      if (picked != null && picked != initialTime) {
                        context.read<NotificationBloc>().add(
                              UpdateNotificationPreferences(
                                streakReminderTime: picked,
                              ),
                            );
                      }
                    },
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      // Convert domain TimeOfDayVO to Flutter TimeOfDay for display
                      state.preferences.streakReminderTime
                          .toFlutterTimeOfDay()
                          .format(context),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 12),

          // Streak Milestone Notification
          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsStreakMilestoneTitle),
            description: context.tr(TranslationKeys
                .notificationsSettingsStreakMilestoneDescription),
            icon: Icons.emoji_events,
            enabled: state.preferences.streakMilestoneEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                      streakMilestoneEnabled: value,
                    ),
                  );
            },
          ),

          const SizedBox(height: 12),

          // Streak Lost Notification
          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsStreakLostTitle),
            description: context
                .tr(TranslationKeys.notificationsSettingsStreakLostDescription),
            icon: Icons.refresh,
            enabled: state.preferences.streakLostEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                      streakLostEnabled: value,
                    ),
                  );
            },
          ),

          const SizedBox(height: 24),

          // Memory Verse Section Title
          Text(
            context.tr(
                TranslationKeys.notificationsSettingsMemoryVerseSectionTitle),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Memory Verse Daily Reminder with Time Picker
          NotificationPreferenceCard(
            title: context.tr(
                TranslationKeys.notificationsSettingsMemoryVerseReminderTitle),
            description: context.tr(TranslationKeys
                .notificationsSettingsMemoryVerseReminderDescription),
            icon: Icons.psychology_outlined,
            enabled: state.preferences.memoryVerseReminderEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                      memoryVerseReminderEnabled: value,
                    ),
                  );
            },
            // Time picker for memory verse reminder time
            trailing: state.preferences.memoryVerseReminderEnabled
                ? TextButton.icon(
                    onPressed: () async {
                      // Convert domain TimeOfDayVO to Flutter TimeOfDay for TimePicker
                      final initialTime = state
                          .preferences.memoryVerseReminderTime
                          .toFlutterTimeOfDay();

                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      if (picked != null && picked != initialTime) {
                        context.read<NotificationBloc>().add(
                              UpdateNotificationPreferences(
                                memoryVerseReminderTime: picked,
                              ),
                            );
                      }
                    },
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      // Convert domain TimeOfDayVO to Flutter TimeOfDay for display
                      state.preferences.memoryVerseReminderTime
                          .toFlutterTimeOfDay()
                          .format(context),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : null,
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
                        context.tr(TranslationKeys
                            .notificationsSettingsPermissionTitle),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        permissionsGranted
                            ? context.tr(TranslationKeys
                                .notificationsSettingsPermissionEnabled)
                            : context.tr(TranslationKeys
                                .notificationsSettingsPermissionDisabled),
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
                  label: Text(context
                      .tr(TranslationKeys.notificationsSettingsEnableButton)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ), // Scaffold
    ); // PopScope
  }

  Widget _buildInfoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use explicit colors for better visibility in dark mode
    final backgroundColor = isDark
        ? const Color(0xFF2196F3)
            .withOpacity(0.15) // Brighter blue with 15% opacity
        : Colors.blue.withOpacity(0.1);

    final borderColor = isDark
        ? const Color(0xFF64B5F6).withOpacity(0.4) // Light blue border
        : Colors.blue.withOpacity(0.3);

    final iconColor = isDark
        ? const Color(0xFF90CAF9) // Light blue for dark mode
        : Colors.blue;

    final textColor = isDark
        ? const Color(0xFFE3F2FD) // Very light blue for dark mode
        : Colors.blue[900];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: iconColor),
              const SizedBox(width: 8),
              Text(
                context.tr(TranslationKeys.notificationsSettingsAboutTitle),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(TranslationKeys.notificationsSettingsAboutInfo),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
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
              context.tr(TranslationKeys.notificationsSettingsErrorTitle),
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
              label:
                  Text(context.tr(TranslationKeys.notificationsSettingsRetry)),
            ),
          ],
        ),
      ),
    );
  }
}
