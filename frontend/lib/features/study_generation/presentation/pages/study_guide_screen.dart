import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/study_guide.dart';

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
  
  late StudyGuide _currentStudyGuide;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeStudyGuide();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeStudyGuide() {
    if (widget.studyGuide != null) {
      _currentStudyGuide = widget.studyGuide!;
    } else if (widget.routeExtra != null) {
      // Handle predefined topics or other route data
      final topic = widget.routeExtra!['topic'] as String?;
      if (topic != null) {
        _generateMockStudyGuide(topic);
      } else {
        _showError('No study guide data provided');
      }
    } else {
      _showError('No study guide data provided');
    }
  }

  void _generateMockStudyGuide(String topic) {
    // Mock study guide for demonstration - TODO: Replace with actual API call
    _currentStudyGuide = StudyGuide(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      input: topic,
      inputType: 'topic',
      summary: 'A comprehensive study on $topic',
      interpretation: 'This topic reveals God\'s character and His relationship with humanity. The original meaning emphasizes themes of faith, redemption, and spiritual growth. Understanding the context helps us apply these timeless truths to our modern lives, encouraging us to deepen our relationship with God and live according to His will.',
      context: 'Understanding the biblical foundation and historical context of $topic in Christian theology. This topic appears throughout Scripture and has been central to Christian teaching since the early church.',
      relatedVerses: [
        'John 3:16 - "For God so loved the world..."',
        'Romans 8:28 - "And we know that in all things..."',
        '1 Corinthians 13:4-7 - "Love is patient, love is kind..."',
      ],
      reflectionQuestions: [
        'How does this biblical principle apply to your daily life?',
        'What challenges do you face in living out this truth?',
        'How can you share this understanding with others?',
        'What practical steps can you take this week?',
      ],
      prayerPoints: [
        'Pray for deeper understanding of God\'s truth',
        'Ask for wisdom in application',
        'Seek strength to live out these principles',
        'Pray for opportunities to share with others',
      ],
      language: 'en',
      createdAt: DateTime.now(),
    );
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
          icon: Icon(
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
            icon: Icon(
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

  Widget _buildErrorScreen() {
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
  }

  Widget _buildStudyContent() {
    return Column(
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
  }

  Widget _buildNotesSection() {
    return Column(
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
              color: AppTheme.primaryColor.withOpacity(0.2),
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
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saveStudyGuide,
              icon: const Icon(Icons.bookmark_border),
              label: Text(
                'Save Study',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                  color: AppTheme.primaryColor,
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
  }

  String _getDisplayTitle() {
    if (_currentStudyGuide.inputType == 'scripture') {
      return _currentStudyGuide.input;
    } else {
      return _currentStudyGuide.input.substring(0, 1).toUpperCase() + 
             _currentStudyGuide.input.substring(1);
    }
  }

  void _saveStudyGuide() {
    // TODO: Implement save functionality with local storage or Supabase
    final notes = _notesController.text.trim();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Study guide saved successfully!',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // TODO: Save to database with notes
    debugPrint('Saving study guide: ${_currentStudyGuide.id} with notes: $notes');
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
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
                  color: AppTheme.primaryColor.withOpacity(0.1),
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
  }

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