import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../../home/presentation/bloc/home_event.dart';
import '../../../home/presentation/bloc/home_state.dart';
import '../bloc/study_topics_bloc.dart';
import '../bloc/study_topics_event.dart';
import '../bloc/study_topics_state.dart';
import '../widgets/topics_grid_view.dart';
import '../widgets/category_filter_chips.dart';

/// Screen for browsing all study topics with filtering and search capabilities.
class StudyTopicsScreen extends StatelessWidget {
  const StudyTopicsScreen({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                sl<StudyTopicsBloc>()..add(const LoadStudyTopics()),
          ),
          BlocProvider.value(
            value: sl<HomeBloc>(),
          ),
        ],
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
  bool _isGeneratingStudyGuide = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      final searchText = _searchController.text;
      if (mounted) {
        context.read<StudyTopicsBloc>().add(SearchTopics(searchText));
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (_isSearchExpanded) {
        _searchFocusNode.requestFocus();
      } else {
        // Temporarily remove listener to avoid conflict
        _searchController.removeListener(_onSearchChanged);
        _searchController.clear();
        _searchFocusNode.unfocus();
        // Re-add listener
        _searchController.addListener(_onSearchChanged);
        // Reset all filters when closing search
        context.read<StudyTopicsBloc>().add(const ClearFilters());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: MultiBlocListener(
        listeners: [
          BlocListener<StudyTopicsBloc, StudyTopicsState>(
            listener: (context, state) {
              // Handle any side effects here if needed
            },
          ),
          BlocListener<HomeBloc, HomeState>(
            listener: (context, state) {
              if (state is HomeStudyGuideGenerated) {
                // Stop loading and navigate directly to study guide screen
                setState(() {
                  _isGeneratingStudyGuide = false;
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.go('/study-guide?source=studyTopics',
                    extra: state.studyGuide);
              } else if (state is HomeStudyGuideGeneratedCombined) {
                // Stop loading and navigate directly to study guide screen
                setState(() {
                  _isGeneratingStudyGuide = false;
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.go('/study-guide?source=studyTopics',
                    extra: state.studyGuide);
              } else if (state is HomeCombinedState) {
                // Update loading state based on study guide generation status
                setState(() {
                  _isGeneratingStudyGuide = state.isGeneratingStudyGuide;
                });

                // Handle generation error
                if (state.generationError != null) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr(
                          TranslationKeys.studyTopicsGenerationError,
                          {'error': state.generationError})),
                      backgroundColor: Colors.red,
                      action: SnackBarAction(
                        label: context.tr(TranslationKeys.commonCancel),
                        onPressed: () =>
                            ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
        child: BlocBuilder<StudyTopicsBloc, StudyTopicsState>(
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
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return StudyTopicsAppBar(
      isSearchExpanded: _isSearchExpanded,
      onToggleSearch: _toggleSearch,
      onBuildSearchField: _buildSearchField,
      onNavigateBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onBackground,
        ),
        decoration: InputDecoration(
          hintText: context.tr(TranslationKeys.studyTopicsSearchHint),
          hintStyle: GoogleFonts.inter(
            fontSize: 16,
            color: AppTheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
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
    return ErrorStateView(
      message: state.message,
      isInitialLoadError: state.isInitialLoadError,
      onRetry: () => context
          .read<StudyTopicsBloc>()
          .add(const LoadStudyTopics(forceRefresh: true)),
    );
  }

  Widget _buildEmptyState(BuildContext context, StudyTopicsEmpty state) {
    return EmptyStateView(
      hasFilters: state.currentFilter.hasFilters,
      onClearFilters: () =>
          context.read<StudyTopicsBloc>().add(const ClearFilters()),
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

    return TopicsLoadedView(
      topics: topics,
      categories: categories,
      isFiltering: isFiltering,
      isLoadingMore: isLoadingMore,
      hasMore: hasMore,
      isGeneratingStudyGuide: _isGeneratingStudyGuide,
      onTopicTap: _navigateToStudyGuide,
      onFilterCategories: (selectedCategories) => context
          .read<StudyTopicsBloc>()
          .add(FilterByCategories(selectedCategories)),
      onLoadMore: () =>
          context.read<StudyTopicsBloc>().add(const LoadMoreTopics()),
    );
  }

  void _navigateToStudyGuide(RecommendedGuideTopic topic) {
    // Prevent multiple clicks during generation
    if (_isGeneratingStudyGuide) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.tr(TranslationKeys.studyTopicsGenerationInProgress)),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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

    // Set loading state immediately
    setState(() {
      _isGeneratingStudyGuide = true;
    });

    // Generate study guide using HomeBloc - navigation handled by BlocListener
    context.read<HomeBloc>().add(GenerateStudyGuideFromTopic(
          topicName: topic.title,
          language: _getLanguageCode(selectedLanguage),
        ));

    // Show generation progress immediately
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
            Text(context.tr(
                TranslationKeys.studyTopicsGenerating, {'topic': topic.title})),
          ],
        ),
        duration: const Duration(minutes: 1),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
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

/// Error state view widget for displaying error messages with retry functionality.
class ErrorStateView extends StatelessWidget {
  final String message;
  final bool isInitialLoadError;
  final VoidCallback onRetry;

  const ErrorStateView({
    super.key,
    required this.message,
    required this.isInitialLoadError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppTheme.accentColor),
            const SizedBox(height: 16),
            Text(
              isInitialLoadError
                  ? context.tr(TranslationKeys.studyTopicsFailedToLoad)
                  : context.tr(TranslationKeys.studyTopicsSomethingWentWrong),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.inter(
                    fontSize: 16, color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr(TranslationKeys.studyTopicsTryAgain),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state view widget for displaying no topics found message.
class EmptyStateView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;

  const EmptyStateView({
    super.key,
    required this.hasFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                size: 64, color: AppTheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.studyTopicsNoTopicsFound),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? context.tr(TranslationKeys.studyTopicsAdjustFilters)
                  : context.tr(TranslationKeys.studyTopicsNoTopicsAvailable),
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ..._buildClearFiltersButton(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildClearFiltersButton(BuildContext context) {
    return [
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onClearFilters,
        icon: const Icon(Icons.clear_all),
        label: Text(context.tr(TranslationKeys.studyTopicsClearFilters),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ];
  }
}

/// Topics loaded view widget for displaying the main content with filters and topics grid.
class TopicsLoadedView extends StatelessWidget {
  final List<RecommendedGuideTopic> topics;
  final List<String> categories;
  final bool isFiltering;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isGeneratingStudyGuide;
  final Function(RecommendedGuideTopic) onTopicTap;
  final Function(List<String>) onFilterCategories;
  final VoidCallback onLoadMore;

  const TopicsLoadedView({
    super.key,
    required this.topics,
    required this.categories,
    required this.isFiltering,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isGeneratingStudyGuide,
    required this.onTopicTap,
    required this.onFilterCategories,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<StudyTopicsBloc, StudyTopicsState>(
          buildWhen: (previous, current) => _shouldRebuildFilters(current),
          builder: (context, state) => _buildCategoryFilters(state),
        ),
        Expanded(
          child: Stack(
            children: [
              _buildTopicsList(context),
              if (isFiltering) _buildFilteringOverlay(),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldRebuildFilters(StudyTopicsState current) {
    return current is StudyTopicsLoaded ||
        current is StudyTopicsEmpty ||
        current is StudyTopicsFiltering;
  }

  Widget _buildCategoryFilters(StudyTopicsState state) {
    final selectedCategories = _getSelectedCategories(state);
    return CategoryFilterChips(
      categories: categories,
      selectedCategories: selectedCategories,
      isLoading: state is StudyTopicsLoading,
      onCategoriesChanged: onFilterCategories,
    );
  }

  List<String> _getSelectedCategories(StudyTopicsState state) {
    if (state is StudyTopicsLoaded) {
      return state.currentFilter.selectedCategories;
    }
    if (state is StudyTopicsEmpty) {
      return state.currentFilter.selectedCategories;
    }
    if (state is StudyTopicsFiltering) {
      return state.currentFilter.selectedCategories;
    }
    return [];
  }

  Widget _buildTopicsList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.tr(TranslationKeys.studyTopicsTopicsFound,
              {'count': topics.length.toString()}),
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 16),
        TopicsGridView(
          topics: topics,
          onTopicTap: onTopicTap,
          isLoading: isLoadingMore,
          hasMore: hasMore,
          isGeneratingStudyGuide: isGeneratingStudyGuide,
          onLoadMore: hasMore ? onLoadMore : null,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilteringOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.1),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      ),
    );
  }
}

/// App bar widget for the Study Topics screen with search functionality.
class StudyTopicsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isSearchExpanded;
  final VoidCallback onToggleSearch;
  final Widget Function() onBuildSearchField;
  final VoidCallback onNavigateBack;

  const StudyTopicsAppBar({
    super.key,
    required this.isSearchExpanded,
    required this.onToggleSearch,
    required this.onBuildSearchField,
    required this.onNavigateBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: Theme.of(context).colorScheme.onBackground,
          onPressed: onNavigateBack,
        ),
        title: isSearchExpanded
            ? onBuildSearchField()
            : Text(
                context.tr(TranslationKeys.studyTopicsTitle),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(isSearchExpanded ? Icons.close : Icons.search),
            color: Theme.of(context).colorScheme.onBackground,
            onPressed: onToggleSearch,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 15);
}
