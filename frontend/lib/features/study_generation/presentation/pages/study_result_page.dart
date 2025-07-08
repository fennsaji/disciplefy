import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/study_guide.dart';

/// Page for displaying generated Bible study guides.
/// 
/// This page presents the study guide content in a formatted, readable manner
/// following the Jeff Reed methodology structure.
class StudyResultPage extends StatelessWidget {
  /// The study guide to display.
  final StudyGuide? studyGuide;

  /// Creates a new StudyResultPage.
  /// 
  /// [studyGuide] The study guide to display.
  const StudyResultPage({super.key, this.studyGuide});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // If localization is not ready, show loading
    if (l10n == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyResultTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareStudyGuide(context),
            tooltip: l10n.studyResultShareButton,
          ),
        ],
      ),
      body: studyGuide == null
          ? _buildErrorState(context, l10n)
          : _buildStudyGuideContent(context, l10n),
    );
  }

  /// Builds the error state when no study guide is available.
  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.LARGE_PADDING),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              'No study guide available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.LARGE_PADDING),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home),
              label: Text(l10n.studyResultNewButton),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the main study guide content display.
  Widget _buildStudyGuideContent(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        // Study guide header
        _buildStudyGuideHeader(context),
        
        // Study guide content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
            children: [
              _buildSection(context, 'Summary', studyGuide!.summary),
              _buildSection(context, 'Context', studyGuide!.context),
              _buildListSection(context, 'Related Verses', studyGuide!.relatedVerses),
              _buildListSection(context, 'Reflection Questions', studyGuide!.reflectionQuestions),
              _buildListSection(context, 'Prayer Points', studyGuide!.prayerPoints),
              const SizedBox(height: AppConstants.LARGE_PADDING),
            ],
          ),
        ),
        
        // Action buttons
        _buildActionButtons(context, l10n),
      ],
    );
  }

  /// Builds the study guide header with title and metadata.
  Widget _buildStudyGuideHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              studyGuide!.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  '${studyGuide!.estimatedReadingTimeMinutes} min read',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: AppConstants.DEFAULT_PADDING),
                Icon(
                  Icons.language,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  studyGuide!.language.toUpperCase(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a text section with title and content.
  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.LARGE_PADDING),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.SMALL_PADDING),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a list section with title and bullet points.
  Widget _buildListSection(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.LARGE_PADDING),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.SMALL_PADDING),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.SMALL_PADDING),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the action buttons at the bottom.
  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareStudyGuide(context),
                icon: const Icon(Icons.share),
                label: Text(l10n.studyResultShareButton),
              ),
            ),
            const SizedBox(width: AppConstants.DEFAULT_PADDING),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.add),
                label: Text(l10n.studyResultNewButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shares the study guide content.
  void _shareStudyGuide(BuildContext context) {
    if (studyGuide != null) {
      final content = _formatStudyGuideForSharing(studyGuide!);
      Clipboard.setData(ClipboardData(text: content));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Study guide copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Formats the study guide for sharing as plain text.
  String _formatStudyGuideForSharing(StudyGuide guide) {
    final buffer = StringBuffer();
    buffer.writeln('📖 ${guide.title}');
    buffer.writeln('Generated by Disciplefy Bible Study App');
    buffer.writeln();
    
    buffer.writeln('📝 SUMMARY');
    buffer.writeln(guide.summary);
    buffer.writeln();
    
    buffer.writeln('📚 CONTEXT');
    buffer.writeln(guide.context);
    buffer.writeln();
    
    buffer.writeln('🔗 RELATED VERSES');
    for (final verse in guide.relatedVerses) {
      buffer.writeln('• $verse');
    }
    buffer.writeln();
    
    buffer.writeln('💭 REFLECTION QUESTIONS');
    for (int i = 0; i < guide.reflectionQuestions.length; i++) {
      buffer.writeln('${i + 1}. ${guide.reflectionQuestions[i]}');
    }
    buffer.writeln();
    
    buffer.writeln('🙏 PRAYER POINTS');
    for (final point in guide.prayerPoints) {
      buffer.writeln('• $point');
    }
    
    return buffer.toString();
  }
}