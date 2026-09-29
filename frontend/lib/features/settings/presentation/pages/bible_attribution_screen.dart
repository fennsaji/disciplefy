import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';

/// Bible copyright & attribution page (API.Bible compliance).
///
/// API.Bible's terms require a copyright page that names each translation, its
/// copyright/licence and IP-holder link, and (on the Starter plan) a visible link
/// to https://api.bible. In-context citations elsewhere in the app link here.
class BibleAttributionScreen extends StatelessWidget {
  const BibleAttributionScreen({super.key});

  static const _apiBibleUrl = 'https://api.bible';
  static const _vachanUrl = 'https://vachanonline.com';
  static const _ccBySaUrl = 'https://creativecommons.org/licenses/by-sa/4.0/';

  // Notices are the verbatim `copyright` strings from API.Bible's /bibles metadata.
  static const List<_Attribution> _attributions = [
    _Attribution(
      language: 'English',
      abbreviation: 'KJV',
      name: 'King James (Authorised) Version',
      notice:
          'PUBLIC DOMAIN except in the United Kingdom, where a Crown Copyright '
          'applies to printing the KJV.',
      licenseUrl: null,
    ),
    _Attribution(
      language: 'हिन्दी (Hindi)',
      abbreviation: 'IRV',
      name: 'Indian Revised Version (IRV) Hindi — 2019',
      notice:
          'Indian Revised Version (IRV) - Hindi (इंडियन रिवाइज्ड वर्जन - हिंदी), '
          '2019 by Bridge Connectivity Solutions Pvt. Ltd. is licensed under a '
          'Creative Commons Attribution-ShareAlike 4.0 International License. '
          'This resource is published originally on VachanOnline.',
      licenseUrl: _ccBySaUrl,
    ),
    _Attribution(
      language: 'മലയാളം (Malayalam)',
      abbreviation: 'IRV',
      name: 'Indian Revised Version (IRV) Malayalam — 2025',
      notice:
          'Indian Revised Version (IRV) - Malayalam (ഇന്ത്യന്‍ റിവൈസ്ഡ് വേര്‍ഷന്‍ '
          '- മലയാളം), 2019 by Bridge Connectivity Solutions Pvt. Ltd. is licensed '
          'under a Creative Commons Attribution-ShareAlike 4.0 International '
          'License. This resource is published originally on VachanOnline.',
      licenseUrl: _ccBySaUrl,
    ),
  ];

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: SettingsTopBar(
        title: context.tr(TranslationKeys.settingsBibleAttribution),
        subtitle: 'Scripture provided by API.Bible',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Scripture text in Disciplefy is provided by API.Bible. Each '
              'translation is used under its respective copyright or licence, '
              'as shown below.',
              style: AppFonts.inter(
                fontSize: 13.5,
                color: palette.muted,
                height: 1.5,
              ),
            ),
          ),
          const SettingsSectionLabel('Bible text'),
          SettingsGroup(
            children: [
              for (final a in _attributions)
                _AttributionRow(attribution: a, onLicenseTap: _launch),
            ],
          ),
          const SettingsSectionLabel('Sources'),
          SettingsGroup(
            children: [
              // API.Bible attribution (required visible link on the Starter
              // plan).
              SettingsRow(
                icon: Icons.menu_book_outlined,
                title: 'Scripture provided by API.Bible',
                subtitle: _apiBibleUrl,
                trailing: Icon(Icons.open_in_new, size: 16, color: palette.dim),
                onTap: () => _launch(_apiBibleUrl),
              ),
              SettingsRow(
                icon: Icons.public,
                tone: SettingsTone.sky,
                title: 'VachanOnline',
                subtitle: _vachanUrl,
                trailing: Icon(Icons.open_in_new, size: 16, color: palette.dim),
                onTap: () => _launch(_vachanUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Attribution {
  final String language;
  final String abbreviation;
  final String name;
  final String notice;
  final String? licenseUrl;

  const _Attribution({
    required this.language,
    required this.abbreviation,
    required this.name,
    required this.notice,
    required this.licenseUrl,
  });
}

/// One translation: gold book tile, "Language · ABBR", its full name, the
/// verbatim copyright notice and, when licensed, the licence link.
class _AttributionRow extends StatelessWidget {
  final _Attribution attribution;
  final Future<void> Function(String) onLicenseTap;

  const _AttributionRow({
    required this.attribution,
    required this.onLicenseTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsIconTile(
            icon: Icons.book_outlined,
            tone: SettingsTone.gold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Native-script name as well, e.g. "हिन्दी (Hindi) · IRV".
                Text(
                  '${attribution.language} · ${attribution.abbreviation}',
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attribution.name,
                  style: AppFonts.inter(fontSize: 12, color: palette.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  attribution.notice,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: palette.muted,
                    height: 1.5,
                  ),
                ),
                if (attribution.licenseUrl != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => onLicenseTap(attribution.licenseUrl!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CC BY-SA 4.0',
                            style: AppFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: palette.accentIcon,
                              decoration: TextDecoration.underline,
                              decorationColor: palette.accentIcon,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new,
                              size: 14, color: palette.accentIcon),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
