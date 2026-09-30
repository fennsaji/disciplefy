// ============================================================================
// Notification Settings Screen
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/services/notification_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_event.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_state.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/utils/time_of_day_extensions.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

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

/// Tells the user notifications were refused, and — when the OS will no longer
/// prompt — offers the only route that can still turn them on.
///
/// Without the settings action the "Enable" button is a dead end after a
/// permanent denial: Android returns the refusal immediately, raising no
/// dialog, so the button appears to do nothing at all.
Future<void> _showPermissionDeniedSnackbar(BuildContext context) async {
  final permanentlyDenied =
      await sl<NotificationService>().isPermissionPermanentlyDenied();
  if (!context.mounted) return;

  showAppSnackBar(
    context,
    context.tr(TranslationKeys.notificationsSettingsPermissionsDenied),
    tone: AppSnackTone.warning,
    actionLabel: permanentlyDenied
        ? context.tr(TranslationKeys.commonOpenSettings)
        : null,
    onAction: permanentlyDenied
        ? sl<NotificationService>().openPermissionSettings
        : null,
  );
}

class _NotificationSettingsView extends StatelessWidget {
  const _NotificationSettingsView();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: palette.page,
        appBar: SettingsTopBar(
          title: context.tr(TranslationKeys.notificationsSettingsTitle),
          subtitle: context.tr(TranslationKeys.notificationsSettingsSubtitle),
          onBack: () => Navigator.of(context).pop(),
        ),
        body: BlocConsumer<NotificationBloc, NotificationState>(
          listener: (context, state) {
            if (state is NotificationError) {
              showAppSnackBar(
                context,
                context.tr(TranslationKeys.commonErrorTryAgain),
                tone: AppSnackTone.error,
              );
            } else if (state is NotificationPreferencesUpdated) {
              showAppSnackBar(
                context,
                context.tr(
                    TranslationKeys.notificationsSettingsPreferencesUpdated),
                tone: AppSnackTone.success,
              );
              context
                  .read<NotificationBloc>()
                  .add(const LoadNotificationPreferences());
            } else if (state is NotificationPermissionResult) {
              if (state.granted) {
                showAppSnackBar(
                  context,
                  context.tr(
                      TranslationKeys.notificationsSettingsPermissionsGranted),
                  tone: AppSnackTone.success,
                );
              } else {
                _showPermissionDeniedSnackbar(context);
              }
              context
                  .read<NotificationBloc>()
                  .add(const LoadNotificationPreferences());
            }
          },
          builder: (context, state) {
            if (state is NotificationLoading) {
              return const Center(
                child: CircularProgressIndicator(color: settingsPrimaryFill),
              );
            }
            if (state is NotificationPreferencesLoaded) {
              return _buildPreferencesView(context, state);
            }
            if (state is NotificationError) {
              return _buildErrorView(
                  context, context.tr(TranslationKeys.commonErrorTryAgain));
            }
            return Center(
              child: Text(
                context.tr(TranslationKeys.notificationsSettingsLoading),
                style: AppFonts.inter(fontSize: 14, color: palette.muted),
              ),
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
    final prefs = state.preferences;
    void update(UpdateNotificationPreferences event) =>
        context.read<NotificationBloc>().add(event);

    Widget toggle({
      required IconData icon,
      required SettingsTone tone,
      required String titleKey,
      required String descriptionKey,
      required bool enabled,
      required ValueChanged<bool> onChanged,
    }) =>
        _NotificationToggleRow(
          icon: icon,
          tone: tone,
          title: context.tr(titleKey),
          description: context.tr(descriptionKey),
          enabled: enabled,
          onChanged: onChanged,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        // Permission status: an action card while missing, a quiet status
        // row once granted.
        const SizedBox(height: 8),
        if (state.permissionsGranted)
          SettingsGroup(children: [
            SettingsRow(
              icon: Icons.check_circle_outline_rounded,
              tone: SettingsTone.green,
              title: context
                  .tr(TranslationKeys.notificationsSettingsPermissionTitle),
              subtitle: context
                  .tr(TranslationKeys.notificationsSettingsPermissionEnabled),
            ),
          ])
        else
          _buildPermissionCard(context),

        SettingsSectionLabel(
            context.tr(TranslationKeys.notificationsSettingsDailySectionTitle)),
        SettingsGroup(children: [
          toggle(
            icon: Icons.wb_sunny_outlined,
            tone: SettingsTone.gold,
            titleKey: TranslationKeys.notificationsSettingsDailyVerseTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsDailyVerseDescription,
            enabled: prefs.dailyVerseEnabled,
            onChanged: (v) =>
                update(UpdateNotificationPreferences(dailyVerseEnabled: v)),
          ),
          toggle(
            icon: Icons.auto_awesome_outlined,
            tone: SettingsTone.indigo,
            titleKey:
                TranslationKeys.notificationsSettingsRecommendedTopicsTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsRecommendedTopicsDescription,
            enabled: prefs.recommendedTopicEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(recommendedTopicEnabled: v)),
          ),
        ]),

        SettingsSectionLabel(context
            .tr(TranslationKeys.notificationsSettingsStreakSectionTitle)),
        SettingsGroup(children: [
          toggle(
            icon: Icons.local_fire_department_outlined,
            tone: SettingsTone.gold,
            titleKey: TranslationKeys.notificationsSettingsStreakReminderTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsStreakReminderDescription,
            enabled: prefs.streakReminderEnabled,
            onChanged: (v) =>
                update(UpdateNotificationPreferences(streakReminderEnabled: v)),
          ),
          if (prefs.streakReminderEnabled)
            _ReminderTimeRow(
              label: context
                  .tr(TranslationKeys.notificationsSettingsReminderTimeLabel),
              time: prefs.streakReminderTime.toFlutterTimeOfDay(),
              onPicked: (picked) => update(
                  UpdateNotificationPreferences(streakReminderTime: picked)),
            ),
          toggle(
            icon: Icons.emoji_events_outlined,
            tone: SettingsTone.gold,
            titleKey: TranslationKeys.notificationsSettingsStreakMilestoneTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsStreakMilestoneDescription,
            enabled: prefs.streakMilestoneEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(streakMilestoneEnabled: v)),
          ),
          toggle(
            icon: Icons.wb_twilight_outlined,
            tone: SettingsTone.green,
            titleKey: TranslationKeys.notificationsSettingsStreakLostTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsStreakLostDescription,
            enabled: prefs.streakLostEnabled,
            onChanged: (v) =>
                update(UpdateNotificationPreferences(streakLostEnabled: v)),
          ),
        ]),

        SettingsSectionLabel(context
            .tr(TranslationKeys.notificationsSettingsMemoryVerseSectionTitle)),
        SettingsGroup(children: [
          toggle(
            icon: Icons.psychology_outlined,
            tone: SettingsTone.pink,
            titleKey:
                TranslationKeys.notificationsSettingsMemoryVerseReminderTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsMemoryVerseReminderDescription,
            enabled: prefs.memoryVerseReminderEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(memoryVerseReminderEnabled: v)),
          ),
          if (prefs.memoryVerseReminderEnabled)
            _ReminderTimeRow(
              label: context.tr(TranslationKeys
                  .notificationsSettingsMemoryVerseReminderTimeLabel),
              time: prefs.memoryVerseReminderTime.toFlutterTimeOfDay(),
              onPicked: (picked) => update(UpdateNotificationPreferences(
                  memoryVerseReminderTime: picked)),
            ),
          toggle(
            icon: Icons.warning_amber_rounded,
            tone: SettingsTone.amber,
            titleKey:
                TranslationKeys.notificationsSettingsMemoryVerseOverdueTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsMemoryVerseOverdueDescription,
            enabled: prefs.memoryVerseOverdueEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(memoryVerseOverdueEnabled: v)),
          ),
        ]),

