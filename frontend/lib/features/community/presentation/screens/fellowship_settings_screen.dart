import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mentor_contact_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

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
      showAppSnackBar(context, l10n.mentorContactInvalidWhatsapp,
          tone: AppSnackTone.warning);
      return false;
    }
    if (rawEmail.isNotEmpty && !isValidEmailValue(rawEmail)) {
      showAppSnackBar(context, l10n.mentorContactInvalidEmail,
          tone: AppSnackTone.warning);
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
        showAppSnackBar(context, ErrorMessageSanitizer.sanitize(failure),
            tone: AppSnackTone.error);
      },
      (confirmed) {
        setState(() {
          _savedWhatsapp = confirmed.whatsapp ?? '';
          _savedEmail = confirmed.email ?? '';
          _mentorWhatsappController.text = _savedWhatsapp;
          _mentorEmailController.text = _savedEmail;
        });
        if (!silent) {
          showAppSnackBar(context, l10n.editFellowshipSuccess,
              tone: AppSnackTone.success);
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
      builder: (dialogContext) => SettingsDialog(
        title: l10n.unsavedChangesTitle,
        content: Text(l10n.unsavedChangesMessage),
        actions: [
          SettingsButton(
            label: l10n.cancel,
            kind: SettingsButtonKind.neutral,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          SettingsButton(
            label: l10n.discard,
            kind: SettingsButtonKind.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SettingsButton(
            label: l10n.editFellowshipSave,
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
    final palette = ReaderPalette.of(context);

    return BlocConsumer<FellowshipSettingsBloc, FellowshipSettingsState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == FellowshipSettingsStatus.saved) {
          showAppSnackBar(context, l10n.editFellowshipSuccess,
              tone: AppSnackTone.success);
          Navigator.of(context).pop(state.original);
        } else if (state.status == FellowshipSettingsStatus.failure &&
            state.errorMessage != null) {
          showAppSnackBar(context, state.errorMessage!,
              tone: AppSnackTone.error);
        }
      },
      builder: (context, state) {
        final draft = state.draft ?? widget.fellowship;
        final saving = state.status == FellowshipSettingsStatus.saving;
        final bloc = context.read<FellowshipSettingsBloc>();

        final dirty = state.isDirty || _contactDirty;

        final scopeOptions = [
          CommunitySegment('all', l10n.disciplerScopeAll),
          CommunitySegment('lessons_only', l10n.disciplerScopeLessons),
        ];
        final delayOptions = [
          CommunitySegment(0, l10n.disciplerDelayNow),
          CommunitySegment(30, l10n.disciplerDelay30),
          CommunitySegment(120, l10n.disciplerDelay120),
          CommunitySegment(720, l10n.disciplerDelay720),
        ];
        String? labelFor<T>(List<CommunitySegment<T>> options, T value) =>
            options.firstWhereOrNull((o) => o.value == value)?.label;

        final eyebrow = [
          widget.fellowship.name,
          if (_isMentor) context.tr(TranslationKeys.communityPagesYouAreMentor),
        ].where((s) => s.trim().isNotEmpty).join(' · ');

        return PopScope(
          canPop: !dirty && !saving,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || saving) return;
            if (await _confirmLeave(state) && mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: palette.page,
            appBar: CommunityBackBar(
              background: palette.page,
              actions: [
                // Saves both sections: the settings fields and, when edited,
                // the contact details, which use a separate endpoint.
                TextButton(
                  onPressed: dirty && !saving && !_mentorContactSaving
                      ? () => _saveAll(state)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.accentIcon,
                    minimumSize: const Size(44, 44),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n.editFellowshipSave,
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CommunityPageHeading(
                    eyebrow: eyebrow,
                    title: l10n.fellowshipSettingsTitle,
                  ),
                ),
                const SizedBox(height: 6),
                CommunityGroupLabel(
                    context.tr(TranslationKeys.communityPagesAbout)),
                CommunityFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CommunityFieldLabel(l10n.createFellowshipNameLabel),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 60,
                        style: communityInputStyle(context),
                        decoration: communityInputDecoration(context),
                        onChanged: (v) =>
                            bloc.add(FellowshipSettingsChanged(name: v)),
                      ),
                      const SizedBox(height: 8),
                      CommunityFieldLabel(l10n.createFellowshipDescLabel),
                      TextFormField(
                        controller: _descController,
                        maxLength: 500,
                        maxLines: 3,
                        minLines: 2,
                        style: communityInputStyle(context),
                        decoration: communityInputDecoration(context),
                        onChanged: (v) =>
                            bloc.add(FellowshipSettingsChanged(description: v)),
                      ),
                      const SizedBox(height: 8),
                      CommunityFieldLabel(l10n.createFellowshipWhoCanPostLabel),
                      CommunitySegmented<String>(
                        segments: [
                          CommunitySegment(
                            'all_members',
                            l10n.createFellowshipPostEveryone,
                          ),
                          CommunitySegment(
                            'mentor_only',
                            l10n.createFellowshipPostAdminsOnly,
                          ),
                        ],
                        selected: draft.postingPermission,
                        onChanged: (v) => bloc.add(
                            FellowshipSettingsChanged(postingPermission: v)),
                      ),
                    ],
                  ),
                ),
                if (widget.fellowship.disciplerAllowed) ...[
                  CommunityGroupLabel(
                    l10n.disciplerSettingsSection,
                    trailing: _AllowedByAdminChip(
                        label: l10n.disciplerAllowedByAdmin),
                  ),
                  SettingsGroup(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const DisciplerAvatar(radius: 16),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.disciplerAnswerQuestions,
                                    style: AppFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: palette.text,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            CommunitySegmented<String>(
                              segments: [
                                CommunitySegment('off', l10n.disciplerModeOff),
                                CommunitySegment(
                                    'auto', l10n.disciplerModeAuto),
                                CommunitySegment(
                                    'review', l10n.disciplerModeReview),
                              ],
                              selected: draft.disciplerReplyMode,
                              onChanged: (v) => bloc.add(
                                  FellowshipSettingsChanged(
                                      disciplerReplyMode: v)),
                            ),
                          ],
                        ),
                      ),
                      CommunitySettingRow(
                        title: l10n.disciplerWhichQuestions,
                        value:
                            labelFor(scopeOptions, draft.disciplerReplyScope),
                        onTap: () async {
                          final picked = await showCommunityChoiceSheet(
                            context: context,
                            title: l10n.disciplerWhichQuestions,
                            options: scopeOptions,
                            selected: draft.disciplerReplyScope,
                          );
                          if (picked != null &&
                              picked != draft.disciplerReplyScope) {
                            bloc.add(FellowshipSettingsChanged(
                                disciplerReplyScope: picked));
                          }
                        },
                      ),
                      CommunitySettingRow(
                        title: l10n.disciplerWaitFirst,
                        value: labelFor(
                            delayOptions, draft.disciplerReplyDelayMin),
                        onTap: () async {
                          final picked = await showCommunityChoiceSheet(
                            context: context,
                            title: l10n.disciplerWaitFirst,
                            options: delayOptions,
                            selected: draft.disciplerReplyDelayMin,
                          );
                          if (picked != null &&
                              picked != draft.disciplerReplyDelayMin) {
                            bloc.add(FellowshipSettingsChanged(
                                disciplerReplyDelayMin: picked));
                          }
                        },
                      ),
                      CommunitySwitchRow(
                        title: l10n.disciplerReactToggle,
                        value: draft.disciplerReactEnabled,
                        onChanged: (v) => bloc.add(FellowshipSettingsChanged(
                            disciplerReactEnabled: v)),
                      ),
                      // Daily post settings live on the Daily post screen.
                      if (widget.fellowship.dailyPostAllowed)
                        CommunitySettingRow(
                          title: l10n.dailyPostScreenTitle,
                          onTap: () => context.push(
                              '/community/${widget.fellowship.id}/daily-post'),
                        ),
                      CommunitySwitchRow(
                        title: l10n.disciplerNotifyToggle,
                        value: draft.myDisciplerActivityPush,
                        onChanged: (v) => bloc.add(FellowshipSettingsChanged(
                            disciplerActivityPush: v)),
                      ),
                    ],
                  ),
                ],
                // Save for THIS section (everything above), mirroring the
                // contact section's own button below.
                const SizedBox(height: 16),
                SettingsButton(
                  label: l10n.editFellowshipSave,
                  loading: saving,
                  onPressed: state.isDirty && !saving
                      ? () => bloc.add(const FellowshipSettingsSaveRequested())
                      : null,
                ),
                if (_isMentor) ...[
                  CommunityGroupLabel(l10n.mentorContactTitle),
                  CommunityFormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.mentorContactSubtitle,
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            color: palette.muted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_mentorContactLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else ...[
                          CommunityFieldLabel(l10n.contactWhatsapp),
                          TextFormField(
                            controller: _mentorWhatsappController,
                            keyboardType: TextInputType.phone,
                            style: communityInputStyle(context),
                            decoration: communityInputDecoration(
                              context,
                              helperText: l10n.mentorContactBlankHint,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CommunityFieldLabel(l10n.contactEmail),
                          TextFormField(
                            controller: _mentorEmailController,
                            keyboardType: TextInputType.emailAddress,
                            style: communityInputStyle(context),
                            decoration: communityInputDecoration(
                              context,
                              helperText: l10n.mentorContactBlankHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Distinct label: this button saves only the
                          // contact fields, through a different endpoint than
                          // the "Save Changes" action in the app bar. Sharing
                          // one label made the two look interchangeable.
                          SettingsButton(
                            label: l10n.saveContactDetails,
                            kind: SettingsButtonKind.neutral,
                            loading: _mentorContactSaving,
                            onPressed: _mentorContactSaving
                                ? null
                                : _saveMentorContact,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small green "Allowed by admin" chip beside the Discipler section label.
class _AllowedByAdminChip extends StatelessWidget {
  final String label;

  const _AllowedByAdminChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final tone = SettingsToneColors.of(context, SettingsTone.green);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tone.fill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tone.foreground,
          ),
        ),
      ),
    );
  }
}
