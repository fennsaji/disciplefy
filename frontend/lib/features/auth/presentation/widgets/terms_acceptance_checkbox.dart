import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/legal_urls.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

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
  const LegalLinksLine({super.key, this.textColor, this.linkColor});

  /// Colour of the surrounding sentence. Defaults to the palette muted ink.
  final Color? textColor;

  /// Colour of the two links. Defaults to the palette accent, underlined;
  /// when set, links are drawn in this colour without an underline.
  final Color? linkColor;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final baseStyle = AppFonts.inter(
      fontSize: 12,
      color: textColor ?? palette.muted,
      height: 1.4,
    );
    final linkStyle = linkColor == null
        ? baseStyle.copyWith(
            color: palette.accentIcon,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          )
        : baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w500,
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
