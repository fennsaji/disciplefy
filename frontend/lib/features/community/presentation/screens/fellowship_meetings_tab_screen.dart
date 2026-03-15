import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_meeting_entity.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_event.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_state.dart';
import 'google_calendar_auth_stub.dart'
    if (dart.library.js_interop) 'google_calendar_auth_web.dart'
    if (dart.library.io) 'google_calendar_auth_mobile.dart';

class FellowshipMeetingsTabScreen extends StatelessWidget {
  final String fellowshipId;
  final bool isMentor;

  const FellowshipMeetingsTabScreen({
    required this.fellowshipId,
    required this.isMentor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FellowshipMeetingsBloc, FellowshipMeetingsState>(
      listenWhen: (prev, curr) =>
          prev.successMessage != curr.successMessage ||
          prev.errorMessage != curr.errorMessage ||
          prev.syncRequiresReconnect != curr.syncRequiresReconnect,
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
        } else if (state.syncRequiresReconnect) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.meetingsSyncReconnect),
              backgroundColor: AppColors.brandPrimary,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
        }
      },
      builder: (context, state) {
        Future<void> syncCalendar() async {
          final supabaseUser = Supabase.instance.client.auth.currentUser;
          final isGoogleUser =
              supabaseUser?.identities?.any((id) => id.provider == 'google') ??
                  false;
          final googleAccessToken = isGoogleUser
              ? await requestCalendarAccessToken(AppConfig.googleClientId,
                  userEmail: supabaseUser?.email)
              : null;
          if (!context.mounted) return;
          context.read<FellowshipMeetingsBloc>().add(
                FellowshipMeetingsSyncCalendarRequested(
                  fellowshipId,
                  googleAccessToken: googleAccessToken,
                ),
              );
        }

        Future<void> cancelMeeting(String meetingId) async {
          final supabaseUser = Supabase.instance.client.auth.currentUser;
          final isGoogleUser =
              supabaseUser?.identities?.any((id) => id.provider == 'google') ??
                  false;
          final googleAccessToken = isGoogleUser
              ? await requestCalendarAccessToken(AppConfig.googleClientId,
                  userEmail: supabaseUser?.email)
              : null;
          if (!context.mounted) return;
          context.read<FellowshipMeetingsBloc>().add(
                FellowshipMeetingCancelRequested(
                  meetingId,
                  googleAccessToken: googleAccessToken,
                ),
              );
        }

        if (state.status == FellowshipMeetingsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == FellowshipMeetingsStatus.failure) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load meetings',
                  style: TextStyle(color: context.appTextSecondary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context
                      .read<FellowshipMeetingsBloc>()
                      .add(FellowshipMeetingsLoadRequested(fellowshipId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state.meetings.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_call_outlined,
                    size: 56, color: context.appTextTertiary),
                const SizedBox(height: 12),
                Text(
                  isMentor
                      ? 'No upcoming meetings.\nTap + to schedule one.'
                      : 'No upcoming meetings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            if (isMentor && state.showSyncBanner)
              _SyncCalendarBanner(
                isSyncing: state.isSyncingCalendar,
                onSync: syncCalendar,
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: state.meetings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _MeetingCard(
                  meeting: state.meetings[index],
                  isMentor: isMentor,
                  onCancel: () => cancelMeeting(state.meetings[index].id),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final FellowshipMeetingEntity meeting;
  final bool isMentor;
  final VoidCallback onCancel;

  const _MeetingCard({
    required this.meeting,
    required this.isMentor,
    required this.onCancel,
  });

  String _formatDateTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$dayName, ${dt.day} $month · $hour:$minute $amPm';
  }

  String _duration() {
    final start = DateTime.parse(meeting.startsAt);
    final end = DateTime.parse(meeting.endsAt);
    final minutes = end.difference(start).inMinutes;
    if (minutes < 60) return '$minutes min';
    final hrs = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '$hrs hr' : '$hrs hr $rem min';
  }

  Future<void> _joinMeeting() async {
    final uri = Uri.parse(meeting.meetLink);
    if (uri.scheme != 'https') return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F7FF);
    final dateBg = isDark ? const Color(0xFF2A2A3E) : const Color(0xFFEEECFA);
    final dateTextColor =
        isDark ? const Color(0xFF9B9BB8) : const Color(0xFF6B6890);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: isDark ? 0.15 : 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icon + title + recurrence ────────────────────────
            Row(
              children: [
                // Soft icon badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brandSecondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    meeting.isInPerson
                        ? Icons.location_on_rounded
                        : Icons.videocam_rounded,
                    color: AppColors.brandPrimaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (meeting.description != null &&
                          meeting.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meeting.description!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (meeting.recurrence != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _capitalize(meeting.recurrence!),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9898B8),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // ── Date / duration row ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: dateBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: AppColors.brandPrimaryLight.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatDateTime(meeting.startsAt),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: dateTextColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: dateTextColor.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: dateTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _duration(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: dateTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Action row ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: meeting.isInPerson
                      ? _LocationPill(
                          location: meeting.location ?? '',
                          isDark: isDark,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.brandPrimary,
                                AppColors.brandSecondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: meeting.meetLink.isNotEmpty
                                ? _joinMeeting
                                : null,
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 17),
                            label: Text(
                              meeting.meetLink.isNotEmpty
                                  ? 'Join Meeting'
                                  : 'No link yet',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                ),
                if (isMentor) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showCancelConfirm(context),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    tooltip: 'Cancel meeting',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.07),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cancel Meeting',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Cancel "${meeting.title}"? All invitees will receive a cancellation email.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onCancel();
            },
            child: const Text(
              'Cancel Meeting',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Shown at the top of the meetings list when the mentor has upcoming meetings
/// whose Google Calendar events have not yet been synced with the full
/// fellowship member list.  A single tap triggers [FellowshipMeetingsSyncCalendarRequested].
class _SyncCalendarBanner extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onSync;

  const _SyncCalendarBanner({
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandSecondary.withValues(alpha: isDark ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandSecondary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync_rounded,
            size: 18,
            color: AppColors.brandPrimaryLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.meetingsSyncBannerTitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: context.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: onSync,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimaryLight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  child: Text(l10n.meetingsSyncCalendar),
                ),
        ],
      ),
    );
  }
}

/// Displays the physical location of an in-person meeting inside the card's
/// action row — replaces the "Join Meeting" button for in-person events.
class _LocationPill extends StatelessWidget {
  final String location;
  final bool isDark;

  const _LocationPill({required this.location, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.brandPrimary.withValues(alpha: 0.12)
            : AppColors.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 16,
            color: AppColors.brandPrimaryLight,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              location,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
