import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class VerseInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;

  const VerseInputWidget({
    super.key,
    required this.controller,
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
            l10n.studyInputVerseTab,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a detailed study guide for any Bible verse or passage.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          
          TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit?.call(),
            decoration: InputDecoration(
              labelText: l10n.studyInputVerseHint,
              hintText: 'John 3:16, Psalm 23:1-3, Romans 8:28',
              errorText: error,
              prefixIcon: const Icon(Icons.book),
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
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Supported Formats',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
}