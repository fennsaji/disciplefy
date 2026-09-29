import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/legal_urls.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Functional Terms of Use (EULA) and Privacy Policy links.
///
/// Required on every auto-renewable subscription purchase screen by App Store
/// Review Guideline 3.1.2(c). These MUST be tappable, working links — a plain
/// text mention is not sufficient and will be rejected.
class SubscriptionLegalLinks extends StatelessWidget {
  const SubscriptionLegalLinks({super.key});

  static const String termsUrl = LegalUrls.terms;
  static const String privacyUrl = LegalUrls.privacy;

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final linkStyle = AppFonts.inter(
      fontSize: 12,
      color: palette.accentIcon,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: palette.accentIcon,
    );
    final separatorStyle = AppFonts.inter(
      fontSize: 12,
      color: palette.dim,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => _launch(termsUrl),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.tr(TranslationKeys.subscriptionTermsOfUse),
              style: linkStyle,
            ),
          ),
        ),
        Text('    •    ', style: separatorStyle),
        InkWell(
          onTap: () => _launch(privacyUrl),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.tr(TranslationKeys.subscriptionPrivacyPolicy),
              style: linkStyle,
            ),
          ),
        ),
      ],
    );
  }
}
