import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/services/study_navigation_service.dart';
import '../bloc/study_bloc.dart';
import '../bloc/study_event.dart';
import '../bloc/study_state.dart';
import '../widgets/recent_guides_section.dart';

/// Generate Study Screen allowing users to input scripture reference or topic.
///
/// Features toggle between modes, input validation, suggestions, and loading states
/// following the UX specifications and brand guidelines.
class GenerateStudyScreen extends StatefulWidget {
  const GenerateStudyScreen({super.key});

  @override
  State<GenerateStudyScreen> createState() => _GenerateStudyScreenState();
}

class _GenerateStudyScreenState extends State<GenerateStudyScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  StudyInputMode _selectedMode = StudyInputMode.scripture;
  StudyLanguage _selectedLanguage = StudyLanguage.english;
  bool _isInputValid = false;
  String? _validationError;

  // Scripture reference suggestions
  final List<String> _scriptureeSuggestions = [
    'John 3:16',
    'Psalm 23:1',
    'Romans 8:28',
    'Matthew 5:16',
    'Philippians 4:13',
    '1 Corinthians 13:4-7',
    'Isaiah 40:31',
    'Jeremiah 29:11',
    'Proverbs 3:5-6',
    'Ephesians 2:8-9',
  ];

  // Topic suggestions
  final List<String> _topicSuggestions = [
    'Forgiveness',
    'Love',
    'Faith',
    'Hope',
    'Prayer',
    'Salvation',
    'Grace',
    'Peace',
    'Wisdom',
    'Trust',
    'Courage',
    'Patience',
    'Joy',
    'Mercy',
    'Redemption',
  ];

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _validateInput() {
    final text = _inputController.text.trim();
    setState(() {
      if (text.isEmpty) {
        _isInputValid = false;
        _validationError = null;
      } else if (_selectedMode == StudyInputMode.scripture) {
        _isInputValid = _validateScriptureReference(text);
        _validationError = _isInputValid
            ? null
            : 'Please enter a valid scripture reference (e.g., John 3:16)';
      } else {
        _isInputValid = text.length >= 2;
        _validationError =
            _isInputValid ? null : 'Please enter at least 2 characters';
      }
    });
  }

  bool _validateScriptureReference(String text) {
    // Basic regex pattern for scripture references
    final scripturePattern =
        RegExp(r'^[1-3]?\s*[a-zA-Z]+\s+\d+(?::\d+(?:-\d+)?)?$');
    return scripturePattern.hasMatch(text);
  }

  List<String> _getFilteredSuggestions() {
    final suggestions = _selectedMode == StudyInputMode.scripture
        ? _scriptureeSuggestions
        : _topicSuggestions;

    final query = _inputController.text.trim().toLowerCase();
    if (query.isEmpty) return suggestions.take(5).toList();

    return suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Generate Study Guide',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.push('/saved'),
            icon: Icon(
              Icons.bookmark_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'View Saved Guides',
          ),
        ],
      ),
      body: BlocListener<StudyBloc, StudyState>(
        listener: (context, state) {
          if (state is StudyGenerationSuccess) {
            // Navigate to study guide screen with generated content
            StudyNavigationService.navigateToStudyGuide(
              context,
              studyGuide: state.studyGuide,
              source: StudyNavigationSource.generate,
            );
          } else if (state is StudyGenerationFailure) {
            // Show error message with retry option
            _showErrorDialog(context, state.failure.message, state.isRetryable);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isLargeScreen ? 32 : 24),

                  // Mode Toggle
                  _buildModeToggle(),

                  SizedBox(height: isLargeScreen ? 24 : 16),

                  // Language Selection
                  _buildLanguageSelection(),

                  SizedBox(height: isLargeScreen ? 32 : 24),

                  // Input Section
                  _buildInputSection(),

                  SizedBox(height: isLargeScreen ? 24 : 16),

                  // Suggestions
                  _buildSuggestions(),

                  SizedBox(height: isLargeScreen ? 32 : 24),

                  // Generate Button and Status
                  BlocBuilder<StudyBloc, StudyState>(
                    builder: (context, state) => _buildGenerateButton(state),
                  ),

                  // Recent Guides Section (Bottom section as per Option 2)
                  const RecentGuidesSection(),

                  SizedBox(height: isLargeScreen ? 40 : 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What would you like to study?',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeToggleButton(
                    label: 'Scripture Reference',
                    isSelected: _selectedMode == StudyInputMode.scripture,
                    onTap: () => _switchMode(StudyInputMode.scripture),
                  ),
                ),
                Expanded(
                  child: _ModeToggleButton(
                    label: 'Topic',
                    isSelected: _selectedMode == StudyInputMode.topic,
                    onTap: () => _switchMode(StudyInputMode.topic),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildLanguageSelection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Language',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LanguageToggleButton(
                    flag: '🇺🇸',
                    label: 'English',
                    isSelected: _selectedLanguage == StudyLanguage.english,
                    onTap: () => _switchLanguage(StudyLanguage.english),
                  ),
                ),
                Expanded(
                  child: _LanguageToggleButton(
                    flag: '🇮🇳',
                    label: 'हिन्दी',
                    isSelected: _selectedLanguage == StudyLanguage.hindi,
                    onTap: () => _switchLanguage(StudyLanguage.hindi),
                  ),
                ),
                Expanded(
                  child: _LanguageToggleButton(
                    flag: '🇮🇳',
                    label: 'മലയാളം',
                    isSelected: _selectedLanguage == StudyLanguage.malayalam,
                    onTap: () => _switchLanguage(StudyLanguage.malayalam),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildInputSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedMode == StudyInputMode.scripture
                ? 'Enter Scripture Reference'
                : 'Enter Topic',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            decoration: InputDecoration(
              hintText: _selectedMode == StudyInputMode.scripture
                  ? 'e.g., John 3:16, Matthew 5:1-12'
                  : 'e.g., Forgiveness, Love, Faith',
              hintStyle: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 2,
                ),
              ),
              errorText: _validationError,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: _inputController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _inputController.clear();
                        _inputFocusNode.requestFocus();
                      },
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      );

  Widget _buildSuggestions() {
    final suggestions = _getFilteredSuggestions();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggestions',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map((suggestion) => _SuggestionChip(
                    label: suggestion,
                    onTap: () {
                      _inputController.text = suggestion;
                      _inputFocusNode.unfocus();
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGenerateButton(StudyState state) {
    final isLoading = state is StudyGenerationInProgress;

    return Column(
      children: [
        if (isLoading) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Generating your study guide...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a few moments.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isInputValid && !isLoading ? _generateStudyGuide : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              isLoading ? 'Generating...' : 'Generate Study Guide',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _switchMode(StudyInputMode mode) {
    setState(() {
      _selectedMode = mode;
      _inputController.clear();
      _validationError = null;
      _isInputValid = false;
    });
    _inputFocusNode.requestFocus();
  }

  void _switchLanguage(StudyLanguage language) {
    setState(() {
      _selectedLanguage = language;
    });
  }

  void _generateStudyGuide() {
    if (!_isInputValid) return;

    final input = _inputController.text.trim();
    final inputType =
        _selectedMode == StudyInputMode.scripture ? 'scripture' : 'topic';
    final languageCode = _selectedLanguage.code;

    // Trigger BLoC event to generate study guide
    context.read<StudyBloc>().add(
          GenerateStudyGuideRequested(
            input: input,
            inputType: inputType,
            language: languageCode,
          ),
        );
  }

  void _showErrorDialog(
      BuildContext context, String message, bool isRetryable) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFA), // Light background
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFDC2626), // Red error color
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Generation Failed',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333), // Primary gray text
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF333333), // Primary gray text
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5), // Light gray background
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'We couldn\'t generate a study guide right now. Please try again later.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF666666), // Secondary gray text
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF888888), // Light gray for cancel
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888888), // Light gray text
              ),
            ),
          ),
          if (isRetryable) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _generateStudyGuide();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A56DB), // Primary purple
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mode toggle button widget.
class _ModeToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

/// Language toggle button widget.
class _LanguageToggleButton extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageToggleButton({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
}

/// Suggestion chip widget.
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
}

/// Enum for study input mode.
enum StudyInputMode {
  scripture,
  topic,
}

/// Enum for study language selection.
enum StudyLanguage {
  english('en'),
  hindi('hi'),
  malayalam('ml');

  const StudyLanguage(this.code);
  final String code;
}
