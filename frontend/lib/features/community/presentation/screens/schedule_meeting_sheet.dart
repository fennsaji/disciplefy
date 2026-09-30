import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/config/app_config.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_meetings_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';

import 'package:disciplefy_bible_study/features/community/presentation/screens/google_calendar_auth_stub.dart'
    if (dart.library.js_interop) 'package:disciplefy_bible_study/features/community/presentation/screens/google_calendar_auth_web.dart'
    if (dart.library.io) 'package:disciplefy_bible_study/features/community/presentation/screens/google_calendar_auth_mobile.dart';

/// A modal bottom sheet that allows a fellowship mentor to schedule a new
/// Google Meet session (or an in-person gathering) for the group.
///
/// Dispatches [FellowshipMeetingCreateRequested] and closes itself once the
/// [FellowshipMeetingsBloc] emits a [FellowshipMeetingsState.successMessage].
class ScheduleMeetingSheet extends StatefulWidget {
  /// The ID of the fellowship for which the meeting is being scheduled.
  final String fellowshipId;

  const ScheduleMeetingSheet({required this.fellowshipId, super.key});

  @override
  State<ScheduleMeetingSheet> createState() => _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends State<ScheduleMeetingSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  int _durationMinutes = 60;

  /// Whether this is a physical/in-person gathering (skips Google Meet).
  bool _isInPerson = false;

  /// `null` represents a one-time (non-recurring) meeting.
  String? _recurrence;

