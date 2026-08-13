import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/legal_urls.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';

/// Opens [url] in the platform browser, silently doing nothing if no handler
/// exists. Mirrors [SubscriptionLegalLinks]'s behaviour.
Future<void> _launchLegalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// The inline "…Terms of Use and Privacy Policy…" sentence with both
/// documents as tappable links.
///
/// Shared by [TermsAcceptanceCheckbox] (first-run gate) and [LegalLinksLine]
/// (returning users) so the link targets cannot diverge.
List<InlineSpan> _legalSpans(BuildContext context, TextStyle linkStyle) => [
      TextSpan(
        text: context.tr(TranslationKeys.loginTermsOfUse),
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchLegalUrl(LegalUrls.terms),
      ),
      TextSpan(text: context.tr(TranslationKeys.loginTermsAnd)),
      TextSpan(
        text: context.tr(TranslationKeys.loginPrivacyPolicyLink),
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchLegalUrl(LegalUrls.privacy),
      ),
    ];

/// Checkbox gating sign-in on explicit acceptance of the Terms of Use and
/// Privacy Policy.
///
/// Required by App Store Review Guideline 1.2, which mandates that the terms
/// be presented before a user registers or logs in. Stateless — the parent
/// owns the boolean.
class TermsAcceptanceCheckbox extends StatelessWidget {
  /// Whether the terms are currently accepted.
  final bool value;

  /// Called with the new value when the user taps the checkbox or label.
  final ValueChanged<bool> onChanged;

  const TermsAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = AppFonts.inter(
      fontSize: 13,
      color: theme.colorScheme.onSurface.withOpacity(0.8),
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    final sentence = context.tr(TranslationKeys.loginTermsAgree) +
        context.tr(TranslationKeys.loginTermsOfUse) +
        context.tr(TranslationKeys.loginTermsAnd) +
        context.tr(TranslationKeys.loginPrivacyPolicyLink) +
        context.tr(TranslationKeys.loginTermsSuffix);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No fixed SizedBox around the Checkbox: its default tap target is
        // already 48dp via MaterialTapTargetSize.padded, the framework
        // default. Clipping it to 24x24 (as before) shrank the touch area
        // below the accessible minimum.
        Semantics(
          label: sentence,
          checked: value,
          child: Checkbox(
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              // Tapping the sentence body (but not a link) also toggles,
              // which is the expected affordance for a checkbox label.
              onTap: () => onChanged(!value),
              child: Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(text: context.tr(TranslationKeys.loginTermsAgree)),
                    ..._legalSpans(context, linkStyle),
                    TextSpan(
                        text: context.tr(TranslationKeys.loginTermsSuffix)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Static "By continuing, you agree to our Terms of Use and Privacy Policy"
/// line with tappable links, shown to users who have already accepted.
///
/// The terms stay visible on every visit to the login screen; only the
/// blocking checkbox is first-run. Unlike [TermsAcceptanceCheckbox], this is
/// a passive notice — there is no checkbox here to back a first-person "I
/// agree" claim, so it uses the `terms_notice`/`terms_notice_suffix` keys
/// instead of `terms_agree`/`terms_suffix`.
class LegalLinksLine extends StatelessWidget {
  const LegalLinksLine({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = AppFonts.inter(
      fontSize: 12,
      color: theme.colorScheme.onSurface.withOpacity(0.6),
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: context.tr(TranslationKeys.loginTermsNotice)),
          ..._legalSpans(context, linkStyle),
          TextSpan(text: context.tr(TranslationKeys.loginTermsNoticeSuffix)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
