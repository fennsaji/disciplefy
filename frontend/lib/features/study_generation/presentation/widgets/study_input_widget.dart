import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

/// Unified input widget for both verse and topic study generation.
///
/// This widget can be configured to work for both scripture input
/// and topic input modes by passing different configuration values.
class StudyInputWidget extends StatelessWidget {
  /// The text controller for the input field.
  final TextEditingController controller;

  /// Error message to display below the input field.
  final String? error;

  /// Callback when the input text changes.
  final ValueChanged<String>? onChanged;

  /// Callback when the submit button is pressed.
  final VoidCallback? onSubmit;

  /// The input mode ('verse' or 'topic').
  final StudyInputMode mode;

  const StudyInputWidget({
    super.key,
    required this.controller,
    required this.mode,
    this.error,
    this.onChanged,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // If localization is not ready, show loading
    if (l10n == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _getTitle(l10n),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _getDescription(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: mode == StudyInputMode.verse
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit?.call(),
            decoration: InputDecoration(
              labelText: _getInputLabel(l10n),
              hintText: _getInputHint(),
              errorText: error,
              prefixIcon: Icon(_getInputIcon()),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getHelpIcon(),
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getHelpTitle(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHelpContent(context),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.auto_awesome),
            label: Text(l10n.studyInputGenerateButton),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle(AppLocalizations l10n) =>
      mode == StudyInputMode.verse ? l10n.studyInputVerseTab : l10n.studyInputTopicTab;

  String _getDescription() => mode == StudyInputMode.verse
      ? 'Generate a detailed study guide for any Bible verse or passage.'
      : 'Generate a comprehensive study guide on any biblical topic or theme.';

  String _getInputLabel(AppLocalizations l10n) =>
      mode == StudyInputMode.verse ? l10n.studyInputVerseHint : l10n.studyInputTopicHint;

  String _getInputHint() =>
      mode == StudyInputMode.verse ? 'John 3:16, Psalm 23:1-3, Romans 8:28' : 'faith, love, prayer, forgiveness';

  IconData _getInputIcon() => mode == StudyInputMode.verse ? Icons.book : Icons.topic;

  IconData _getHelpIcon() => mode == StudyInputMode.verse ? Icons.info_outline : Icons.lightbulb_outline;

  String _getHelpTitle() => mode == StudyInputMode.verse ? 'Supported Formats' : 'Popular Topics';

  Widget _buildHelpContent(BuildContext context) {
    if (mode == StudyInputMode.verse) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• Single verse: John 3:16',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '• Verse range: John 3:16-17',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '• Chapter range: John 3:16-4:2',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '• Full chapter: Psalm 23',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: ['Faith', 'Love', 'Prayer', 'Forgiveness', 'Hope', 'Wisdom', 'Grace', 'Peace']
            .map((topic) => ActionChip(
                  label: Text(topic),
                  onPressed: () {
                    controller.text = topic.toLowerCase();
                    onChanged?.call(topic.toLowerCase());
                  },
                ))
            .toList(),
      );
    }
  }
}

/// Enum representing the different input modes for study generation.
enum StudyInputMode {
  /// Mode for entering Bible verses and passages.
  verse,

  /// Mode for entering biblical topics and themes.
  topic,
}
