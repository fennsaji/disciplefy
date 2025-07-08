import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// Home screen displaying daily verse, navigation options, and study recommendations.
/// 
/// Features app logo, verse of the day, main navigation, and predefined study topics
/// following the UX specifications and brand guidelines.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _currentUserName = 'John'; // TODO: Get from auth service
  final bool _hasResumeableStudy = true; // TODO: Check from storage/database
  
  // Sample verse of the day - TODO: Fetch from Bible API
  final VerseOfTheDay _verseOfTheDay = const VerseOfTheDay(
    reference: 'John 3:16',
    text: 'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
  );

  // Predefined study topics
  static const List<StudyTopic> _recommendedTopics = [
    StudyTopic(
      title: 'Faith',
      subtitle: 'Understanding trust in God',
      icon: Icons.favorite,
      color: Color(0xFF6A4FB6),
    ),
    StudyTopic(
      title: 'Prayer',
      subtitle: 'Communication with God',
      icon: Icons.favorite,
      color: Color(0xFF8B7FB8),
    ),
    StudyTopic(
      title: 'Baptism',
      subtitle: 'Spiritual rebirth and commitment',
      icon: Icons.water_drop,
      color: Color(0xFF6A4FB6),
    ),
    StudyTopic(
      title: 'Grace',
      subtitle: 'God\'s unmerited favor',
      icon: Icons.volunteer_activism,
      color: Color(0xFF8B7FB8),
    ),
    StudyTopic(
      title: 'Gospel',
      subtitle: 'The good news of Jesus Christ',
      icon: Icons.auto_awesome,
      color: Color(0xFF6A4FB6),
    ),
    StudyTopic(
      title: 'Faith in Trials',
      subtitle: 'Trusting God through difficulty',
      icon: Icons.shield,
      color: Color(0xFF8B7FB8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isLargeScreen ? 32 : 24),
                    
                    // App Header with Logo
                    _buildAppHeader(),
                    
                    SizedBox(height: isLargeScreen ? 32 : 24),
                    
                    // Welcome Message
                    _buildWelcomeMessage(),
                    
                    SizedBox(height: isLargeScreen ? 32 : 24),
                    
                    // Verse of the Day
                    _buildVerseOfTheDay(),
                    
                    SizedBox(height: isLargeScreen ? 40 : 32),
                    
                    // Generate Study Guide Button
                    _buildGenerateStudyButton(),
                    
                    SizedBox(height: isLargeScreen ? 32 : 24),
                    
                    // Resume Last Study (conditional)
                    if (_hasResumeableStudy) ...[
                      _buildResumeStudyBanner(),
                      SizedBox(height: isLargeScreen ? 32 : 24),
                    ],
                    
                    // Recommended Study Topics
                    _buildRecommendedTopics(),
                    
                    SizedBox(height: isLargeScreen ? 32 : 24),
                  ],
                ),
              ),
            ),
            
            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Row(
      children: [
        // App Logo
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // App Title
        Text(
          'Disciplefy',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        
        const Spacer(),
        
        // Settings Icon
        IconButton(
          onPressed: () {
            // TODO: Navigate to settings
          },
          icon: Icon(
            Icons.settings_outlined,
            color: AppTheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $_currentUserName',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Continue your spiritual journey with guided study',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppTheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildVerseOfTheDay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor.withOpacity(0.4),
            AppTheme.secondaryColor.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryColor.withOpacity(0.8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              
              const SizedBox(width: 8),
              
              Text(
                'Verse of the Day',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            '"${_verseOfTheDay.text}"',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            '- ${_verseOfTheDay.reference}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateStudyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go('/generate-study'),
        icon: const Icon(
          Icons.auto_awesome,
          size: 24,
        ),
        label: Text(
          'Generate Study Guide',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildResumeStudyBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bookmark,
            color: AppTheme.accentColor,
            size: 24,
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resume your last study',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  'Continue studying "Faith in Trials"',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          Icon(
            Icons.arrow_forward_ios,
            color: AppTheme.accentColor,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedTopics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Study Topics',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: _recommendedTopics.length,
          itemBuilder: (context, index) {
            final topic = _recommendedTopics[index];
            return _StudyTopicCard(
              topic: topic,
              onTap: () => _navigateToStudyGuide(topic.title),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.home,
            label: 'Home',
            isActive: true,
            onTap: () {},
          ),
          _BottomNavItem(
            icon: Icons.history,
            label: 'History',
            isActive: false,
            onTap: () {
              // TODO: Navigate to history
            },
          ),
          _BottomNavItem(
            icon: Icons.settings,
            label: 'Settings',
            isActive: false,
            onTap: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
    );
  }

  void _navigateToStudyGuide(String topic) {
    // TODO: Navigate to study guide with predefined topic
    context.go('/study-guide', extra: {'topic': topic, 'isPredefiend': true});
  }
}

/// Study topic card widget for recommended topics grid.
class _StudyTopicCard extends StatelessWidget {
  final StudyTopic topic;
  final VoidCallback onTap;

  const _StudyTopicCard({
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: topic.color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: topic.color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: topic.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                topic.icon,
                color: topic.color,
                size: 20,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              topic.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              topic.subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom navigation item widget.
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primaryColor : AppTheme.onSurfaceVariant;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          
          const SizedBox(height: 4),
          
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data model for verse of the day.
class VerseOfTheDay {
  final String reference;
  final String text;

  const VerseOfTheDay({
    required this.reference,
    required this.text,
  });
}

/// Data model for study topic.
class StudyTopic {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const StudyTopic({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}