        SettingsSectionLabel(
            context.tr(TranslationKeys.notificationsSettingsStudySectionTitle)),
        SettingsGroup(children: [
          toggle(
            icon: Icons.play_lesson_outlined,
            tone: SettingsTone.indigo,
            titleKey:
                TranslationKeys.notificationsSettingsContinueLearningTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsContinueLearningDescription,
            enabled: prefs.continueLearningEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(continueLearningEnabled: v)),
          ),
          toggle(
            icon: Icons.military_tech_outlined,
            tone: SettingsTone.gold,
            titleKey: TranslationKeys.notificationsSettingsAchievementTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsAchievementDescription,
            enabled: prefs.achievementUnlockedEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(achievementUnlockedEnabled: v)),
          ),
        ]),

        SettingsSectionLabel(context
            .tr(TranslationKeys.notificationsSettingsCommunitySectionTitle)),
        SettingsGroup(children: [
          toggle(
            icon: Icons.auto_stories_outlined,
            tone: SettingsTone.sky,
            titleKey:
                TranslationKeys.notificationsSettingsFellowshipDailyPostTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsFellowshipDailyPostDescription,
            enabled: prefs.fellowshipDailyPostEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(fellowshipDailyPostEnabled: v)),
          ),
          toggle(
            icon: Icons.forum_outlined,
            tone: SettingsTone.sky,
            titleKey:
                TranslationKeys.notificationsSettingsFellowshipNewPostTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsFellowshipNewPostDescription,
            enabled: prefs.fellowshipNewPostEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(fellowshipNewPostEnabled: v)),
          ),
          toggle(
            icon: Icons.mode_comment_outlined,
            tone: SettingsTone.sky,
            titleKey:
                TranslationKeys.notificationsSettingsFellowshipCommentTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsFellowshipCommentDescription,
            enabled: prefs.fellowshipNewCommentEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(fellowshipNewCommentEnabled: v)),
          ),
          toggle(
            icon: Icons.favorite_outline_rounded,
            tone: SettingsTone.pink,
            titleKey:
                TranslationKeys.notificationsSettingsFellowshipReactionTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsFellowshipReactionDescription,
            enabled: prefs.fellowshipReactionEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(fellowshipReactionEnabled: v)),
          ),
        ]),

        SettingsSectionLabel(context
            .tr(TranslationKeys.notificationsSettingsDisciplerSectionTitle)),
        SettingsGroup(children: [
          toggle(
            icon: Icons.chat_bubble_outline_rounded,
            tone: SettingsTone.indigo,
            titleKey: TranslationKeys.notificationsSettingsDisciplerReplyTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsDisciplerReplyDescription,
            enabled: prefs.fellowshipDisciplerReplyEnabled,
            onChanged: (v) => update(UpdateNotificationPreferences(
                fellowshipDisciplerReplyEnabled: v)),
          ),
          toggle(
            icon: Icons.insights_outlined,
            tone: SettingsTone.indigo,
            titleKey:
                TranslationKeys.notificationsSettingsDisciplerActivityTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsDisciplerActivityDescription,
            enabled: prefs.fellowshipDisciplerActivityEnabled,
            onChanged: (v) => update(UpdateNotificationPreferences(
                fellowshipDisciplerActivityEnabled: v)),
          ),
          toggle(
            icon: Icons.workspace_premium_outlined,
            tone: SettingsTone.gold,
            titleKey: TranslationKeys.notificationsSettingsMentorPromotedTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsMentorPromotedDescription,
            enabled: prefs.fellowshipMentorPromotedEnabled,
            onChanged: (v) => update(UpdateNotificationPreferences(
                fellowshipMentorPromotedEnabled: v)),
          ),
          toggle(
            icon: Icons.person_add_alt_1_outlined,
            tone: SettingsTone.green,
            titleKey: TranslationKeys.notificationsSettingsMemberJoinedTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsMemberJoinedDescription,
            enabled: prefs.fellowshipMemberJoinedEnabled,
            onChanged: (v) => update(UpdateNotificationPreferences(
                fellowshipMemberJoinedEnabled: v)),
          ),
          toggle(
            icon: Icons.alternate_email_rounded,
            tone: SettingsTone.sky,
            titleKey: TranslationKeys.notificationsSettingsMentionTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsMentionDescription,
            enabled: prefs.fellowshipMentionEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(fellowshipMentionEnabled: v)),
          ),
        ]),

        SettingsSectionLabel(context
            .tr(TranslationKeys.notificationsSettingsMeetingsSectionTitle)),
        SettingsGroup(children: [
          toggle(
            icon: Icons.event_available_outlined,
            tone: SettingsTone.green,
            titleKey: TranslationKeys.notificationsSettingsMeetingNewTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsMeetingNewDescription,
            enabled: prefs.fellowshipMeetingEnabled,
            onChanged: (v) => update(
                UpdateNotificationPreferences(fellowshipMeetingEnabled: v)),
          ),
          toggle(
            icon: Icons.mail_outline_rounded,
            tone: SettingsTone.sky,
            titleKey: TranslationKeys.notificationsSettingsMeetingInviteTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsMeetingInviteDescription,
            enabled: prefs.fellowshipMeetingInviteEnabled,
            onChanged: (v) => update(UpdateNotificationPreferences(
                fellowshipMeetingInviteEnabled: v)),
          ),
          toggle(
            icon: Icons.alarm_outlined,
            tone: SettingsTone.indigo,
            titleKey: TranslationKeys.notificationsSettingsMeetingReminderTitle,
            descriptionKey:
                TranslationKeys.notificationsSettingsMeetingReminderDescription,
            enabled: prefs.fellowshipMeetingReminderEnabled,
            onChanged: (v) => update(UpdateNotificationPreferences(
                fellowshipMeetingReminderEnabled: v)),
          ),
          toggle(
            icon: Icons.event_busy_outlined,
            tone: SettingsTone.red,
            titleKey:
                TranslationKeys.notificationsSettingsMeetingCancelledTitle,
            descriptionKey: TranslationKeys
                .notificationsSettingsMeetingCancelledDescription,
            enabled: prefs.fellowshipMeetingCancelledEnabled,
            onChanged: (v) => update(UpdateNotificationPreferences(
                fellowshipMeetingCancelledEnabled: v)),
          ),
        ]),

        const SizedBox(height: 20),
        _buildInfoSection(context),
      ],
    );
  }

  /// Shown while permission is missing: explains and offers the prompt.
  Widget _buildPermissionCard(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final amber = SettingsToneColors.of(context, SettingsTone.amber);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.isDark
            ? amber.foreground.withValues(alpha: 0.12)
            : amber.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_off_outlined,
                  size: 20, color: amber.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                          TranslationKeys.notificationsSettingsPermissionTitle),
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys
                          .notificationsSettingsPermissionDisabled),
                      style: AppFonts.inter(
                        fontSize: 12.5,
                        color: palette.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsButton(
            label:
                context.tr(TranslationKeys.notificationsSettingsEnableButton),
            icon: Icons.notifications_active_outlined,
            height: 44,
            onPressed: () => context
                .read<NotificationBloc>()
                .add(const RequestNotificationPermissions()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: palette.dim),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.notificationsSettingsAboutTitle),
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(TranslationKeys.notificationsSettingsAboutInfo),
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.muted,
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
    final palette = ReaderPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SettingsIconTile(
              icon: Icons.error_outline_rounded,
              tone: SettingsTone.red,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              context.tr(TranslationKeys.notificationsSettingsErrorTitle),
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 14, color: palette.muted),
            ),
            const SizedBox(height: 22),
            SettingsButton(
              label: context.tr(TranslationKeys.notificationsSettingsRetry),
              icon: Icons.refresh_rounded,
              height: 46,
              onPressed: () => context
                  .read<NotificationBloc>()
                  .add(const LoadNotificationPreferences()),
            ),
          ],
        ),
      ),
    );
  }
}

