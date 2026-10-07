import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/domain/utils/auth_validator.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';

/// The Google / Apple / email buttons that turn a guest into a full account,
/// shared by the account-needed sheet and the sign-up block on "Lesson
/// complete".
///
/// Links through [GuestSessionService], so the guest's user id and progress
/// are kept. Email opens a small inline form (name, email, password) instead
/// of the sign-up screen: the sign-up screen creates a new user, while
/// linking keeps the guest's.
class AccountLinkPanel extends StatefulWidget {
  /// Called once the guest is a full account ([LinkOutcome.linked] or
  /// [LinkOutcome.mergedIntoExisting]). The profile refresh is already sent.
  final ValueChanged<LinkOutcome> onLinked;

  const AccountLinkPanel({super.key, required this.onLinked});

  /// Overrides the platform check in tests.
  @visibleForTesting
  static bool? debugShowApple;

  /// Apple sign-in shows where the login screen shows it: iOS only.
  static bool get showApple => debugShowApple ?? (!kIsWeb && Platform.isIOS);

  @override
  State<AccountLinkPanel> createState() => _AccountLinkPanelState();
}

class _AccountLinkPanelState extends State<AccountLinkPanel> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _emailOpen = false;
  bool _obscure = true;

  /// Translation key of the inline note under the buttons.
  String? _noteKey;

  /// Set once a confirmation email was sent to this address.
  String? _confirmEmail;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<LinkOutcome> Function() link,
      {String? email}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _noteKey = null;
    });
    LinkOutcome? outcome;
    try {
      outcome = await link();
    } catch (e) {
      Logger.warning('Account link failed',
          tag: 'GUEST', context: {'error': e.runtimeType.toString()});
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case LinkOutcome.linked:
      case LinkOutcome.mergedIntoExisting:
        _refreshProfile();
        widget.onLinked(outcome!);
      case LinkOutcome.emailConfirmationSent:
        setState(() {
          _confirmEmail = email;
          _emailOpen = false;
        });
      case LinkOutcome.mergeFailed:
        setState(() => _noteKey = TranslationKeys.accountMergePending);
      case LinkOutcome.cancelled:
      case LinkOutcome.redirecting:
        break;
      case null:
        setState(() => _noteKey = TranslationKeys.accountLinkFailed);
    }
  }

  void _refreshProfile() {
    try {
      context.read<AuthBloc>().add(const RefreshUserProfileRequested());
    } catch (_) {
      // No AuthBloc above this widget (tests): nothing to refresh.
    }
  }

  void _submitEmail() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    _run(
      () => sl<GuestSessionService>().linkEmail(
        email: email,
        password: _password.text,
        fullName: _name.text.trim(),
      ),
      email: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final service = sl<GuestSessionService>();
    final confirm = _confirmEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (confirm != null)
          _Note(
            key: const Key('account_check_email'),
            text: context
                .tr(TranslationKeys.accountCheckEmail, {'email': confirm}),
            icon: Icons.mark_email_read_outlined,
          )
        else ...[
          AccountButton(
            key: const Key('account_google'),
            label: context.tr(TranslationKeys.accountContinueGoogle),
            style: AccountButtonStyle.primary,
            onPressed: _busy ? null : () => _run(service.linkGoogle),
          ),
          if (AccountLinkPanel.showApple) ...[
            const SizedBox(height: 8),
            AccountButton(
              key: const Key('account_apple'),
              label: context.tr(TranslationKeys.accountContinueApple),
              icon: Icons.apple,
              style: AccountButtonStyle.inverse,
              onPressed: _busy ? null : () => _run(service.linkApple),
            ),
          ],
          const SizedBox(height: 8),
          AccountButton(
            key: const Key('account_email'),
            label: context.tr(TranslationKeys.accountContinueEmail),
            icon: Icons.mail_outline_rounded,
            style: AccountButtonStyle.outlined,
            onPressed:
                _busy ? null : () => setState(() => _emailOpen = !_emailOpen),
          ),
          if (_emailOpen) ...[
            const SizedBox(height: 12),
            _emailForm(context, palette),
          ],
        ],
        if (_noteKey != null) ...[
          const SizedBox(height: 10),
          _Note(
            key: const Key('account_note'),
            text: context.tr(_noteKey!),
            icon: Icons.info_outline_rounded,
          ),
        ],
      ],
    );
  }

  Widget _emailForm(BuildContext context, ReaderPalette palette) {
    InputDecoration deco(IconData icon, String hint, {Widget? suffix}) =>
        InputDecoration(
          isDense: true,
          filled: true,
          fillColor: palette.raised,
          prefixIcon: Icon(icon, size: 18, color: palette.muted),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: palette.dim),
          hintMaxLines: 2,
          errorStyle: const TextStyle(fontSize: 12),
          errorMaxLines: 2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        );
    final fieldStyle = TextStyle(fontSize: 14, color: palette.text);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const Key('account_email_name'),
            controller: _name,
            style: fieldStyle,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: deco(Icons.person_outline_rounded,
                context.tr(TranslationKeys.emailAuthFullNameHint)),
            validator: (v) => v == null || !AuthValidator.isValidFullName(v)
                ? context.tr(TranslationKeys.emailAuthInvalidName)
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('account_email_address'),
            controller: _email,
            style: fieldStyle,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: deco(Icons.mail_outline_rounded,
                context.tr(TranslationKeys.emailAuthEmailHint)),
            validator: (v) => v == null || !AuthValidator.isValidEmail(v.trim())
                ? context.tr(TranslationKeys.emailAuthInvalidEmail)
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('account_email_password'),
            controller: _password,
            style: fieldStyle,
            obscureText: _obscure,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _submitEmail(),
            decoration: deco(
              Icons.lock_outline_rounded,
              context.tr(TranslationKeys.emailAuthNewPasswordHint),
              suffix: IconButton(
                iconSize: 18,
                color: palette.muted,
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => v == null || !AuthValidator.isValidPassword(v)
                ? context.tr(TranslationKeys.emailAuthInvalidPassword)
                : null,
          ),
          const SizedBox(height: 10),
          AccountButton(
            key: const Key('account_email_submit'),
            label: context.tr(TranslationKeys.emailAuthSignUpButton),
            style: AccountButtonStyle.primary,
            busy: _busy,
            onPressed: _busy ? null : _submitEmail,
          ),
        ],
      ),
    );
  }
}

/// Looks of an [AccountButton].
enum AccountButtonStyle {
  /// White pill on dark, ink pill on light.
  primary,

  /// The reverse of [primary] with an outline (Apple's button).
  inverse,

  /// Transparent with an outline.
  outlined,
}

/// A 40px pill used by the sign-up surfaces.
class AccountButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AccountButtonStyle style;
  final VoidCallback? onPressed;
  final bool busy;

  const AccountButton({
    super.key,
    required this.label,
    required this.style,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final (Color bg, Color fg, Color? border) = switch (style) {
      AccountButtonStyle.primary => (palette.ctaFill, palette.ctaInk, null),
      AccountButtonStyle.inverse => palette.isDark
          ? (Colors.black, Colors.white, palette.outline)
          : (Colors.white, ReaderPalette.ink, ReaderPalette.ink),
      AccountButtonStyle.outlined => (
          Colors.transparent,
          palette.text,
          palette.outline
        ),
    };
    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          );
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: StadiumBorder(
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Note({super.key, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: palette.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
