import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/services/recommended_guides_service.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_event.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../daily_verse/presentation/widgets/daily_verse_card.dart';
import '../../../study_generation/domain/usecases/generate_study_guide.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;

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
  // Services
  late final RecommendedGuidesService _topicsService;
  
  // State variables
  final bool _hasResumeableStudy = false;
  bool _isLoadingTopics = true;
  String? _topicsError;
  List<RecommendedGuideTopic> _recommendedTopics = [];

  @override
  void initState() {
    super.initState();
    _topicsService = RecommendedGuidesService();
    _initializeScreen();
  }

  @override
  void dispose() {
    _topicsService.dispose();
    super.dispose();
  }

  /// Initializes the screen by loading topics and daily verse
  Future<void> _initializeScreen() async {
    await _loadRecommendedTopics();
    // Load daily verse only once on screen initialization
    _loadDailyVerse();
  }
  
  /// Load daily verse - called only once during initialization
  void _loadDailyVerse() {
    // Auto-load daily verse on home screen initialization
    // BLoC will handle caching and avoid redundant calls
    final bloc = sl<DailyVerseBloc>();
    // Always trigger load - the BLoC will handle daily caching logic
    bloc.add(const LoadTodaysVerse());
  }

  /// Loads recommended topics from the API
  Future<void> _loadRecommendedTopics() async {
    setState(() {
      _isLoadingTopics = true;
      _topicsError = null;
    });

    final result = await _topicsService.getFilteredTopics(limit: 6);
    
    result.fold(
      (failure) {
        setState(() {
          _isLoadingTopics = false;
          _topicsError = failure.message;
        });
        print('❌ [HOME] Failed to load topics: ${failure.message}');
      },
      (topics) {
        setState(() {
          _isLoadingTopics = false;
          _recommendedTopics = topics;
        });
        print('✅ [HOME] Loaded ${topics.length} topics');
      },
    );
  }

  /// Handle daily verse card tap to generate study guide
  void _onDailyVerseCardTap() {
    // Get the current DailyVerseBloc state
    final dailyVerseBloc = context.read<DailyVerseBloc>();
    final currentState = dailyVerseBloc.state;

    if (currentState is DailyVerseLoaded) {
      // Generate study guide with verse reference
      _generateStudyGuideFromVerse(currentState.verse.reference);
    } else if (currentState is DailyVerseOffline) {
      // Generate study guide with cached verse reference
      _generateStudyGuideFromVerse(currentState.verse.reference);
    } else {
      // Show error if verse is not loaded
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily verse is not yet loaded. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Generate study guide from verse reference
  Future<void> _generateStudyGuideFromVerse(String verseReference) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Generating study guide for "$verseReference"...'),
              ],
            ),
            duration: const Duration(minutes: 1), // Long duration since generation can take time
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      // Generate study guide using the study generation service
      final generateStudyGuide = sl<GenerateStudyGuide>();
      final result = await generateStudyGuide(StudyGenerationParams(
        input: verseReference,
        inputType: 'scripture',
        language: 'en', // TODO: Get from user preferences
      ));

      if (mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        result.fold(
          (failure) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to generate study guide: ${failure.message}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _generateStudyGuideFromVerse(verseReference),
                ),
              ),
            );
          },
          (studyGuide) {
            // Navigate directly to study guide screen with generated content
            context.go('/study-guide', extra: studyGuide);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating study guide: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, authState) {
        // Extract user information from AuthBloc state
        String currentUserName = 'Guest';
        
        if (authState is auth_states.AuthenticatedState) {
          if (authState.isAnonymous) {
            currentUserName = 'Guest';
          } else {
            // Extract user name from Google account
            final user = authState.user;
            currentUserName = user.userMetadata?['full_name'] ?? 
                             user.userMetadata?['name'] ?? 
                             user.email?.split('@').first ?? 
                             'User';
          }
          print('👤 [HOME] User loaded: $currentUserName (authenticated: ${!authState.isAnonymous})');
        }

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
                        _buildWelcomeMessage(currentUserName),
                        
                        SizedBox(height: isLargeScreen ? 32 : 24),
                        
                        // Daily Verse Card with click functionality
                        DailyVerseCard(
                          margin: EdgeInsets.zero,
                          onTap: _onDailyVerseCardTap,
                        ),
                        
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppHeader() => Row(
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
            context.go('/settings');
          },
          icon: const Icon(
            Icons.settings_outlined,
            color: AppTheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ],
    );

  Widget _buildWelcomeMessage(String userName) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $userName',
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

  Widget _buildGenerateStudyButton() => SizedBox(
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

  Widget _buildResumeStudyBanner() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
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
          
          const Icon(
            Icons.arrow_forward_ios,
            color: AppTheme.accentColor,
            size: 16,
          ),
        ],
      ),
    );

  Widget _buildRecommendedTopics() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended Study Topics',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (_isLoadingTopics)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (_topicsError != null)
          _buildTopicsErrorWidget()
        else if (_isLoadingTopics)
          _buildTopicsLoadingWidget()
        else if (_recommendedTopics.isEmpty)
          _buildNoTopicsWidget()
        else
          _buildTopicsGrid(),
      ],
    );

  Widget _buildTopicsErrorWidget() => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.accentColor,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load topics',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _topicsError!,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRecommendedTopics,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

  Widget _buildTopicsLoadingWidget() => LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 16.0;
        final double cardWidth = (constraints.maxWidth - spacing) / 2;
        
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(6, (index) => SizedBox(
              width: cardWidth,
              child: _buildLoadingTopicCard(),
            )),
        );
      },
    );

  Widget _buildLoadingTopicCard() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Match the real card
        children: [
          // Header row skeleton
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 20,
                width: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Title skeleton
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Description skeleton
          Container(
            height: 11,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          
          const SizedBox(height: 4),
          
          Container(
            height: 11,
            width: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Footer skeleton
          Row(
            children: [
              Container(
                height: 10,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 10,
                width: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );

  Widget _buildNoTopicsWidget() => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.topic_outlined,
            color: AppTheme.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'No topics available',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

  Widget _buildTopicsGrid() {
    // Use a different approach: Wrap or ListView instead of fixed-height GridView
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal card width (accounting for spacing)
        const double spacing = 16.0;
        final double cardWidth = (constraints.maxWidth - spacing) / 2;
        
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _recommendedTopics.map((topic) => SizedBox(
              width: cardWidth,
              child: _RecommendedGuideTopicCard(
                topic: topic,
                onTap: () => _navigateToStudyGuide(topic),
              ),
            )).toList(),
        );
      },
    );
  }

  void _navigateToStudyGuide(RecommendedGuideTopic topic) {
    // Generate study guide directly and navigate to study guide screen
    _generateAndNavigateToStudyGuide(topic);
  }

  /// Generates a study guide for the given topic and navigates directly to the study guide screen
  Future<void> _generateAndNavigateToStudyGuide(RecommendedGuideTopic topic) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Generating study guide for "${topic.title}"...'),
              ],
            ),
            duration: const Duration(minutes: 1), // Long duration since generation can take time
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      // Generate study guide using the study generation service
      final generateStudyGuide = sl<GenerateStudyGuide>();
      final result = await generateStudyGuide(StudyGenerationParams(
        input: topic.title,
        inputType: 'topic',
        language: 'en', // TODO: Get from user preferences
      ));

      if (mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        result.fold(
          (failure) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to generate study guide: ${failure.message}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _generateAndNavigateToStudyGuide(topic),
                ),
              ),
            );
          },
          (studyGuide) {
            // Navigate directly to study guide screen with generated content
            context.go('/study-guide', extra: studyGuide);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating study guide: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Recommended guide topic card widget for API-based topics.
class _RecommendedGuideTopicCard extends StatelessWidget {
  final RecommendedGuideTopic topic;
  final VoidCallback onTap;

  const _RecommendedGuideTopicCard({
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconForCategory(topic.category);
    final color = _getColorForDifficulty(topic.difficulty);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important: Don't expand unnecessarily
          children: [
            // Header row with icon and difficulty badge
            Row(
              children: [
                Container(
                  width: 36, // Slightly smaller for better proportions
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    iconData,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8), // Fixed spacing instead of Spacer
                Flexible( // Use Flexible instead of Spacer
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      topic.difficulty.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Title with proper constraints
            Text(
              topic.title,
              style: GoogleFonts.inter(
                fontSize: 14, // Slightly smaller for better fit
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.2, // Tighter line height
              ),
              maxLines: 2, // Allow 2 lines for longer titles
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 6), // Reduced spacing
            
            // Description with flexible height
            Flexible(
              child: Text(
                topic.description,
                style: GoogleFonts.inter(
                  fontSize: 11, // Smaller font for more content
                  color: AppTheme.onSurfaceVariant,
                  height: 1.3,
                ),
                maxLines: 3, // Allow up to 3 lines
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(height: 12), // Fixed spacing instead of Spacer
            
            // Footer with metadata - use Wrap for overflow protection
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${topic.estimatedMinutes}min',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.book_outlined,
                      size: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${topic.scriptureCount}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'faith foundations':
        return Icons.foundation;
      case 'spiritual disciplines':
        return Icons.self_improvement;
      case 'salvation':
        return Icons.favorite;
      case 'christian living':
        return Icons.directions_walk;
      case 'character of god':
        return Icons.auto_awesome;
      case 'relationships':
        return Icons.people;
      case 'spiritual growth':
        return Icons.trending_up;
      default:
        return Icons.menu_book;
    }
  }

  Color _getColorForDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF4CAF50); // Green
      case 'intermediate':
        return const Color(0xFF6A4FB6); // Primary purple
      case 'advanced':
        return const Color(0xFFFF6B6B); // Accent red
      default:
        return AppTheme.primaryColor;
    }
  }
}