/// A notification type: icon, title, description and a switch. Tapping the
/// row flips the switch too.
class _NotificationToggleRow extends StatelessWidget {
  final IconData icon;
  final SettingsTone tone;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: SettingsRow(
          icon: icon,
          tone: tone,
          title: title,
          subtitle: description,
          onTap: () => onChanged(!enabled),
          trailing: SettingsSwitch(value: enabled, onChanged: onChanged),
        ),
      );
}

/// "Reminder time" row showing the time; opens the time picker.
class _ReminderTimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPicked;

  const _ReminderTimeRow({
    required this.label,
    required this.time,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) => SettingsRow(
        icon: Icons.timer_outlined,
        title: label,
        value: time.format(context),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
            builder: (ctx, child) => Theme(
              data:
                  reminderTimePickerTheme(Theme.of(ctx), ReaderPalette.of(ctx)),
              child: child!,
            ),
          );
          if (picked != null && picked != time) onPicked(picked);
        },
      );
}

/// Theme for the reminder time picker: palette card surface, raised dial,
/// ctaFill selection and Poppins/Inter text so it matches the settings sheets.
@visibleForTesting
ThemeData reminderTimePickerTheme(ThemeData base, ReaderPalette palette) {
  Color selected(Color on, Color off) => WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected) ? on : off);

  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: palette.ctaFill,
      onPrimary: palette.ctaInk,
      surface: palette.card,
      onSurface: palette.text,
      surfaceTint: Colors.transparent,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: palette.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.hairline),
      ),
      helpTextStyle: AppFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: palette.gold,
      ),
      hourMinuteShape: pill,
      hourMinuteColor: selected(palette.ctaFill, palette.raised),
      hourMinuteTextColor: selected(palette.ctaInk, palette.text),
      hourMinuteTextStyle:
          AppFonts.poppins(fontSize: 44, fontWeight: FontWeight.w600),
      dayPeriodShape: pill,
      dayPeriodBorderSide: BorderSide(color: palette.outline),
      dayPeriodColor: selected(palette.ctaFill, Colors.transparent),
      dayPeriodTextColor: selected(palette.ctaInk, palette.muted),
      dayPeriodTextStyle:
          AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      dialBackgroundColor: palette.raised,
      dialHandColor: palette.ctaFill,
      dialTextColor: selected(palette.ctaInk, palette.text),
      dialTextStyle: AppFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
      entryModeIconColor: palette.muted,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: palette.muted,
        textStyle: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
      confirmButtonStyle: TextButton.styleFrom(
        backgroundColor: palette.ctaFill,
        foregroundColor: palette.ctaInk,
        textStyle: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
  );
}
