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
import '../../../../core/theme/app_colors.dart';
import '../../../../core/i18n/translation_keys.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            context.tr(TranslationKeys.notificationsSettingsTitle),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ),
        body: BlocConsumer<NotificationBloc, NotificationState>(
          listener: (context, state) {
            if (state is NotificationError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('Something went wrong. Please try again.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            } else if (state is NotificationPreferencesUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr(
                      TranslationKeys.notificationsSettingsPreferencesUpdated)),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );
              context
                  .read<NotificationBloc>()
                  .add(const LoadNotificationPreferences());
            } else if (state is NotificationPermissionResult) {
              if (state.granted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr(TranslationKeys
                        .notificationsSettingsPermissionsGranted)),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr(TranslationKeys
                        .notificationsSettingsPermissionsDenied)),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
              context
                  .read<NotificationBloc>()
                  .add(const LoadNotificationPreferences());
            }
          },
          builder: (context, state) {
            if (state is NotificationLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              );
            }
            if (state is NotificationPreferencesLoaded) {
              return _buildPreferencesView(context, state);
            }
            if (state is NotificationError) {
              return _buildErrorView(
                  context, 'Something went wrong. Please try again.');
            }
            return Center(
              child: Text(
                  context.tr(TranslationKeys.notificationsSettingsLoading)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreferencesView(
    BuildContext context,
    NotificationPreferencesLoaded state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Permission Status Card
          _buildPermissionCard(context, state.permissionsGranted),

          const SizedBox(height: 28),

          // Notification Preferences Section
          _buildSectionHeader(
            context,
            context.tr(TranslationKeys.notificationsSettingsPreferencesTitle),
          ),
          const SizedBox(height: 12),

          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsDailyVerseTitle),
            description: context
                .tr(TranslationKeys.notificationsSettingsDailyVerseDescription),
            icon: Icons.book_rounded,
            enabled: state.preferences.dailyVerseEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(dailyVerseEnabled: value),
                  );
            },
          ),
          const SizedBox(height: 10),

          NotificationPreferenceCard(
            title: context.tr(
                TranslationKeys.notificationsSettingsRecommendedTopicsTitle),
            description: context.tr(TranslationKeys
                .notificationsSettingsRecommendedTopicsDescription),
            icon: Icons.lightbulb_rounded,
            enabled: state.preferences.recommendedTopicEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                        recommendedTopicEnabled: value),
                  );
            },
          ),
          const SizedBox(height: 10),

          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsStreakReminderTitle),
            description: context.tr(
                TranslationKeys.notificationsSettingsStreakReminderDescription),
            icon: Icons.bolt_rounded,
            enabled: state.preferences.streakReminderEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(streakReminderEnabled: value),
                  );
            },
            trailing: state.preferences.streakReminderEnabled
                ? _buildTimePicker(
                    context,
                    state.preferences.streakReminderTime.toFlutterTimeOfDay(),
                    (picked) {
                      context.read<NotificationBloc>().add(
                            UpdateNotificationPreferences(
                                streakReminderTime: picked),
                          );
                    },
                  )
                : null,
          ),
          const SizedBox(height: 10),

          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsStreakMilestoneTitle),
            description: context.tr(TranslationKeys
                .notificationsSettingsStreakMilestoneDescription),
            icon: Icons.emoji_events_rounded,
            enabled: state.preferences.streakMilestoneEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                        streakMilestoneEnabled: value),
                  );
            },
          ),
          const SizedBox(height: 10),

          NotificationPreferenceCard(
            title: context
                .tr(TranslationKeys.notificationsSettingsStreakLostTitle),
            description: context
                .tr(TranslationKeys.notificationsSettingsStreakLostDescription),
            icon: Icons.refresh_rounded,
            enabled: state.preferences.streakLostEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(streakLostEnabled: value),
                  );
            },
          ),

          const SizedBox(height: 28),

          // Memory Verse Section
          _buildSectionHeader(
            context,
            context.tr(
                TranslationKeys.notificationsSettingsMemoryVerseSectionTitle),
          ),
          const SizedBox(height: 12),

          NotificationPreferenceCard(
            title: context.tr(
                TranslationKeys.notificationsSettingsMemoryVerseReminderTitle),
            description: context.tr(TranslationKeys
                .notificationsSettingsMemoryVerseReminderDescription),
            icon: Icons.psychology_rounded,
            enabled: state.preferences.memoryVerseReminderEnabled,
            onChanged: (value) {
              context.read<NotificationBloc>().add(
                    UpdateNotificationPreferences(
                        memoryVerseReminderEnabled: value),
                  );
            },
            trailing: state.preferences.memoryVerseReminderEnabled
                ? _buildTimePicker(
                    context,
                    state.preferences.memoryVerseReminderTime
                        .toFlutterTimeOfDay(),
                    (picked) {
                      context.read<NotificationBloc>().add(
                            UpdateNotificationPreferences(
                                memoryVerseReminderTime: picked),
                          );
                    },
                  )
                : null,
          ),

          const SizedBox(height: 28),
          _buildInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(
    BuildContext context,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onPicked,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppColors.brandPrimary;

    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                    primary: primary,
                    onPrimary: Colors.white,
                  ),
            ),
            child: child!,
          ),
        );
        if (picked != null && picked != time) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? primary.withOpacity(0.15)
              : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary.withOpacity(isDark ? 0.35 : 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 14,
              color: isDark ? AppColors.brandPrimaryLight : primary,
            ),
            const SizedBox(width: 6),
            Text(
              time.format(context),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.brandPrimaryLight : primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(BuildContext context, bool permissionsGranted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppColors.brandPrimary;

    final bgColor = permissionsGranted
        ? (isDark ? primary.withOpacity(0.12) : const Color(0xFFEEF2FF))
        : (isDark
            ? AppColors.warning.withOpacity(0.12)
            : AppColors.warningLight);

    final borderColor = permissionsGranted
        ? primary.withOpacity(isDark ? 0.35 : 0.3)
        : AppColors.warning.withOpacity(isDark ? 0.4 : 0.5);

    final iconColor =
        permissionsGranted ? AppColors.success : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    permissionsGranted
                        ? Icons.check_circle_rounded
                        : Icons.notifications_off_rounded,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(TranslationKeys
                            .notificationsSettingsPermissionTitle),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        permissionsGranted
                            ? context.tr(TranslationKeys
                                .notificationsSettingsPermissionEnabled)
                            : context.tr(TranslationKeys
                                .notificationsSettingsPermissionDisabled),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!permissionsGranted) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<NotificationBloc>().add(
                          const RequestNotificationPermissions(),
                        );
                  },
                  icon:
                      const Icon(Icons.notifications_active_rounded, size: 18),
                  label: Text(context
                      .tr(TranslationKeys.notificationsSettingsEnableButton)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppColors.brandPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? primary.withOpacity(0.08) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primary.withOpacity(isDark ? 0.2 : 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_rounded,
            color: isDark ? AppColors.brandPrimaryLight : primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.notificationsSettingsAboutTitle),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.brandPrimaryLight : primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(TranslationKeys.notificationsSettingsAboutInfo),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr(TranslationKeys.notificationsSettingsErrorTitle),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<NotificationBloc>().add(
                      const LoadNotificationPreferences(),
                    );
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label:
                  Text(context.tr(TranslationKeys.notificationsSettingsRetry)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
