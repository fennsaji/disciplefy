import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/legal_urls.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final linkStyle = AppFonts.inter(
      fontSize: 12,
      color: colorScheme.primary,
      fontWeight: FontWeight.w600,
    ).copyWith(decoration: TextDecoration.underline);
    final separatorStyle = AppFonts.inter(
      fontSize: 12,
      color: colorScheme.onSurface.withOpacity(0.5),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => _launch(termsUrl),
          child: Text(
            context.tr(TranslationKeys.subscriptionTermsOfUse),
            style: linkStyle,
          ),
        ),
        Text('    •    ', style: separatorStyle),
        InkWell(
          onTap: () => _launch(privacyUrl),
          child: Text(
            context.tr(TranslationKeys.subscriptionPrivacyPolicy),
            style: linkStyle,
          ),
        ),
      ],
    );
  }
}
