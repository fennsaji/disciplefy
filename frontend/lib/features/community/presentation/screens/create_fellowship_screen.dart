import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_list/fellowship_list_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Screen that allows a mentor/admin/paid user to create a new fellowship.
///
/// Creates its own [FellowshipListBloc] (same pattern as [JoinFellowshipScreen])
/// since GoRouter pushes it as a separate navigator page.
/// On success it pops with [true] so the community tab reloads the list.
class CreateFellowshipScreen extends StatefulWidget {
  const CreateFellowshipScreen({super.key});

  @override
  State<CreateFellowshipScreen> createState() => _CreateFellowshipScreenState();
}

class _CreateFellowshipScreenState extends State<CreateFellowshipScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _maxController = TextEditingController(text: '12');

  bool _hasName = false;
  bool _isPublic = false;
  String _language = 'en';
  String _postingPermission = 'all_members';
  bool _unlimitedMembers = false;
  bool _isOfficial = false;
  bool _disciplerAllowed = false;
  bool _dailyPostAllowed = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final hasName = _nameController.text.trim().isNotEmpty;
    if (hasName != _hasName) setState(() => _hasName = hasName);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _descController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _onCreatePressed(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final maxRaw = int.tryParse(_maxController.text.trim());
    context.read<FellowshipListBloc>().add(
          FellowshipCreateRequested(
            name: name,
            description: desc.isNotEmpty ? desc : null,
            maxMembers: _unlimitedMembers ? null : maxRaw,
            isPublic: _isPublic,
            language: _language,
            postingPermission: _postingPermission,
            unlimitedMembers: _unlimitedMembers,
            isOfficial: _isOfficial,
            disciplerAllowed: _isOfficial && _disciplerAllowed,
            dailyPostAllowed: _isOfficial && _dailyPostAllowed,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FellowshipListBloc>(
      create: (_) => sl<FellowshipListBloc>(),
      child: _CreateFellowshipConsumer(
        formKey: _formKey,
        nameController: _nameController,
        descController: _descController,
        maxController: _maxController,
        hasName: _hasName,
        isPublic: _isPublic,
        language: _language,
        postingPermission: _postingPermission,
        unlimitedMembers: _unlimitedMembers,
        isOfficial: _isOfficial,
        disciplerAllowed: _disciplerAllowed,
        dailyPostAllowed: _dailyPostAllowed,
        onIsPublicChanged: (v) => setState(() => _isPublic = v),
        onLanguageChanged: (v) => setState(() => _language = v),
        onPostingPermissionChanged: (v) =>
            setState(() => _postingPermission = v),
        onUnlimitedChanged: (v) => setState(() => _unlimitedMembers = v),
        onIsOfficialChanged: (v) => setState(() => _isOfficial = v),
        onDisciplerAllowedChanged: (v) => setState(() => _disciplerAllowed = v),
        onDailyPostAllowedChanged: (v) => setState(() => _dailyPostAllowed = v),
        onCreatePressed: _onCreatePressed,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inner BlocConsumer
// ---------------------------------------------------------------------------

class _CreateFellowshipConsumer extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController maxController;
  final bool hasName;
  final bool isPublic;
  final String language;
  final String postingPermission;
  final bool unlimitedMembers;
  final bool isOfficial;
  final bool disciplerAllowed;
  final bool dailyPostAllowed;
  final ValueChanged<bool> onIsPublicChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onPostingPermissionChanged;
  final ValueChanged<bool> onUnlimitedChanged;
  final ValueChanged<bool> onIsOfficialChanged;
  final ValueChanged<bool> onDisciplerAllowedChanged;
  final ValueChanged<bool> onDailyPostAllowedChanged;
  final void Function(BuildContext) onCreatePressed;

  const _CreateFellowshipConsumer({
    required this.formKey,
    required this.nameController,
    required this.descController,
    required this.maxController,
    required this.hasName,
    required this.isPublic,
    required this.language,
    required this.postingPermission,
    required this.unlimitedMembers,
    required this.isOfficial,
    required this.disciplerAllowed,
    required this.dailyPostAllowed,
    required this.onIsPublicChanged,
    required this.onLanguageChanged,
    required this.onPostingPermissionChanged,
    required this.onUnlimitedChanged,
    required this.onIsOfficialChanged,
    required this.onDisciplerAllowedChanged,
    required this.onDailyPostAllowedChanged,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<FellowshipListBloc, FellowshipListState>(
      listenWhen: (prev, curr) => prev.createStatus != curr.createStatus,
      listener: (context, state) {
        if (state.createStatus == FellowshipCreateStatus.success) {
          context.pop(true);
        } else if (state.createStatus == FellowshipCreateStatus.failure) {
          final message = state.createError ?? l10n.createFellowshipFailed;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
        }
      },
      buildWhen: (prev, curr) => prev.createStatus != curr.createStatus,
      builder: (context, state) {
        final isLoading = state.createStatus == FellowshipCreateStatus.loading;
        return Stack(
          children: [
            _CreateFellowshipBody(
              formKey: formKey,
              nameController: nameController,
              descController: descController,
              maxController: maxController,
              isLoading: isLoading,
              hasName: hasName,
              isPublic: isPublic,
              language: language,
              postingPermission: postingPermission,
              unlimitedMembers: unlimitedMembers,
              isOfficial: isOfficial,
              disciplerAllowed: disciplerAllowed,
              dailyPostAllowed: dailyPostAllowed,
              onIsPublicChanged: onIsPublicChanged,
              onLanguageChanged: onLanguageChanged,
              onPostingPermissionChanged: onPostingPermissionChanged,
              onUnlimitedChanged: onUnlimitedChanged,
              onIsOfficialChanged: onIsOfficialChanged,
              onDisciplerAllowedChanged: onDisciplerAllowedChanged,
              onDailyPostAllowedChanged: onDailyPostAllowedChanged,
              onCreatePressed: () => onCreatePressed(context),
            ),
            if (isLoading) const _LoadingOverlay(),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _CreateFellowshipBody
// ---------------------------------------------------------------------------

class _CreateFellowshipBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController maxController;
  final bool isLoading;
  final bool hasName;
  final bool isPublic;
  final String language;
  final String postingPermission;
  final bool unlimitedMembers;
  final bool isOfficial;
  final bool disciplerAllowed;
  final bool dailyPostAllowed;
  final ValueChanged<bool> onIsPublicChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onPostingPermissionChanged;
  final ValueChanged<bool> onUnlimitedChanged;
  final ValueChanged<bool> onIsOfficialChanged;
  final ValueChanged<bool> onDisciplerAllowedChanged;
  final ValueChanged<bool> onDailyPostAllowedChanged;
  final VoidCallback onCreatePressed;

  const _CreateFellowshipBody({
    required this.formKey,
    required this.nameController,
    required this.descController,
    required this.maxController,
    required this.isLoading,
    required this.hasName,
    required this.isPublic,
    required this.language,
    required this.postingPermission,
    required this.unlimitedMembers,
    required this.isOfficial,
    required this.disciplerAllowed,
    required this.dailyPostAllowed,
    required this.onIsPublicChanged,
    required this.onLanguageChanged,
    required this.onPostingPermissionChanged,
    required this.onUnlimitedChanged,
    required this.onIsOfficialChanged,
    required this.onDisciplerAllowedChanged,
    required this.onDailyPostAllowedChanged,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: CommunityBackBar(
        title: l10n.createFellowshipTitle,
        background: palette.page,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child:
                      PopupIconCircle(icon: Icons.groups_2_rounded, size: 72),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.createFellowshipHeading,
                  textAlign: TextAlign.center,
                  style: AppFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.createFellowshipSubtitle,
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    color: palette.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                CommunityGroupLabel(
                    context.tr(TranslationKeys.communityPagesAbout)),
                CommunityFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Name ────────────────────────────────────────────
                      CommunityFieldLabel(l10n.createFellowshipNameLabel),
                      TextFormField(
                        controller: nameController,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        maxLength: 60,
                        style: communityInputStyle(context),
                        decoration: communityInputDecoration(
                          context,
                          hintText: l10n.createFellowshipNameHint,
                          prefixIcon: Icons.group_rounded,
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.length < 3 || s.length > 60) {
                            return l10n.createFellowshipNameError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // ── Description ─────────────────────────────────────
                      CommunityFieldLabel(l10n.createFellowshipDescLabel),
                      TextFormField(
                        controller: descController,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        maxLength: 500,
                        maxLines: 3,
                        style: communityInputStyle(context),
                        decoration: communityInputDecoration(
                          context,
                          hintText: l10n.createFellowshipDescHint,
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.length > 500) {
                            return l10n.createFellowshipDescError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // ── Max members (+ admin-only unlimited toggle) ─────
                      BlocBuilder<AuthBloc, auth_states.AuthState>(
                        builder: (context, authState) {
                          final isAdmin =
                              authState is auth_states.AuthenticatedState &&
                                  authState.isAdmin;
                          final hideMaxField = isAdmin && unlimitedMembers;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!hideMaxField) ...[
                                CommunityFieldLabel(
                                    l10n.createFellowshipMaxLabel),
                                TextFormField(
                                  controller: maxController,
                                  enabled: !isLoading,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  style: communityInputStyle(context),
                                  decoration: communityInputDecoration(
                                    context,
                                    hintText: '12',
                                    prefixIcon: Icons.people_rounded,
                                  ),
                                  validator: (v) {
                                    if (hideMaxField) return null;
                                    final n = int.tryParse(v?.trim() ?? '');
                                    if (n == null || n < 2 || n > 50) {
                                      return l10n.createFellowshipMaxError;
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) {
                                    if (!isLoading && hasName) {
                                      onCreatePressed();
                                    }
                                  },
                                ),
                              ],
                              // Unlimited members — admin only, grouped with
                              // the cap.
                              if (isAdmin) ...[
                                const SizedBox(height: 8),
                                _FormSwitch(
                                  title: l10n.createFellowshipUnlimitedLabel,
                                  subtitle: l10n.createFellowshipUnlimitedHint,
                                  value: unlimitedMembers,
                                  onChanged:
                                      isLoading ? null : onUnlimitedChanged,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // ── Who can post (any creator can choose) ───────────
                      CommunityFieldLabel(l10n.createFellowshipWhoCanPostLabel),
                      CommunitySegmented<String>(
                        segments: [
                          CommunitySegment(
                            'all_members',
                            l10n.createFellowshipPostEveryone,
                            icon: Icons.groups_rounded,
                          ),
                          CommunitySegment(
                            'mentor_only',
                            l10n.createFellowshipPostAdminsOnly,
                            icon: Icons.shield_outlined,
                          ),
                        ],
                        selected: postingPermission,
                        onChanged:
                            isLoading ? null : onPostingPermissionChanged,
                      ),
                    ],
                  ),
                ),

                // ── Admin-only fields ─────────────────────────────────────
                BlocBuilder<AuthBloc, auth_states.AuthState>(
                  builder: (context, authState) {
                    if (authState is! auth_states.AuthenticatedState ||
                        !authState.isAdmin) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CommunityGroupLabel(l10n.adminOptionsLabel),
                        CommunityFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CommunityFieldLabel(
                                  l10n.createFellowshipLanguageLabel),
                              CommunitySegmented<String>(
                                segments: const [
                                  CommunitySegment('en', 'English'),
                                  CommunitySegment('hi', 'हिन्दी'),
                                  CommunitySegment('ml', 'മലയാളം'),
                                ],
                                selected: language,
                                onChanged: isLoading ? null : onLanguageChanged,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SettingsGroup(
                          children: [
                            CommunitySwitchRow(
                              title: l10n.createFellowshipMakePublicLabel,
                              subtitle: l10n.createFellowshipMakePublicHint,
                              value: isPublic,
                              onChanged: isLoading ? null : onIsPublicChanged,
                            ),
                            CommunitySwitchRow(
                              title: l10n.createFellowshipOfficial,
                              value: isOfficial,
                              onChanged: isLoading ? null : onIsOfficialChanged,
                            ),
                            CommunitySwitchRow(
                              title: l10n.createFellowshipDisciplerAllowed,
                              value: disciplerAllowed,
                              onChanged: (isLoading || !isOfficial)
                                  ? null
                                  : onDisciplerAllowedChanged,
                            ),
                            CommunitySwitchRow(
                              title: l10n.createFellowshipDailyAllowed,
                              value: dailyPostAllowed,
                              onChanged: (isLoading || !isOfficial)
                                  ? null
                                  : onDailyPostAllowedChanged,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Create button ─────────────────────────────────────────
                CommunityWideCta(
                  label: l10n.createFellowshipButton,
                  icon: Icons.groups_2_rounded,
                  loading: isLoading,
                  onPressed: hasName && !isLoading ? onCreatePressed : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FormSwitch — switch row inside a form card (no card chrome of its own)
// ---------------------------------------------------------------------------

class _FormSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _FormSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SettingsSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LoadingOverlay
// ---------------------------------------------------------------------------

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: palette.page.withValues(alpha: 0.55),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(palette.accentIcon),
          ),
        ),
      ),
    );
  }
}
