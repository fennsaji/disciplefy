import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_entity.dart';
import '../bloc/fellowship_settings/fellowship_settings_bloc.dart';
import '../bloc/fellowship_settings/fellowship_settings_event.dart';
import '../bloc/fellowship_settings/fellowship_settings_state.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
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
                if (widget.fellowship.dailyPostAllowed)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.disciplerDailyToggle),
                    value: draft.dailyPostOn,
                    onChanged: (v) => context
                        .read<FellowshipSettingsBloc>()
                        .add(FellowshipSettingsChanged(dailyPostOn: v)),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.disciplerNotifyToggle),
                  value: draft.myDisciplerActivityPush,
                  onChanged: (v) => context
                      .read<FellowshipSettingsBloc>()
                      .add(FellowshipSettingsChanged(disciplerActivityPush: v)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
