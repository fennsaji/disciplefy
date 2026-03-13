import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import 'google_calendar_auth_stub.dart'
    if (dart.library.js_interop) 'google_calendar_auth_web.dart'
    if (dart.library.io) 'google_calendar_auth_mobile.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_event.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_state.dart';

/// A modal bottom sheet that allows a fellowship mentor to schedule a new
/// Google Meet session for the group.
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

  /// Returns a human-readable date string, e.g. `"10 Mar 2026"`.
  String _formatDate() {
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
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} '
        '${_selectedDate.year}';
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
    // IANA zone IDs always contain at least one slash.
    if (name.contains('/')) return name;
    // Fall back to UTC — the ISO string already carries the correct offset.
    return 'UTC';
  }

  /// Shows a dialog explaining the Google Calendar permission request.
  /// Returns true if the user wants to proceed, false to skip.
  Future<bool> _showCalendarPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('📅', style: TextStyle(fontSize: 22)),
            SizedBox(width: 10),
            Text(
              'Connect Google Calendar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'To generate a Google Meet link for this meeting, we need brief access to your Google Calendar.\n\nGoogle will open to confirm — it only takes a moment.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip — no Meet link'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    // Only request calendar access when the user signed in with Google.
    // Non-Google users (email/password, Apple) skip this — the meeting is
    // still created but without a Google Meet link.
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final isGoogleUser =
        supabaseUser?.identities?.any((id) => id.provider == 'google') ?? false;
    final userEmail = supabaseUser?.email;

    final location = _isInPerson ? _locationController.text.trim() : null;

    String? googleAccessToken;
    // Skip Google Calendar entirely for in-person gatherings.
    if (!_isInPerson && isGoogleUser) {
      // Show explanation dialog so the user knows why Google is opening.
      final proceed = await _showCalendarPermissionDialog(context);
      if (!context.mounted) return;
      if (proceed) {
        googleAccessToken = await requestCalendarAccessToken(
          AppConfig.googleClientId,
          userEmail: userEmail,
        );
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
    return BlocListener<FellowshipMeetingsBloc, FellowshipMeetingsState>(
      // Detect the submitting → done transition that carries a success message.
      listenWhen: (prev, curr) =>
          prev.submitting && !curr.submitting && curr.successMessage != null,
      listener: (context, state) => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DragHandle(),
                Text(
                  'Schedule Meeting',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                _TitleField(controller: _titleController),
                const SizedBox(height: 12),
                _DescriptionField(controller: _descController),
                const SizedBox(height: 16),
                _DateTimeRow(
                  dateLabel: _formatDate(),
                  timeLabel: _selectedTime.format(context),
                  onPickDate: _pickDate,
                  onPickTime: _pickTime,
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                  text: 'Meeting Type',
                  color: context.appTextSecondary,
                ),
                const SizedBox(height: 8),
                _MeetingTypeToggle(
                  isInPerson: _isInPerson,
                  onChanged: (val) => setState(() => _isInPerson = val),
                ),
                if (_isInPerson) ...[
                  const SizedBox(height: 12),
                  _LocationField(controller: _locationController),
                ],
                const SizedBox(height: 16),
                _SectionLabel(
                  text: 'Duration',
                  color: context.appTextSecondary,
                ),
                const SizedBox(height: 8),
                _DurationChips(
                  selected: _durationMinutes,
                  onSelected: (mins) => setState(() => _durationMinutes = mins),
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                  text: 'Repeat',
                  color: context.appTextSecondary,
                ),
                const SizedBox(height: 8),
                _RecurrenceChips(
                  selected: _recurrence,
                  onSelected: (rec) => setState(() => _recurrence = rec),
                ),
                const SizedBox(height: 24),
                _SubmitButton(onSubmit: () => _submit(context)),
              ],
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.appBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  final TextEditingController controller;

  const _TitleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Meeting title *',
        hintText: 'e.g. Weekly Prayer Session',
        filled: true,
        fillColor: context.appInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Title is required' : null,
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 2,
      maxLength: 500,
      decoration: InputDecoration(
        labelText: 'Description (optional)',
        filled: true,
        fillColor: context.appInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String dateLabel;
  final String timeLabel;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeRow({
    required this.dateLabel,
    required this.timeLabel,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PickerTile(
            icon: Icons.calendar_today_rounded,
            label: dateLabel,
            onTap: onPickDate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PickerTile(
            icon: Icons.access_time_rounded,
            label: timeLabel,
            onTap: onPickTime,
          ),
        ),
      ],
    );
  }
}

class _DurationChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _DurationChips({required this.selected, required this.onSelected});

  static String _label(int mins) {
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remainder = mins % 60;
    if (remainder == 0) return '$hours hr';
    return '$hours hr $remainder min';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [30, 60, 90, 120].map((mins) {
        final isSelected = selected == mins;
        return ChoiceChip(
          label: Text(_label(mins)),
          selected: isSelected,
          onSelected: (_) => onSelected(mins),
          selectedColor: AppColors.brandPrimary,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : context.appTextPrimary,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }
}

class _RecurrenceChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _RecurrenceChips({required this.selected, required this.onSelected});

  static const _options = <String?>[null, 'daily', 'weekly', 'monthly'];

  static String _label(String? rec) {
    if (rec == null) return 'One-time';
    return rec[0].toUpperCase() + rec.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _options.map((rec) {
        final isSelected = selected == rec;
        return ChoiceChip(
          label: Text(_label(rec)),
          selected: isSelected,
          onSelected: (_) => onSelected(rec),
          selectedColor: AppColors.brandPrimary,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : context.appTextPrimary,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onSubmit;

  const _SubmitButton({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FellowshipMeetingsBloc, FellowshipMeetingsState>(
      buildWhen: (prev, curr) => prev.submitting != curr.submitting,
      builder: (context, state) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: state.submitting
                ? null
                : const LinearGradient(
                    colors: [AppColors.brandPrimary, AppColors.brandSecondary],
                  ),
            color: state.submitting ? AppColors.brandPrimary : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: state.submitting
                ? null
                : [
                    BoxShadow(
                      color: AppColors.brandPrimary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                disabledBackgroundColor:
                    AppColors.brandPrimary.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: state.submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Schedule & Send Invites',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _MeetingTypeToggle extends StatelessWidget {
  final bool isInPerson;
  final ValueChanged<bool> onChanged;

  const _MeetingTypeToggle({required this.isInPerson, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Online',
          icon: Icons.videocam_rounded,
          selected: !isInPerson,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 8),
        _TypeChip(
          label: 'In-person',
          icon: Icons.location_on_rounded,
          selected: isInPerson,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : context.appInputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : context.appBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : context.appTextSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.appTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;

  const _LocationField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Location *',
        hintText: 'e.g. Community Hall, Room 3',
        prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
        filled: true,
        fillColor: context.appInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Please enter a location' : null,
    );
  }
}

/// A tappable tile used to display and trigger date/time pickers.
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.appInputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.brandPrimaryLight),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.appTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                size: 14,
                color: AppColors.brandPrimaryLight.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
