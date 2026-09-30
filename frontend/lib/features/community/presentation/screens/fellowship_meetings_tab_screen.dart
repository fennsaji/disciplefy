import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/config/app_config.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_meeting_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';

import 'package:disciplefy_bible_study/features/community/presentation/screens/google_calendar_auth_stub.dart'
    if (dart.library.js_interop) 'package:disciplefy_bible_study/features/community/presentation/screens/google_calendar_auth_web.dart'
    if (dart.library.io) 'package:disciplefy_bible_study/features/community/presentation/screens/google_calendar_auth_mobile.dart';

/// Body of the fellowship Meetings page: the calendar-sync banner (mentors),
/// then upcoming meetings grouped into This week / Next week / Later.
///
/// The page chrome (back bar, schedule action) belongs to the host page.
class FellowshipMeetingsTabScreen extends StatelessWidget {
  final String fellowshipId;
  final bool isMentor;

  const FellowshipMeetingsTabScreen({
    required this.fellowshipId,
    required this.isMentor,
    super.key,
  });

  /// Asks Google for a calendar token when the user signed in with Google.
  static Future<String?> _googleTokenIfGoogleUser() async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final isGoogleUser =
        supabaseUser?.identities?.any((id) => id.provider == 'google') ?? false;
    if (!isGoogleUser) return null;
    return requestCalendarAccessToken(
      AppConfig.googleClientId,
      userEmail: supabaseUser?.email,
    );
  }

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FellowshipMeetingsBloc, FellowshipMeetingsState>(
      listenWhen: (prev, curr) =>
          prev.successMessage != curr.successMessage ||
          prev.errorMessage != curr.errorMessage ||
          prev.syncRequiresReconnect != curr.syncRequiresReconnect,
      listener: (context, state) {
        if (state.successMessage != null) {
          _showSnack(context, state.successMessage!, AppColors.success);
        } else if (state.errorMessage != null) {
          _showSnack(context, state.errorMessage!, AppColors.error);
        } else if (state.syncRequiresReconnect) {
          _showSnack(
            context,
            AppLocalizations.of(context)!.meetingsSyncReconnect,
            AppColors.brandPrimary,
          );
        }
      },
      builder: (context, state) {
        Future<void> syncCalendar() async {
          final token = await _googleTokenIfGoogleUser();
          if (!context.mounted) return;
          context.read<FellowshipMeetingsBloc>().add(
                FellowshipMeetingsSyncCalendarRequested(
                  fellowshipId,
                  googleAccessToken: token,
                ),
              );
        }

        Future<void> cancelMeeting(String meetingId) async {
          final token = await _googleTokenIfGoogleUser();
          if (!context.mounted) return;
          context.read<FellowshipMeetingsBloc>().add(
                FellowshipMeetingCancelRequested(
                  meetingId,
                  googleAccessToken: token,
                ),
              );
        }

        if (state.status == FellowshipMeetingsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == FellowshipMeetingsStatus.failure) {
          return _MeetingsMessage(
            icon: Icons.cloud_off_rounded,
            message: context.tr(TranslationKeys.communityPagesLoadError),
            actionLabel: AppLocalizations.of(context)!.retryButton,
            onAction: () => context
                .read<FellowshipMeetingsBloc>()
                .add(FellowshipMeetingsLoadRequested(fellowshipId)),
          );
        }
        if (state.meetings.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return _MeetingsMessage(
            icon: Icons.event_available_outlined,
            message: l10n.meetingsNoUpcoming,
            detail: isMentor ? l10n.meetingsSchedulePrompt : null,
          );
        }

        final groups = groupMeetingsByWeek(state.meetings, DateTime.now());
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            if (isMentor && state.showSyncBanner)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _SyncCalendarBanner(
                  isSyncing: state.isSyncingCalendar,
                  onSync: syncCalendar,
                ),
              ),
            for (final group in groups) ...[
              CommunityGroupLabel(context.tr(group.labelKey)),
              for (final meeting in group.meetings) ...[
                _MeetingCard(
                  meeting: meeting,
                  isMentor: isMentor,
                  onCancel: () => cancelMeeting(meeting.id),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Meetings of one week bucket, in the order the bloc gave them.
@immutable
class MeetingWeekGroup {
  /// Translation key of the section label.
  final String labelKey;
  final List<FellowshipMeetingEntity> meetings;

  const MeetingWeekGroup(this.labelKey, this.meetings);
}

/// Splits [meetings] into This week / Next week / Later relative to [now],
/// with weeks starting on Sunday. Anything before this week (a meeting that
/// is running now) counts as this week. Empty buckets are dropped.
List<MeetingWeekGroup> groupMeetingsByWeek(
  List<FellowshipMeetingEntity> meetings,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  // DateTime.weekday: Monday = 1 … Sunday = 7.
  final weekStart = today.subtract(Duration(days: today.weekday % 7));
  final nextWeekStart = DateTime(weekStart.year, weekStart.month,
      weekStart.day + 7); // DST-safe day arithmetic.
  final laterStart =
      DateTime(weekStart.year, weekStart.month, weekStart.day + 14);

  final thisWeek = <FellowshipMeetingEntity>[];
  final nextWeek = <FellowshipMeetingEntity>[];
  final later = <FellowshipMeetingEntity>[];
  for (final meeting in meetings) {
    final start = DateTime.tryParse(meeting.startsAt)?.toLocal();
    if (start == null || start.isBefore(nextWeekStart)) {
      thisWeek.add(meeting);
    } else if (start.isBefore(laterStart)) {
      nextWeek.add(meeting);
    } else {
      later.add(meeting);
    }
  }
  return [
    if (thisWeek.isNotEmpty)
      MeetingWeekGroup(TranslationKeys.communityPagesThisWeek, thisWeek),
    if (nextWeek.isNotEmpty)
      MeetingWeekGroup(TranslationKeys.communityPagesNextWeek, nextWeek),
    if (later.isNotEmpty)
      MeetingWeekGroup(TranslationKeys.communityPagesLater, later),
  ];
}

/// [DateFormat] for the current locale, falling back to English when the
/// locale's date symbols are not loaded.
DateFormat _dateFormat(BuildContext context, DateFormat Function(String) make) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  try {
    return make(code);
  } catch (_) {
    return make('en');
  }
}

/// Translation key for a meeting recurrence value, or null when unknown.
String? meetingRecurrenceKey(String? recurrence) => switch (recurrence) {
      'daily' => TranslationKeys.communityPagesDaily,
      'weekly' => TranslationKeys.communityPagesWeekly,
      'monthly' => TranslationKeys.communityPagesMonthly,
      _ => null,
    };

// ---------------------------------------------------------------------------
// Meeting card
// ---------------------------------------------------------------------------

class _MeetingCard extends StatelessWidget {
  final FellowshipMeetingEntity meeting;
  final bool isMentor;
  final VoidCallback onCancel;

  const _MeetingCard({
    required this.meeting,
    required this.isMentor,
    required this.onCancel,
  });

  Future<void> _joinMeeting() async {
    final uri = Uri.parse(meeting.meetLink);
    if (uri.scheme != 'https') return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _timeRange(BuildContext context) {
    final start = DateTime.tryParse(meeting.startsAt)?.toLocal();
    final end = DateTime.tryParse(meeting.endsAt)?.toLocal();
    if (start == null) return '';
    final format = _dateFormat(context, (code) => DateFormat.jm(code));
    if (end == null || !end.isAfter(start)) return format.format(start);
    return '${format.format(start)} – ${format.format(end)}';
  }

  String _place(BuildContext context) {
    if (meeting.isInPerson) return meeting.location!;
    if (meeting.meetLink.contains('meet.google.com')) return 'Google Meet';
    return context.tr(TranslationKeys.communityPagesOnline);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final start = DateTime.tryParse(meeting.startsAt)?.toLocal();
    final recurrenceKey = meetingRecurrenceKey(meeting.recurrence);
    final hasLink = !meeting.isInPerson && meeting.meetLink.isNotEmpty;

    final joinPill = hasLink
        ? CommunityCtaPill(
            label: context.tr(TranslationKeys.communityPagesJoin),
            onPressed: _joinMeeting,
          )
        : null;
    final cancelButton = isMentor
        ? IconButton(
            onPressed: () => _showCancelConfirm(context),
            tooltip: context.tr(TranslationKeys.communityPagesCancelMeeting),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 21,
              color:
                  SettingsToneColors.of(context, SettingsTone.red).foreground,
            ),
          )
        : null;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meeting.title,
          style: AppFonts.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: palette.text,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                meeting.isInPerson
                    ? Icons.place_outlined
                    : Icons.videocam_outlined,
                size: 16,
                color: palette.muted,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                [_timeRange(context), _place(context)]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: AppFonts.inter(
                  fontSize: 14,
                  color: palette.muted,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (meeting.description != null && meeting.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            meeting.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.inter(
              fontSize: 13,
              color: palette.dim,
              height: 1.4,
            ),
          ),
        ],
        if (recurrenceKey != null || (!meeting.isInPerson && !hasLink)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (recurrenceKey != null)
                _SmallChip(
                  icon: Icons.repeat_rounded,
                  label: context.tr(recurrenceKey),
                ),
              if (!meeting.isInPerson && !hasLink)
                _SmallChip(
                  icon: Icons.link_off_rounded,
                  label: context.tr(TranslationKeys.communityPagesNoLink),
                ),
            ],
          ),
        ],
      ],
    );

    return CommunityFormCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Beside the details when there is room; under them on narrow
          // phones so the title keeps a readable width.
          final actionsBeside = constraints.maxWidth >= 300;
          final actions = [
            if (joinPill != null) joinPill,
            if (cancelButton != null) cancelButton,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _DateTile(start: start),
                  const SizedBox(width: 14),
                  Expanded(child: details),
                  if (actionsBeside && actions.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: actions,
                    ),
                  ],
                ],
              ),
              if (!actionsBeside && actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cancelButton != null) cancelButton,
                    if (joinPill != null) ...[
                      const SizedBox(width: 6),
                      Flexible(child: joinPill),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCancelConfirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SettingsDialog(
        title: dialogContext.tr(TranslationKeys.communityPagesCancelMeeting),
        content: Text(dialogContext.tr(
          TranslationKeys.communityPagesCancelBody,
          {'title': meeting.title},
        )),
        actions: [
          SettingsButton(
            label: dialogContext.tr(TranslationKeys.communityPagesKeep),
            kind: SettingsButtonKind.neutral,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SettingsButton(
            label:
                dialogContext.tr(TranslationKeys.communityPagesCancelMeeting),
            kind: SettingsButtonKind.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) onCancel();
  }
}

/// Raised tile with the gold short weekday over the day number.
class _DateTile extends StatelessWidget {
  final DateTime? start;

  const _DateTile({required this.start});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final weekday = start == null
        ? ''
        : _dateFormat(context, (code) => DateFormat.E(code))
            .format(start!)
            .toUpperCase();
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              weekday,
              maxLines: 1,
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.gold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            start == null ? '–' : '${start!.day}',
            style: AppFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: palette.text,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar sync banner
// ---------------------------------------------------------------------------

/// Shown above the list when the mentor has upcoming meetings whose Google
/// Calendar events have not yet been synced with the full member list. A tap
/// triggers [FellowshipMeetingsSyncCalendarRequested].
class _SyncCalendarBanner extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onSync;

  const _SyncCalendarBanner({required this.isSyncing, required this.onSync});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.brandSecondary
            .withValues(alpha: palette.isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.accentIcon.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_calendar_outlined,
              size: 22, color: palette.accentIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.meetingsSyncBannerTitle,
              style: AppFonts.inter(
                fontSize: 14.5,
                color: palette.text,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.all(13),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: TextButton(
                onPressed: onSync,
                style: TextButton.styleFrom(
                  foregroundColor: palette.accentIcon,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  l10n.meetingsSyncCalendar,
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: palette.accentIcon,
                    height: 1.25,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error message
// ---------------------------------------------------------------------------

class _MeetingsMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MeetingsMessage({
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: palette.dim),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 14,
                  color: palette.muted,
                  height: 1.45,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              CommunityCtaPill(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
