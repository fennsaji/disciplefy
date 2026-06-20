import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bible Copyright & Attribution')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Scripture text in Disciplefy is provided by API.Bible. Each '
              'translation is used under its respective copyright or licence, '
              'as shown below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            for (final a in _attributions) ...[
              _AttributionCard(attribution: a, onLicenseTap: _launch),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            // API.Bible attribution (required visible link on the Starter plan).
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Scripture provided by API.Bible'),
              subtitle: const Text(_apiBibleUrl),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _launch(_apiBibleUrl),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: const Text('VachanOnline'),
              subtitle: const Text(_vachanUrl),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _launch(_vachanUrl),
            ),
          ],
        ),
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

class _AttributionCard extends StatelessWidget {
  final _Attribution attribution;
  final Future<void> Function(String) onLicenseTap;

  const _AttributionCard(
      {required this.attribution, required this.onLicenseTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  attribution.language,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  attribution.abbreviation,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(attribution.notice, style: theme.textTheme.bodySmall),
          if (attribution.licenseUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => onLicenseTap(attribution.licenseUrl!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CC BY-SA 4.0',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new,
                      size: 14, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
