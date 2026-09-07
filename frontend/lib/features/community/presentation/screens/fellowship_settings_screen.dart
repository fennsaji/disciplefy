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

  // What the contact fields held when last loaded or saved. The app-bar
  // action and the leave-prompt both need to know whether this section has
  // unsaved edits, which the settings bloc knows nothing about.
  String _savedWhatsapp = '';
  String _savedEmail = '';

  bool get _contactDirty =>
      _isMentor &&
      !_mentorContactLoading &&
      (_mentorWhatsappController.text.trim() != _savedWhatsapp ||
          _mentorEmailController.text.trim() != _savedEmail);

  bool get _isMentor => widget.fellowship.userRole == 'mentor';

  @override
  void initState() {
    super.initState();
    if (_isMentor) {
      _mentorWhatsappController.addListener(_onContactChanged);
      _mentorEmailController.addListener(_onContactChanged);
      _loadMentorContact();
    } else {
      _mentorContactLoading = false;
    }
  }

  void _onContactChanged() => setState(() {});

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
          _savedWhatsapp = me?.mentorWhatsapp ?? '';
          _savedEmail = me?.mentorEmail ?? '';
          _mentorWhatsappController.text = _savedWhatsapp;
          _mentorEmailController.text = _savedEmail;
          _mentorContactLoading = false;
        });
      },
    );
  }

  Future<bool> _saveMentorContact({bool silent = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final rawWhatsapp = _mentorWhatsappController.text.trim();
    final rawEmail = _mentorEmailController.text.trim();

    if (rawWhatsapp.isNotEmpty && !isValidWhatsAppValue(rawWhatsapp)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.mentorContactInvalidWhatsapp)));
      return false;
    }
    if (rawEmail.isNotEmpty && !isValidEmailValue(rawEmail)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.mentorContactInvalidEmail)));
      return false;
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
    if (!mounted) return false;
    setState(() => _mentorContactSaving = false);
    var ok = true;
    result.fold(
      (failure) {
        ok = false;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text(ErrorMessageSanitizer.sanitize(failure))));
      },
      (confirmed) {
        setState(() {
          _savedWhatsapp = confirmed.whatsapp ?? '';
          _savedEmail = confirmed.email ?? '';
          _mentorWhatsappController.text = _savedWhatsapp;
          _mentorEmailController.text = _savedEmail;
        });
        if (!silent) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.editFellowshipSuccess)));
        }
      },
    );
    return ok;
  }

  /// Saves whichever sections have unsaved edits.
  ///
  /// The contact fields go through a different endpoint than the rest of the
  /// settings, so "Save Changes" has to drive both. Contact is saved first;
  /// if it fails we stop rather than half-saving and popping the screen.
  Future<void> _saveAll(FellowshipSettingsState state) async {
    if (_contactDirty) {
      final ok = await _saveMentorContact(silent: state.isDirty);
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    if (state.isDirty) {
      // The bloc listener pops on success.
      context
          .read<FellowshipSettingsBloc>()
          .add(const FellowshipSettingsSaveRequested());
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Asks before discarding unsaved edits in either section.
  Future<bool> _confirmLeave(FellowshipSettingsState state) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.unsavedChangesTitle),
        content: Text(l10n.unsavedChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.editFellowshipSave),
          ),
        ],
      ),
    );
    if (shouldSave == null) return false; // Cancel: stay on the screen.
    if (!shouldSave) return true; // Discard: leave without saving.
    if (!mounted) return false;
    await _saveAll(state);
    return false; // _saveAll pops once the save succeeds.
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

        final dirty = state.isDirty || _contactDirty;

        return PopScope(
          canPop: !dirty && !saving,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || saving) return;
            if (await _confirmLeave(state) && mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
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
                  // Saves both sections: the settings fields and, when edited,
                  // the contact details, which use a separate endpoint.
                  onPressed: dirty && !saving && !_mentorContactSaving
                      ? () => _saveAll(state)
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
                      .add(FellowshipSettingsChanged(
                          postingPermission: s.first)),
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
                          value: 'review',
                          label: Text(l10n.disciplerModeReview)),
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
                        .add(FellowshipSettingsChanged(
                            disciplerReactEnabled: v)),
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
                        ButtonSegment(
                            value: 1, label: Text(l10n.frequencyDaily)),
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
                              FellowshipSettingsChanged(
                                  dailyPostAutoAdvance: v))
                          : null,
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.disciplerNotifyToggle),
                    value: draft.myDisciplerActivityPush,
                    onChanged: (v) => context
                        .read<FellowshipSettingsBloc>()
                        .add(FellowshipSettingsChanged(
                            disciplerActivityPush: v)),
                  ),
                ],
                // Save for THIS section (everything above), mirroring the
                // contact section's own button below.
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: state.isDirty && !saving
                        ? () => context
                            .read<FellowshipSettingsBloc>()
                            .add(const FellowshipSettingsSaveRequested())
                        : null,
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.editFellowshipSave),
                  ),
                ),
                if (_isMentor) ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
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
                            // Distinct label: this button saves only the
                            // contact fields, through a different endpoint than
                            // the "Save Changes" action in the app bar. Sharing
                            // one label made the two look interchangeable.
                            : Text(l10n.saveContactDetails),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
