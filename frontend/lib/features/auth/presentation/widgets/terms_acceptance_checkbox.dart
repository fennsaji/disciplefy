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

/// "By continuing, you agree to our Terms of Use and Privacy Policy", with
/// both documents as tappable links.
///
/// Shown on the login screen above the sign-in buttons. Consent is implicit:
/// the terms are presented before any sign-in method is used (App Store
/// Guideline 1.2), and tapping a sign-in button records acceptance.
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
          TextSpan(text: context.tr(TranslationKeys.loginTermsNoticeSuffix)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
