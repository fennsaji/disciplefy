import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class TopicInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;

  const TopicInputWidget({
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
            l10n.studyInputTopicTab,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a comprehensive study guide on any biblical topic or theme.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          
          TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit?.call(),
            decoration: InputDecoration(
              labelText: l10n.studyInputTopicHint,
              hintText: 'faith, love, prayer, forgiveness',
              errorText: error,
              prefixIcon: const Icon(Icons.topic),
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
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Popular Topics',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      'Faith', 'Love', 'Prayer', 'Forgiveness',
                      'Hope', 'Wisdom', 'Grace', 'Peace'
                    ].map((topic) => 
                      ActionChip(
                        label: Text(topic),
                        onPressed: () {
                          controller.text = topic.toLowerCase();
                          onChanged?.call(topic.toLowerCase());
                        },
                      )
                    ).toList(),
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