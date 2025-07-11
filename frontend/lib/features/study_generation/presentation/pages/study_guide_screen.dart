import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import '../../domain/entities/study_guide.dart';
import '../../data/services/save_guide_api_service.dart';

/// Study Guide Screen displaying generated content with sections and user interactions.
/// 
/// Features scrollable content, note-taking, save/share functionality, and error handling
/// following the UX specifications and brand guidelines.
class StudyGuideScreen extends StatefulWidget {
  final StudyGuide? studyGuide;
  final Map<String, dynamic>? routeExtra;

  const StudyGuideScreen({
    super.key,
    this.studyGuide,
    this.routeExtra,
  });

  @override
  State<StudyGuideScreen> createState() => _StudyGuideScreenState();
}

class _StudyGuideScreenState extends State<StudyGuideScreen> {
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SaveGuideApiService _saveGuideService = SaveGuideApiService();
  
  late StudyGuide _currentStudyGuide;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isSaving = false;
  bool _isSaved = false;
  DateTime? _lastSaveAttempt;

  @override
  void initState() {
    super.initState();
    _initializeStudyGuide();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _scrollController.dispose();
    _saveGuideService.dispose();
    super.dispose();
  }

  void _initializeStudyGuide() {
    if (widget.studyGuide != null) {
      _currentStudyGuide = widget.studyGuide!;
    } else {
      _showError('No study guide data provided. Please generate a study guide first.');
    }
  }


  void _showError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    if (_hasError) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          _getDisplayTitle(),
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _shareStudyGuide,
            icon: const Icon(
              Icons.share_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isLargeScreen ? 24 : 16),
                  
                  // Study Guide Content
                  _buildStudyContent(),
                  
                  SizedBox(height: isLargeScreen ? 32 : 24),
                  
                  // Notes Section
                  _buildNotesSection(),
                  
