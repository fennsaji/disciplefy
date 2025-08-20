import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_event.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../daily_verse/presentation/widgets/daily_verse_card.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';

import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

/// Home screen displaying daily verse, navigation options, and study recommendations.
///
/// Features app logo, verse of the day, main navigation, and predefined study topics
/// following the UX specifications and brand guidelines.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) =>
            sl<HomeBloc>()..add(const LoadRecommendedTopics(limit: 6)),
        child: const _HomeScreenContent(),
      );
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  final bool _hasResumeableStudy = false;

  @override
  void initState() {
    super.initState();
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

  /// Handle daily verse card tap to generate study guide
  void _onDailyVerseCardTap() {
    // Get the current DailyVerseBloc state
    final dailyVerseBloc = context.read<DailyVerseBloc>();
    final currentState = dailyVerseBloc.state;

    if (currentState is DailyVerseLoaded) {
      // Generate study guide with verse reference and selected language
      context.read<HomeBloc>().add(GenerateStudyGuideFromVerse(
            verseReference: currentState.verse.reference,
            language: _getLanguageCode(currentState.currentLanguage),
          ));
    } else if (currentState is DailyVerseOffline) {
      // Generate study guide with cached verse reference and selected language
      context.read<HomeBloc>().add(GenerateStudyGuideFromVerse(
            verseReference: currentState.verse.reference,
            language: _getLanguageCode(currentState.currentLanguage),
          ));
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

  /// Convert VerseLanguage enum to language code string
  String _getLanguageCode(VerseLanguage language) {
    switch (language) {
      case VerseLanguage.english:
        return 'en';
      case VerseLanguage.hindi:
        return 'hi';
      case VerseLanguage.malayalam:
        return 'ml';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return BlocListener<HomeBloc, HomeState>(
      listener: (context, state) {
        if (state is HomeStudyGuideGenerated) {
          // Navigate to study guide screen
          context.go('/study-guide?source=home', extra: state.studyGuide);
        } else if (state is HomeCombinedState) {
          // Handle study guide generation states
          if (state.isGeneratingStudyGuide && state.generationInput != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                        'Generating study guide for "${state.generationInput}"...'),
                  ],
                ),
                duration: const Duration(minutes: 1),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          } else if (state.generationError != null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to generate study guide: ${state.generationError}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (!state.isGeneratingStudyGuide) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        }
      },
      child: ListenableBuilder(
        listenable: sl<AuthStateProvider>(),
        builder: (context, _) {
          final authProvider = sl<AuthStateProvider>();
          final currentUserName = authProvider.currentUserName;

          if (kDebugMode) {
            print(
                '👤 [HOME] User loaded via AuthStateProvider: $currentUserName');
            print('👤 [HOME] Auth state: ${authProvider.debugInfo}');
          }

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          ).withHomeProtection();
        },
      ),
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
              color: Theme.of(context).colorScheme.onBackground,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Continue your spiritual journey with guided study',
            style: GoogleFonts.inter(
              fontSize: 16,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
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

  Widget _buildRecommendedTopics() => BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          final homeState =
              state is HomeCombinedState ? state : const HomeCombinedState();

          return Column(
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
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  if (homeState.isLoadingTopics)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (homeState.topicsError != null)
                _buildTopicsErrorWidget(homeState.topicsError!)
              else if (homeState.isLoadingTopics)
                _buildTopicsLoadingWidget()
              else if (homeState.topics.isEmpty)
                _buildNoTopicsWidget()
              else
                _buildTopicsGrid(homeState.topics),
            ],
          );
        },
      );

  Widget _buildTopicsErrorWidget(String error) => Container(
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
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context
                  .read<HomeBloc>()
                  .add(const RefreshRecommendedTopics()),
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
            children: List.generate(
                6,
                (index) => SizedBox(
                      width: cardWidth,
                      child: _buildLoadingTopicCard(),
                    )),
          );
        },
      );

  Widget _buildLoadingTopicCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor),
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
          color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildTopicsGrid(List<RecommendedGuideTopic> topics) {
    // Use a different approach: Wrap or ListView instead of fixed-height GridView
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal card width (accounting for spacing)
        const double spacing = 16.0;
        final double cardWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: topics
              .map((topic) => SizedBox(
                    width: cardWidth,
                    child: _RecommendedGuideTopicCard(
                      topic: topic,
                      onTap: () => _navigateToStudyGuide(topic),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  void _navigateToStudyGuide(RecommendedGuideTopic topic) {
    // Get the current language from Daily Verse state
    final dailyVerseBloc = context.read<DailyVerseBloc>();
    final currentState = dailyVerseBloc.state;

    VerseLanguage selectedLanguage =
        VerseLanguage.english; // Default to English
    if (currentState is DailyVerseLoaded) {
      selectedLanguage = currentState.currentLanguage;
    } else if (currentState is DailyVerseOffline) {
      selectedLanguage = currentState.currentLanguage;
    }

    // Generate study guide using HomeBloc
    context.read<HomeBloc>().add(GenerateStudyGuideFromTopic(
          topicName: topic.title,
          language: _getLanguageCode(selectedLanguage),
        ));
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
    const color = AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
          mainAxisSize:
              MainAxisSize.min, // Important: Don't expand unnecessarily
          children: [
            // Header row with icon
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
                Flexible(
                  // Use Flexible instead of Spacer
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Foundational Doctrines',
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
                color: Theme.of(context).colorScheme.onSurface,
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  height: 1.3,
                ),
                maxLines: 3, // Allow up to 3 lines
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12), // Fixed spacing instead of Spacer

            // Footer with metadata - use Wrap for overflow protection
            // Wrap(
            //   spacing: 8,
            //   runSpacing: 4,
            //   crossAxisAlignment: WrapCrossAlignment.center,
            //   children: [
            //     Row(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         const Icon(
            //           Icons.schedule,
            //           size: 12,
            //           color: AppTheme.onSurfaceVariant,
            //         ),
            //         const SizedBox(width: 3),
            //         Text(
            //           '${topic.estimatedMinutes}min',
            //           style: GoogleFonts.inter(
            //             fontSize: 10,
            //             color: AppTheme.onSurfaceVariant,
            //           ),
            //         ),
            //       ],
            //     ),
            //     Row(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         const Icon(
            //           Icons.book_outlined,
            //           size: 12,
            //           color: AppTheme.onSurfaceVariant,
            //         ),
            //         const SizedBox(width: 3),
            //         Text(
            //           '${topic.scriptureCount}',
            //           style: GoogleFonts.inter(
            //             fontSize: 10,
            //             color: AppTheme.onSurfaceVariant,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  // Category to icon mapping
  static const Map<String, IconData> _categoryIcons = {
    'Foundational Doctrines': Icons.foundation,
    'spiritual disciplines': Icons.self_improvement,
    'salvation': Icons.favorite,
    'christian living': Icons.directions_walk,
    'character of god': Icons.auto_awesome,
    'relationships': Icons.people,
    'spiritual growth': Icons.trending_up,
  };

  IconData _getIconForCategory(String category) =>
      _categoryIcons[category.toLowerCase()] ?? Icons.menu_book;
}
