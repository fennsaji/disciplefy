import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../memory_verses/domain/usecases/fetch_verse_text.dart';
import '../../../memory_verses/domain/usecases/add_verse_manually.dart';

/// A bottom sheet widget for displaying scripture verse text.
///
/// Shows the verse text when a scripture reference chip is tapped,
/// with options to copy the text.
class ScriptureVerseSheet extends StatefulWidget {
  /// The scripture reference (e.g., "John 3:16", "Matthew 5:1-12")
  final String reference;

  const ScriptureVerseSheet({
    super.key,
    required this.reference,
  });

  /// Shows the scripture verse bottom sheet.
  ///
  /// [context] - The build context to show the sheet in.
  /// [reference] - The scripture reference string to fetch and display.
  static void show(BuildContext context, {required String reference}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScriptureVerseSheet(reference: reference),
    );
  }

  @override
  State<ScriptureVerseSheet> createState() => _ScriptureVerseSheetState();
}

class _ScriptureVerseSheetState extends State<ScriptureVerseSheet> {
  bool _isLoading = true;
  String? _verseText;
  String? _localizedReference;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVerseText();
  }

  Future<void> _fetchVerseText() async {
    final fetchVerseText = GetIt.instance<FetchVerseText>();
    final languageService = GetIt.instance<LanguagePreferenceService>();

    // Parse the reference
    final parsed = _parseReference(widget.reference);
    if (parsed == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not parse reference: ${widget.reference}';
      });
      return;
    }

    // Get current language
    final appLanguage = await languageService.getSelectedLanguage();
    final langCode = appLanguage.code;

    // Fetch the verse text
    final result = await fetchVerseText(
      book: parsed.book,
      chapter: parsed.chapter,
      verseStart: parsed.verseStart,
      verseEnd: parsed.verseEnd,
      language: langCode,
    );

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load verse text';
        });
      },
      (fetchedVerse) {
        setState(() {
          _isLoading = false;
          _verseText = fetchedVerse.text;
          _localizedReference = fetchedVerse.localizedReference;
        });
      },
    );
  }

  /// Parses a scripture reference string into components.
  ///
  /// Supports formats:
  /// - "John 3:16" -> book: John, chapter: 3, verse: 16
  /// - "1 John 3:16" -> book: 1 John, chapter: 3, verse: 16
  /// - "Matthew 5:1-12" -> book: Matthew, chapter: 5, verseStart: 1, verseEnd: 12
  _ParsedReference? _parseReference(String reference) {
    // Pattern: captures book name (may start with number), chapter, verse(s)
    // Examples: "John 3:16", "1 John 3:16", "Matthew 5:1-12"
    final regex = RegExp(r'^(\d?\s?[A-Za-z]+)\s+(\d+):(\d+)(?:-(\d+))?$');
    final match = regex.firstMatch(reference.trim());

    if (match == null) {
      // Try simpler pattern without verse range
      final simpleRegex = RegExp(r'^(\d?\s?[A-Za-z]+)\s+(\d+):(\d+)$');
      final simpleMatch = simpleRegex.firstMatch(reference.trim());
      if (simpleMatch == null) return null;

      return _ParsedReference(
        book: simpleMatch.group(1)!.trim(),
        chapter: int.parse(simpleMatch.group(2)!),
        verseStart: int.parse(simpleMatch.group(3)!),
      );
    }

    return _ParsedReference(
      book: match.group(1)!.trim(),
      chapter: int.parse(match.group(2)!),
      verseStart: int.parse(match.group(3)!),
      verseEnd: match.group(4) != null ? int.parse(match.group(4)!) : null,
    );
  }

  void _copyToClipboard() {
    if (_verseText != null && _localizedReference != null) {
      final textToCopy = '"$_verseText" - $_localizedReference';
      Clipboard.setData(ClipboardData(text: textToCopy));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verse copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Reference header
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _localizedReference ?? widget.reference,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content area
              if (_isLoading)
                _buildLoadingState(theme)
              else if (_errorMessage != null)
                _buildErrorState(theme)
              else
                _buildVerseContent(theme),

              const SizedBox(height: 20),

              // Action buttons (only show when verse is loaded)
              if (!_isLoading && _verseText != null) _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading verse...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'An error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseContent(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withOpacity(0.3)
              : theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opening quote mark
          Text(
            '"',
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.primary.withOpacity(isDark ? 0.6 : 0.3),
              fontWeight: FontWeight.bold,
              height: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // Verse text
          Text(
            _verseText ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.7,
              fontSize: 17,
              letterSpacing: 0.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _generateStudyGuide() async {
    final languageService = GetIt.instance<LanguagePreferenceService>();
    final appLanguage = await languageService.getSelectedLanguage();

    if (mounted) {
      Navigator.pop(context);
      final topic = _localizedReference ?? widget.reference;
      context.push(
        '${AppRoutes.studyGuideV2}?input=${Uri.encodeComponent(topic)}&type=topic&language=${appLanguage.code}',
      );
    }
  }

  Future<void> _addToMemoryVerses() async {
    if (_verseText == null) return;

    final addVerseManually = GetIt.instance<AddVerseManually>();
    final languageService = GetIt.instance<LanguagePreferenceService>();
    final appLanguage = await languageService.getSelectedLanguage();

    final result = await addVerseManually(
      verseReference: _localizedReference ?? widget.reference,
      verseText: _verseText!,
      language: appLanguage.code,
    );

    if (mounted) {
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add verse: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        (_) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to Memory Verses'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Study button
        _ActionButton(
          icon: Icons.auto_stories_rounded,
          label: 'Study',
          onTap: _generateStudyGuide,
          theme: theme,
        ),
        const SizedBox(width: 24),
        // Memory button
        _ActionButton(
          icon: Icons.bookmark_add_rounded,
          label: 'Memory',
          onTap: _addToMemoryVerses,
          theme: theme,
        ),
        const SizedBox(width: 24),
        // Copy button
        _ActionButton(
          icon: Icons.copy_rounded,
          label: 'Copy',
          onTap: _copyToClipboard,
          theme: theme,
        ),
      ],
    );
  }
}

/// Internal class to hold parsed reference components.
class _ParsedReference {
  final String book;
  final int chapter;
  final int verseStart;
  final int? verseEnd;

  _ParsedReference({
    required this.book,
    required this.chapter,
    required this.verseStart,
    this.verseEnd,
  });
}

/// Action button widget with icon and label.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
