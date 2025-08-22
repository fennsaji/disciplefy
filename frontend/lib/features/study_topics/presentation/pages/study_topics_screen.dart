import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../../home/presentation/bloc/home_event.dart';
import '../bloc/study_topics_bloc.dart';
import '../bloc/study_topics_event.dart';
import '../bloc/study_topics_state.dart';
import '../widgets/topics_grid_view.dart';
import '../widgets/category_filter_chips.dart';

/// Screen for browsing all study topics with filtering and search capabilities.
class StudyTopicsScreen extends StatelessWidget {
  const StudyTopicsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) =>
            sl<StudyTopicsBloc>()..add(const LoadStudyTopics()),
        child: const _StudyTopicsScreenContent(),
      );
}

class _StudyTopicsScreenContent extends StatefulWidget {
  const _StudyTopicsScreenContent();

  @override
  State<_StudyTopicsScreenContent> createState() =>
      _StudyTopicsScreenContentState();
}

class _StudyTopicsScreenContentState extends State<_StudyTopicsScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<StudyTopicsBloc>().add(SearchTopics(_searchController.text));
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (_isSearchExpanded) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: BlocConsumer<StudyTopicsBloc, StudyTopicsState>(
        listener: (context, state) {
          // Handle any side effects here if needed
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<StudyTopicsBloc>().add(const RefreshStudyTopics());
              // Wait for the refresh to complete
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: _buildBody(context, state),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        color: AppTheme.textPrimary,
        onPressed: () {
          // Check if we can pop, otherwise navigate to home
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
      title: _isSearchExpanded
          ? _buildSearchField()
          : Text(
              'Study Topics',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
          color: AppTheme.textPrimary,
          onPressed: _toggleSearch,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      style: GoogleFonts.inter(
        fontSize: 16,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Search topics...',
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: AppTheme.onSurfaceVariant,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBody(BuildContext context, StudyTopicsState state) {
    if (state is StudyTopicsLoading) {
      return _buildLoadingState();
    } else if (state is StudyTopicsError) {
      return _buildErrorState(context, state);
    } else if (state is StudyTopicsEmpty) {
      return _buildEmptyState(context, state);
    } else if (state is StudyTopicsLoaded ||
        state is StudyTopicsFiltering ||
        state is StudyTopicsLoadingMore) {
      return _buildLoadedState(context, state);
    }

    return _buildLoadingState();
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 40),
          TopicsGridLoadingSkeleton(itemCount: 8),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, StudyTopicsError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.accentColor,
            ),
            const SizedBox(height: 16),
            Text(
              state.isInitialLoadError
                  ? 'Failed to Load Topics'
                  : 'Something Went Wrong',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context
                    .read<StudyTopicsBloc>()
                    .add(const LoadStudyTopics(forceRefresh: true));
              },
              icon: const Icon(Icons.refresh),
              label: Text(
                'Try Again',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, StudyTopicsEmpty state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Topics Found',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.currentFilter.hasFilters
                  ? 'Try adjusting your filters or search terms'
                  : 'No study topics are available at the moment',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (state.currentFilter.hasFilters) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<StudyTopicsBloc>().add(const ClearFilters());
                },
                icon: const Icon(Icons.clear_all),
                label: Text(
                  'Clear Filters',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, StudyTopicsState state) {
    List<RecommendedGuideTopic> topics = [];
    List<String> categories = [];
    bool isFiltering = false;
    bool isLoadingMore = false;
    bool hasMore = false;

    if (state is StudyTopicsLoaded) {
      topics = state.topics;
      categories = state.categories;
      hasMore = state.hasMore;
    } else if (state is StudyTopicsFiltering) {
      topics = state.currentTopics;
      categories = state.categories;
      isFiltering = true;
    } else if (state is StudyTopicsLoadingMore) {
      topics = state.currentTopics;
      categories = state.categories;
      isLoadingMore = true;
      hasMore = state.hasMore;
    }

    return Column(
      children: [
        // Category filter chips
        BlocBuilder<StudyTopicsBloc, StudyTopicsState>(
          buildWhen: (previous, current) =>
              previous != current &&
              (current is StudyTopicsLoaded ||
                  current is StudyTopicsEmpty ||
                  current is StudyTopicsFiltering),
          builder: (context, state) {
            List<String> categories = [];
            List<String> selectedCategories = [];
            final bool isLoading = state is StudyTopicsLoading;

            if (state is StudyTopicsLoaded) {
              categories = state.categories;
              selectedCategories = state.currentFilter.selectedCategories;
            } else if (state is StudyTopicsEmpty) {
              categories = state.categories;
              selectedCategories = state.currentFilter.selectedCategories;
            } else if (state is StudyTopicsFiltering) {
              categories = state.categories;
              selectedCategories = state.currentFilter.selectedCategories;
            }

            return CategoryFilterChips(
              categories: categories,
              selectedCategories: selectedCategories,
              isLoading: isLoading,
              onCategoriesChanged: (selectedCategories) {
                context.read<StudyTopicsBloc>().add(
                      FilterByCategories(selectedCategories),
                    );
              },
            );
          },
        ),

        // Topics content
        Expanded(
          child: Stack(
            children: [
              // Main topics list
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Topics count
                  Text(
                    '${topics.length} topics found',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Topics grid
                  TopicsGridView(
                    topics: topics,
                    onTopicTap: _navigateToStudyGuide,
                    isLoading: isLoadingMore,
                    hasMore: hasMore,
                    onLoadMore: hasMore
                        ? () {
                            context
                                .read<StudyTopicsBloc>()
                                .add(const LoadMoreTopics());
                          }
                        : null,
                  ),

                  const SizedBox(height: 24),
                ],
              ),

              // Filtering overlay
              if (isFiltering)
                Container(
                  color: Colors.black.withOpacity(0.1),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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

    // Navigate back to home to see the generation progress
    context.pop();
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
}