                  SizedBox(height: isLargeScreen ? 32 : 24),
                ],
              ),
            ),
          ),
          
          // Bottom Action Buttons
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() => Scaffold(
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
          'Study Guide',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.accentColor,
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'We couldn\'t generate a study guide',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                _errorMessage.isEmpty 
                    ? 'Something went wrong. Please try again later.'
                    : _errorMessage,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
          ),
        ),
      ),
    );

  Widget _buildStudyContent() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Section
        _StudySection(
          title: 'Summary',
          icon: Icons.summarize,
          content: _currentStudyGuide.summary,
        ),
        
        const SizedBox(height: 24),
        
        // Interpretation Section
        _StudySection(
          title: 'Interpretation',
          icon: Icons.lightbulb_outline,
          content: _currentStudyGuide.interpretation,
        ),
        
        const SizedBox(height: 24),
        
        // Context Section
        _StudySection(
          title: 'Context',
          icon: Icons.history_edu,
          content: _currentStudyGuide.context,
        ),
        
        const SizedBox(height: 24),
        
        // Related Verses Section
        _StudySection(
          title: 'Related Verses',
          icon: Icons.menu_book,
          content: _currentStudyGuide.relatedVerses.join('\n\n'),
        ),
        
        const SizedBox(height: 24),
        
        // Discussion Questions Section
        _StudySection(
          title: 'Discussion Questions',
          icon: Icons.quiz,
          content: _currentStudyGuide.reflectionQuestions
              .asMap()
              .entries
              .map((entry) => '${entry.key + 1}. ${entry.value}')
              .join('\n\n'),
        ),
        
        const SizedBox(height: 24),
        
        // Prayer Points Section
        _StudySection(
          title: 'Prayer Points',
          icon: Icons.favorite,
          content: _currentStudyGuide.prayerPoints
              .asMap()
              .entries
              .map((entry) => '• ${entry.value}')
              .join('\n'),
        ),
      ],
    );

  Widget _buildNotesSection() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            
            const SizedBox(width: 8),
            
            Text(
              'Personal Notes',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 6,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Write your thoughts, insights, and reflections here...',
              hintStyle: GoogleFonts.inter(
                color: AppTheme.onSurfaceVariant,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );

  Widget _buildBottomActions() => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _isSaving
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                    label: Text(
                      'Saving...',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor.withValues(alpha: 0.6),
                      side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _saveStudyGuide,
                    icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(
                      _isSaved ? 'Saved' : 'Save Study',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isSaved ? AppTheme.successColor : AppTheme.primaryColor,
                      side: BorderSide(
                        color: _isSaved ? AppTheme.successColor : AppTheme.primaryColor,
                        width: 2,
                      ),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _shareStudyGuide,
              icon: const Icon(Icons.share),
              label: Text(
                'Share',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );

  String _getDisplayTitle() {
    if (_currentStudyGuide.inputType == 'scripture') {
      return _currentStudyGuide.input;
    } else {
      return _currentStudyGuide.input.substring(0, 1).toUpperCase() + 
             _currentStudyGuide.input.substring(1);
    }
  }

  /// Save the current study guide via API
  void _saveStudyGuide() async {
    // Debounce rapid taps - prevent multiple requests within 2 seconds
    final now = DateTime.now();
    if (_lastSaveAttempt != null && 
        now.difference(_lastSaveAttempt!).inSeconds < 2) {
      return;
    }
    _lastSaveAttempt = now;

    // Check if already saving
    if (_isSaving) return;

    // Check authentication - must be fully authenticated (not guest)
    final isFullyAuthenticated = await AuthService.isFullyAuthenticated();
    if (!isFullyAuthenticated) {
      _showAuthenticationRequiredDialog();
      return;
    }

    // Already saved check
    if (_isSaved) {
      _showSnackBar(
        'Study guide is already saved!',
        AppTheme.primaryColor,
        icon: Icons.bookmark,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Call the API to save the guide
      final success = await _saveGuideService.toggleSaveGuide(
        guideId: _currentStudyGuide.id,
        save: true,
      );

      if (success) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });

        _showSnackBar(
          'Study guide saved successfully!',
          AppTheme.successColor,
          icon: Icons.check_circle,
        );

        // TODO: Save notes locally if needed
        final notes = _notesController.text.trim();
        if (notes.isNotEmpty) {
          debugPrint('Notes to save locally: $notes');
        }
      } else {
        throw Exception('Save operation returned false');
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      _handleSaveError(e);
    }
  }

  /// Show authentication required dialog
  void _showAuthenticationRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Authentication Required',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'You need to be signed in to save study guides. Would you like to sign in now?',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle save operation errors
  void _handleSaveError(dynamic error) {
    String message = 'Failed to save study guide. Please try again.';
    Color backgroundColor = AppTheme.errorColor;

    if (error.toString().contains('UNAUTHORIZED')) {
      message = 'Authentication expired. Please sign in again.';
    } else if (error.toString().contains('NETWORK_ERROR')) {
      message = 'Network error. Please check your connection.';
    } else if (error.toString().contains('NOT_FOUND')) {
      message = 'Study guide not found. It may have been deleted.';
    } else if (error.toString().contains('already saved')) {
      message = 'This study guide is already saved!';
      backgroundColor = AppTheme.primaryColor;
      setState(() {
        _isSaved = true;
      });
    }

    _showSnackBar(message, backgroundColor, icon: Icons.error_outline);
  }

  /// Show snackbar with consistent styling
  void _showSnackBar(String message, Color backgroundColor, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _shareStudyGuide() {
    final shareText = '''
${_getDisplayTitle()}

Summary:
${_currentStudyGuide.summary}

Interpretation:
${_currentStudyGuide.interpretation}

Context:
${_currentStudyGuide.context}

Related Verses:
${_currentStudyGuide.relatedVerses.join('\n')}

Discussion Questions:
${_currentStudyGuide.reflectionQuestions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Prayer Points:
${_currentStudyGuide.prayerPoints.map((p) => '• $p').join('\n')}

Generated by Disciplefy - Bible Study App
''';

    Share.share(
      shareText,
      subject: 'Bible Study: ${_getDisplayTitle()}',
    );
  }
}

/// Study section widget for displaying content with consistent styling.
class _StudySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _StudySection({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              
              // Copy button
              IconButton(
                onPressed: () => _copyToClipboard(context, content),
                icon: Icon(
                  Icons.copy,
                  color: AppTheme.onSurfaceVariant,
                  size: 18,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Section Content
          SelectableText(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied to clipboard',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}