  static const _durations = [30, 60, 90, 120];
  static const _recurrences = <String?>[null, 'daily', 'weekly', 'monthly'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Combines [_selectedDate] and [_selectedTime] into an ISO-8601 string
  /// with the device's UTC offset embedded (e.g. `2026-03-15T10:00:00+05:30`).
  /// This makes the time unambiguous even when the IANA timezone name is
  /// unavailable (e.g. on web).
  String _isoStartsAt() {
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = offset.inHours.abs().toString().padLeft(2, '0');
    final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final base = '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:00';
    return '$base$sign$hh:$mm';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  /// Returns a human-readable date, e.g. `"Mar 10, 2026"` in the app locale.
  String _formatDate() {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    try {
      return DateFormat.yMMMd(code).format(_selectedDate);
    } catch (_) {
      return DateFormat.yMMMd('en').format(_selectedDate);
    }
  }

  /// Returns a best-effort IANA timezone string for the device.
  ///
  /// [DateTime.timeZoneName] can return platform-specific strings such as
  /// "India Standard Time" (Windows) or short abbreviations like "IST" on
  /// web — neither of which is accepted by the Google Calendar API.
  ///
  /// A valid IANA name always contains a slash (e.g. "Asia/Kolkata").  When
  /// the runtime value is not in that format we return "UTC" and rely on the
  /// UTC offset already embedded in [_isoStartsAt] to keep the time correct.
  String _getIanaTimezone() {
    final name = DateTime.now().timeZoneName;
    if (name.contains('/')) return name;
    return 'UTC';
  }

  String _durationLabel(int mins) {
    if (mins < 60) {
      return context.tr(TranslationKeys.communityPagesMinutes, {'count': mins});
    }
    final hours = mins ~/ 60;
    final remainder = mins % 60;
    if (remainder == 0) {
      return context.tr(TranslationKeys.communityPagesHours, {'count': hours});
    }
    return context.tr(TranslationKeys.communityPagesHoursMinutes,
        {'hours': hours, 'minutes': remainder});
  }

  String _recurrenceLabel(String? recurrence) {
    final key = meetingRecurrenceKey(recurrence);
    return context.tr(key ?? TranslationKeys.communityPagesOneTime);
  }

  /// Explains the Google Calendar permission request. True to proceed.
  Future<bool> _showCalendarPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SettingsDialog(
        title: ctx.tr(TranslationKeys.communityPagesCalendarTitle),
        content: Text(ctx.tr(TranslationKeys.communityPagesCalendarBody)),
        actions: [
          SettingsButton(
            label: ctx.tr(TranslationKeys.communityPagesCalendarSkip),
            kind: SettingsButtonKind.neutral,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          SettingsButton(
            label: ctx.tr(TranslationKeys.communityPagesContinue),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final userEmail = supabaseUser?.email;

    final location = _isInPerson ? _locationController.text.trim() : null;

    String? googleAccessToken;
    // Skip Google Calendar entirely for in-person gatherings.
    // Any user (not just Google sign-in users) can connect Google Calendar to
    // generate a Meet link — they may have a separate Google account.
    if (!_isInPerson) {
      final proceed = await _showCalendarPermissionDialog(context);
      if (!context.mounted) return;
      if (proceed) {
        googleAccessToken = await requestCalendarAccessToken(
          AppConfig.googleClientId,
          userEmail: userEmail,
        );
        if (!context.mounted) return;
        if (googleAccessToken == null) {
          // Auth failed — inform user and let them decide whether to continue.
          final continueAnyway = await showDialog<bool>(
            context: context,
            builder: (ctx) => SettingsDialog(
              title: ctx.tr(TranslationKeys.communityPagesCalendarFailedTitle),
              content: Text(
                  ctx.tr(TranslationKeys.communityPagesCalendarFailedBody)),
              actions: [
                SettingsButton(
                  label: AppLocalizations.of(ctx)!.cancel,
                  kind: SettingsButtonKind.neutral,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                SettingsButton(
                  label: ctx.tr(TranslationKeys.communityPagesCreateAnyway),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          );
          if (!context.mounted) return;
          if (continueAnyway != true) return;
        }
      }
    }

    if (!context.mounted) return;
    context.read<FellowshipMeetingsBloc>().add(
          FellowshipMeetingCreateRequested(
            fellowshipId: widget.fellowshipId,
            title: _titleController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            startsAt: _isoStartsAt(),
            durationMinutes: _durationMinutes,
            timeZone: _getIanaTimezone(),
            recurrence: _recurrence,
            location: location?.isEmpty ?? true ? null : location,
            googleAccessToken: googleAccessToken,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return BlocListener<FellowshipMeetingsBloc, FellowshipMeetingsState>(
      // Detect the submitting → done transition that carries a success message.
      listenWhen: (prev, curr) =>
          prev.submitting && !curr.submitting && curr.successMessage != null,
      listener: (context, state) => Navigator.of(context).pop(),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SheetScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _DragHandle(),
                  Text(
                    context.tr(TranslationKeys.communityPagesScheduleTitle),
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CommunityFieldLabel(
                      context.tr(TranslationKeys.communityPagesTitleLabel)),
                  TextFormField(
                    controller: _titleController,
                    style: communityInputStyle(context),
                    decoration: communityInputDecoration(
                      context,
                      hintText:
                          context.tr(TranslationKeys.communityPagesTitleHint),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context
                            .tr(TranslationKeys.communityPagesTitleRequired)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  CommunityFieldLabel(context
                      .tr(TranslationKeys.communityPagesDescriptionLabel)),
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    maxLength: 500,
                    style: communityInputStyle(context),
                    decoration: communityInputDecoration(context),
                  ),
                  const SizedBox(height: 10),
                  CommunityFieldLabel(
                      context.tr(TranslationKeys.communityPagesDateTime)),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.calendar_today_rounded,
                          label: _formatDate(),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.access_time_rounded,
                          label: _selectedTime.format(context),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  CommunityFieldLabel(
                      context.tr(TranslationKeys.communityPagesMeetingType)),
                  CommunitySegmented<bool>(
                    segments: [
                      CommunitySegment(
                        false,
                        context.tr(TranslationKeys.communityPagesOnline),
                        icon: Icons.videocam_outlined,
                      ),
                      CommunitySegment(
                        true,
                        context.tr(TranslationKeys.communityPagesInPerson),
                        icon: Icons.place_outlined,
                      ),
                    ],
                    selected: _isInPerson,
                    onChanged: (val) => setState(() => _isInPerson = val),
                  ),
                  if (_isInPerson) ...[
                    const SizedBox(height: 14),
                    CommunityFieldLabel(context
                        .tr(TranslationKeys.communityPagesLocationLabel)),
                    TextFormField(
                      controller: _locationController,
                      style: communityInputStyle(context),
                      decoration: communityInputDecoration(
                        context,
                        hintText: context
                            .tr(TranslationKeys.communityPagesLocationHint),
                        prefixIcon: Icons.place_outlined,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.tr(
                              TranslationKeys.communityPagesLocationRequired)
                          : null,
                    ),
                  ],
                  const SizedBox(height: 18),
                  CommunityFieldLabel(
                      context.tr(TranslationKeys.communityPagesDuration)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mins in _durations)
                        CommunityRaisedPill(
                          label: _durationLabel(mins),
                          selected: _durationMinutes == mins,
                          onPressed: () =>
                              setState(() => _durationMinutes = mins),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  CommunityFieldLabel(
                      context.tr(TranslationKeys.communityPagesRepeat)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final rec in _recurrences)
                        CommunityRaisedPill(
                          label: _recurrenceLabel(rec),
                          selected: _recurrence == rec,
                          onPressed: () => setState(() => _recurrence = rec),
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  BlocBuilder<FellowshipMeetingsBloc, FellowshipMeetingsState>(
                    buildWhen: (prev, curr) =>
                        prev.submitting != curr.submitting,
                    builder: (context, state) => SettingsButton(
                      label: context.tr(TranslationKeys.communityPagesSubmit),
                      icon: Icons.send_rounded,
                      loading: state.submitting,
                      onPressed: () => _submit(context),
                    ),
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

// ──────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: ReaderPalette.of(context).outline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A tappable well showing the chosen date or time; opens its picker.
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: communityWellFill(palette),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 17, color: palette.accentIcon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, size: 18, color: palette.dim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
