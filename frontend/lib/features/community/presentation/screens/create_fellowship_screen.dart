import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import '../bloc/fellowship_list/fellowship_list_bloc.dart';
import '../bloc/fellowship_list/fellowship_list_event.dart';
import '../bloc/fellowship_list/fellowship_list_state.dart';

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
            maxMembers: maxRaw,
            isPublic: _isPublic,
            language: _language,
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
        onIsPublicChanged: (v) => setState(() => _isPublic = v),
        onLanguageChanged: (v) => setState(() => _language = v),
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
  final ValueChanged<bool> onIsPublicChanged;
  final ValueChanged<String> onLanguageChanged;
  final void Function(BuildContext) onCreatePressed;

  const _CreateFellowshipConsumer({
    required this.formKey,
    required this.nameController,
    required this.descController,
    required this.maxController,
    required this.hasName,
    required this.isPublic,
    required this.language,
    required this.onIsPublicChanged,
    required this.onLanguageChanged,
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
              onIsPublicChanged: onIsPublicChanged,
              onLanguageChanged: onLanguageChanged,
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
  final ValueChanged<bool> onIsPublicChanged;
  final ValueChanged<String> onLanguageChanged;
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
    required this.onIsPublicChanged,
    required this.onLanguageChanged,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(
          l10n.createFellowshipTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon ────────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.groups_2_rounded,
                      size: 44,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Heading ──────────────────────────────────────────────────
                Center(
                  child: Text(
                    l10n.createFellowshipHeading,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    l10n.createFellowshipSubtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.appTextSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Name field ───────────────────────────────────────────────
                _FieldLabel(label: l10n.createFellowshipNameLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  maxLength: 60,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: context.appTextPrimary,
                  ),
                  decoration: _inputDecoration(
                    context: context,
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

                const SizedBox(height: 20),

                // ── Description field ────────────────────────────────────────
                _FieldLabel(label: l10n.createFellowshipDescLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  maxLength: 500,
                  maxLines: 3,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: context.appTextPrimary,
                  ),
                  decoration: _inputDecoration(
                    context: context,
                    hintText: l10n.createFellowshipDescHint,
                    prefixIcon: null,
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length > 500) return l10n.createFellowshipDescError;
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ── Max members field ────────────────────────────────────────
                _FieldLabel(label: l10n.createFellowshipMaxLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: maxController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: context.appTextPrimary,
                  ),
                  decoration: _inputDecoration(
                    context: context,
                    hintText: '12',
                    prefixIcon: Icons.people_rounded,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 2 || n > 50) {
                      return l10n.createFellowshipMaxError;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!isLoading && hasName) onCreatePressed();
                  },
                ),

                // ── Admin-only fields ─────────────────────────────────────────
                BlocBuilder<AuthBloc, auth_states.AuthState>(
                  builder: (context, authState) {
                    if (authState is! auth_states.AuthenticatedState ||
                        !authState.isAdmin) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Language dropdown
                        DropdownButtonFormField<String>(
                          value: language,
                          decoration: InputDecoration(
                            labelText: l10n.createFellowshipLanguageLabel,
                            labelStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: context.appTextSecondary,
                            ),
                            filled: true,
                            fillColor: context.appInputFill,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: context.appBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: context.appBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            color: context.appTextPrimary,
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'en', child: Text('English')),
                            DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                            DropdownMenuItem(
                                value: 'ml', child: Text('Malayalam')),
                          ],
                          onChanged: isLoading
                              ? null
                              : (v) => onLanguageChanged(v ?? 'en'),
                        ),
                        const SizedBox(height: 16),
                        // Public toggle
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.createFellowshipMakePublicLabel,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: context.appTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.createFellowshipMakePublicHint,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isPublic,
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                              onChanged: isLoading ? null : onIsPublicChanged,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 36),

                // ── Create button ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _CreateButton(
                    isLoading: isLoading,
                    isEnabled: hasName && !isLoading,
                    onPressed: onCreatePressed,
                    label: l10n.createFellowshipButton,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hintText,
    required IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: context.appTextTertiary,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: context.appInputFill,
      counterStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: context.appTextTertiary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.appBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.appBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.appBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: context.appTextTertiary)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// _FieldLabel
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimary,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CreateButton
// ---------------------------------------------------------------------------

class _CreateButton extends StatelessWidget {
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;
  final String label;

  const _CreateButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) {
      return Container(
        decoration: BoxDecoration(
          color: context.appBorder,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextTertiary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.groups_2_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
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
// _LoadingOverlay
// ---------------------------------------------------------------------------

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.overlayLight,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
