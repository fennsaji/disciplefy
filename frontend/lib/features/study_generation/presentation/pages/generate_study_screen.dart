import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/study_bloc.dart';

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
        _validationError = _isInputValid ? null : 'Please enter a valid scripture reference (e.g., John 3:16)';
      } else {
        _isInputValid = text.length >= 2;
        _validationError = _isInputValid ? null : 'Please enter at least 2 characters';
      }
    });
  }

  bool _validateScriptureReference(String text) {
    // Basic regex pattern for scripture references
    final scripturePattern = RegExp(r'^[1-3]?\s*[a-zA-Z]+\s+\d+(?::\d+(?:-\d+)?)?$');
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          'Generate Study Guide',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocListener<StudyBloc, StudyState>(
        listener: (context, state) {
          if (state is StudyGenerationSuccess) {
            // Navigate to study guide screen with generated content
            context.go('/study-guide', extra: state.studyGuide);
          } else if (state is StudyGenerationFailure) {
            // Show error message with retry option
            _showErrorDialog(context, state.failure.message, state.isRetryable);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isLargeScreen ? 32 : 24),
                
                // Mode Toggle
                _buildModeToggle(),
                
                SizedBox(height: isLargeScreen ? 32 : 24),
                
                // Input Section
                _buildInputSection(),
                
                SizedBox(height: isLargeScreen ? 24 : 16),
                
                // Suggestions
                _buildSuggestions(),
                
                const Spacer(),
                
                // Generate Button and Status
                BlocBuilder<StudyBloc, StudyState>(
                  builder: (context, state) {
                    return _buildGenerateButton(state);
                  },
                ),
                
                SizedBox(height: isLargeScreen ? 40 : 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What would you like to study?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
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
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedMode == StudyInputMode.scripture 
              ? 'Enter Scripture Reference'
              : 'Enter Topic',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        
        const SizedBox(height: 12),
        
        TextField(
          controller: _inputController,
          focusNode: _inputFocusNode,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: _selectedMode == StudyInputMode.scripture 
                ? 'e.g., John 3:16, Matthew 5:1-12'
                : 'e.g., Forgiveness, Love, Faith',
            hintStyle: GoogleFonts.inter(
              color: AppTheme.onSurfaceVariant,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.accentColor,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
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
                      color: AppTheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

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
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((suggestion) {
            return _SuggestionChip(
              label: suggestion,
              onTap: () {
                _inputController.text = suggestion;
                _inputFocusNode.unfocus();
              },
            );
          }).toList(),
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
              color: AppTheme.primaryColor.withOpacity(0.1),
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
                          AppTheme.primaryColor,
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
                          color: AppTheme.primaryColor,
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
                    color: AppTheme.onSurfaceVariant,
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
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.onSurfaceVariant,
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

  void _generateStudyGuide() {
    if (!_isInputValid) return;
    
    final input = _inputController.text.trim();
    final inputType = _selectedMode == StudyInputMode.scripture ? 'scripture' : 'topic';
    
    // Trigger BLoC event to generate study guide
    context.read<StudyBloc>().add(
      GenerateStudyGuideRequested(
        input: input,
        inputType: inputType,
        language: 'en', // TODO: Get from user preferences
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message, bool isRetryable) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Generation Failed',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
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
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'We couldn\'t generate a study guide right now. Please try again later.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            if (isRetryable) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _generateStudyGuide();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

/// Enum for study input mode.
enum StudyInputMode {
  scripture,
  topic,
}