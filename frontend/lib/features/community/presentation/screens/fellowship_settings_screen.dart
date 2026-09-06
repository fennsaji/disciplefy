import 'package:collection/collection.dart';
import '../../../../core/utils/error_message_sanitizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_entity.dart';
import '../../domain/repositories/community_repository.dart';
import '../bloc/fellowship_settings/fellowship_settings_bloc.dart';
import '../bloc/fellowship_settings/fellowship_settings_event.dart';
import '../bloc/fellowship_settings/fellowship_settings_state.dart';
import '../utils/mentor_contact_helpers.dart';
import '../widgets/discipler_badges.dart';

/// Fellowship settings screen: name/description/posting permission, plus
/// (when [FellowshipEntity.disciplerAllowed]) the mentor-only Discipler
/// preference controls.
class FellowshipSettingsScreen extends StatefulWidget {
  final String fellowshipId;
  final FellowshipEntity fellowship;

  const FellowshipSettingsScreen({
    required this.fellowshipId,
    required this.fellowship,
    super.key,
  });

  @override
  State<FellowshipSettingsScreen> createState() =>
      _FellowshipSettingsScreenState();
}

class _FellowshipSettingsScreenState extends State<FellowshipSettingsScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.fellowship.name);
  late final TextEditingController _descController =
      TextEditingController(text: widget.fellowship.description ?? '');
  final TextEditingController _mentorWhatsappController =
      TextEditingController();
  final TextEditingController _mentorEmailController = TextEditingController();

  bool _mentorContactLoading = true;
  bool _mentorContactSaving = false;

  bool get _isMentor => widget.fellowship.userRole == 'mentor';

  @override
  void initState() {
    super.initState();
    if (_isMentor) {
      _loadMentorContact();
    } else {
      _mentorContactLoading = false;
    }
  }

  Future<void> _loadMentorContact() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final result = await sl<CommunityRepository>()
        .getFellowshipMembers(widget.fellowshipId);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _mentorContactLoading = false),
      (members) {
        final me = members.firstWhereOrNull((m) => m.userId == currentUserId);
        setState(() {
          _mentorWhatsappController.text = me?.mentorWhatsapp ?? '';
          _mentorEmailController.text = me?.mentorEmail ?? '';
          _mentorContactLoading = false;
        });
      },
    );
  }

  Future<void> _saveMentorContact() async {
    final l10n = AppLocalizations.of(context)!;
    final rawWhatsapp = _mentorWhatsappController.text.trim();
    final rawEmail = _mentorEmailController.text.trim();

    if (rawWhatsapp.isNotEmpty && !isValidWhatsAppValue(rawWhatsapp)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.mentorContactInvalidWhatsapp)));
      return;
    }
    if (rawEmail.isNotEmpty && !isValidEmailValue(rawEmail)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.mentorContactInvalidEmail)));
      return;
    }

    final normalizedWhatsapp =
        rawWhatsapp.isEmpty ? null : normalizeWhatsAppDigits(rawWhatsapp);
    final normalizedEmail = rawEmail.isEmpty ? null : rawEmail;

    setState(() => _mentorContactSaving = true);
    final result = await sl<CommunityRepository>().updateMentorContact(
      fellowshipId: widget.fellowshipId,
      whatsapp: normalizedWhatsapp,
      email: normalizedEmail,
    );
    if (!mounted) return;
    setState(() => _mentorContactSaving = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(ErrorMessageSanitizer.sanitize(failure)))),
      (confirmed) {
        setState(() {
          _mentorWhatsappController.text = confirmed.whatsapp ?? '';
          _mentorEmailController.text = confirmed.email ?? '';
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.editFellowshipSuccess)));
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _mentorWhatsappController.dispose();
    _mentorEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<FellowshipSettingsBloc, FellowshipSettingsState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == FellowshipSettingsStatus.saved) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.editFellowshipSuccess)));
          Navigator.of(context).pop(state.original);
        } else if (state.status == FellowshipSettingsStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final draft = state.draft ?? widget.fellowship;
        final saving = state.status == FellowshipSettingsStatus.saving;

        return Scaffold(
          backgroundColor: context.appScaffold,
          appBar: AppBar(
            backgroundColor: context.appScaffold,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              l10n.fellowshipSettingsTitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: state.isDirty && !saving
                    ? () => context
                        .read<FellowshipSettingsBloc>()
                        .add(const FellowshipSettingsSaveRequested())
                    : null,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.editFellowshipSave),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.createFellowshipNameLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                maxLength: 60,
                onChanged: (v) => context
                    .read<FellowshipSettingsBloc>()
                    .add(FellowshipSettingsChanged(name: v)),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.createFellowshipDescLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLength: 500,
                maxLines: 3,
                onChanged: (v) => context
                    .read<FellowshipSettingsBloc>()
                    .add(FellowshipSettingsChanged(description: v)),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.createFellowshipWhoCanPostLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'all_members',
                    label: Text(l10n.createFellowshipPostEveryone),
                    icon: const Icon(Icons.groups_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: 'mentor_only',
                    label: Text(l10n.createFellowshipPostAdminsOnly),
                    icon: const Icon(Icons.shield_rounded, size: 18),
                  ),
                ],
                selected: {draft.postingPermission},
                showSelectedIcon: false,
                onSelectionChanged: (s) => context
                    .read<FellowshipSettingsBloc>()
                    .add(FellowshipSettingsChanged(postingPermission: s.first)),
              ),
              if (widget.fellowship.disciplerAllowed) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    const DisciplerAvatar(radius: 12),
                    const SizedBox(width: 8),
                    Text(
                      l10n.disciplerSettingsSection,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.disciplerAllowedByAdmin,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.successDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.disciplerAnswerQuestions,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'off', label: Text(l10n.disciplerModeOff)),
                    ButtonSegment(
                        value: 'auto', label: Text(l10n.disciplerModeAuto)),
                    ButtonSegment(
                        value: 'review', label: Text(l10n.disciplerModeReview)),
                  ],
                  selected: {draft.disciplerReplyMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => context
                      .read<FellowshipSettingsBloc>()
                      .add(FellowshipSettingsChanged(
                          disciplerReplyMode: s.first)),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.disciplerWhichQuestions,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'all', label: Text(l10n.disciplerScopeAll)),
                    ButtonSegment(
                        value: 'lessons_only',
                        label: Text(l10n.disciplerScopeLessons)),
                  ],
                  selected: {draft.disciplerReplyScope},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => context
                      .read<FellowshipSettingsBloc>()
                      .add(FellowshipSettingsChanged(
                          disciplerReplyScope: s.first)),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.disciplerWaitFirst,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                        value: 0, label: Text(l10n.disciplerDelayNow)),
                    ButtonSegment(
                        value: 30, label: Text(l10n.disciplerDelay30)),
                    ButtonSegment(
                        value: 120, label: Text(l10n.disciplerDelay120)),
                    ButtonSegment(
                        value: 720, label: Text(l10n.disciplerDelay720)),
                  ],
                  selected: {draft.disciplerReplyDelayMin},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => context
                      .read<FellowshipSettingsBloc>()
                      .add(FellowshipSettingsChanged(
                          disciplerReplyDelayMin: s.first)),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.disciplerReactToggle),
                  value: draft.disciplerReactEnabled,
                  onChanged: (v) => context
                      .read<FellowshipSettingsBloc>()
                      .add(FellowshipSettingsChanged(disciplerReactEnabled: v)),
                ),
                if (widget.fellowship.dailyPostAllowed) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.disciplerDailyToggle),
                    value: draft.dailyPostOn,
                    onChanged: (v) => context
                        .read<FellowshipSettingsBloc>()
                        .add(FellowshipSettingsChanged(dailyPostOn: v)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.dailyPostFrequency,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 1, label: Text(l10n.frequencyDaily)),
                      ButtonSegment(
                          value: 2, label: Text(l10n.frequencyEveryTwoDays)),
                      ButtonSegment(
                          value: 7, label: Text(l10n.frequencyWeekly)),
                    ],
                    selected: {draft.dailyPostFrequencyDays},
                    showSelectedIcon: false,
                    onSelectionChanged: draft.dailyPostOn
                        ? (s) => context.read<FellowshipSettingsBloc>().add(
                            FellowshipSettingsChanged(
                                dailyPostFrequencyDays: s.first))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.disciplerAdvancesLessons),
                    subtitle: Text(l10n.disciplerAdvancesLessonsSubtitle),
                    value: draft.dailyPostAutoAdvance,
                    onChanged: draft.dailyPostOn
                        ? (v) => context.read<FellowshipSettingsBloc>().add(
                            FellowshipSettingsChanged(dailyPostAutoAdvance: v))
                        : null,
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.disciplerNotifyToggle),
                  value: draft.myDisciplerActivityPush,
                  onChanged: (v) => context
                      .read<FellowshipSettingsBloc>()
                      .add(FellowshipSettingsChanged(disciplerActivityPush: v)),
                ),
              ],
              if (_isMentor) ...[
                const SizedBox(height: 28),
                Text(
                  l10n.mentorContactTitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.mentorContactSubtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (_mentorContactLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  TextFormField(
                    controller: _mentorWhatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.contactWhatsapp,
                      helperText: l10n.mentorContactBlankHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _mentorEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.contactEmail,
                      helperText: l10n.mentorContactBlankHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed:
                          _mentorContactSaving ? null : _saveMentorContact,
                      child: _mentorContactSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.editFellowshipSave),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
