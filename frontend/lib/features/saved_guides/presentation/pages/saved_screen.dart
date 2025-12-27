import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/animations/app_animations.dart';
import '../../domain/entities/saved_guide_entity.dart';
import '../bloc/unified_saved_guides_bloc.dart';
import '../bloc/saved_guides_event.dart';
import '../bloc/saved_guides_state.dart';
import '../widgets/guide_list_item.dart';
import '../widgets/empty_state_widget.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Unified Saved Guides Screen with Clean Architecture
class SavedScreen extends StatefulWidget {
  final int? initialTabIndex;
  final String? navigationSource;

  const SavedScreen({
    super.key,
    this.initialTabIndex,
    this.navigationSource,
  });

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _savedScrollController;
  late ScrollController _recentScrollController;
  UnifiedSavedGuidesBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    _savedScrollController = ScrollController();
    _recentScrollController = ScrollController();

    // Setup scroll listeners for pagination
    _savedScrollController.addListener(_onSavedScroll);
    _recentScrollController.addListener(_onRecentScroll);
  }

  @override
  void dispose() {
    _savedScrollController.removeListener(_onSavedScroll);
    _recentScrollController.removeListener(_onRecentScroll);

    _tabController.dispose();
    _savedScrollController.dispose();
    _recentScrollController.dispose();
    _bloc = null;
    super.dispose();
  }

  void _onTabChanged(int tabIndex) {
    _bloc?.add(TabChangedEvent(tabIndex: tabIndex));
  }

  void _onSavedScroll() {
    if (_savedScrollController.position.pixels >=
        _savedScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreSaved();
    }
  }

  void _onRecentScroll() {
    if (_recentScrollController.position.pixels >=
        _recentScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreRecent();
    }
  }

  void _loadMoreSaved() {
    final bloc = _bloc;
    if (bloc != null) {
      final state = bloc.state;
      if (state is SavedGuidesApiLoaded &&
          !state.isLoadingSaved &&
          state.hasMoreSaved) {
        bloc.add(
          LoadSavedGuidesFromApi(offset: state.savedGuides.length),
        );
      }
    }
  }

  void _loadMoreRecent() {
    final bloc = _bloc;
    if (bloc != null) {
      final state = bloc.state;
      if (state is SavedGuidesApiLoaded &&
          !state.isLoadingRecent &&
          state.hasMoreRecent) {
        bloc.add(
          LoadRecentGuidesFromApi(offset: state.recentGuides.length),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) {
          final bloc = sl<UnifiedSavedGuidesBloc>();
          _bloc = bloc; // Store reference

          // Setup tab listener after BloC is available
          _tabController.addListener(() {
            _onTabChanged(_tabController.index);
          });

          // Load initial tab data based on the initial tab index
          final initialTab = _tabController.index;
          if (initialTab == 0) {
            bloc.add(const LoadSavedGuidesFromApi(refresh: true));
          } else {
            bloc.add(const LoadRecentGuidesFromApi(refresh: true));
          }
          return bloc;
        },
        child: _SavedScreenContent(
          tabController: _tabController,
          savedScrollController: _savedScrollController,
          recentScrollController: _recentScrollController,
          navigationSource: widget.navigationSource,
        ),
      );
}

class _SavedScreenContent extends StatelessWidget {
  final TabController tabController;
  final ScrollController savedScrollController;
  final ScrollController recentScrollController;
  final String? navigationSource;

  const _SavedScreenContent({
    required this.tabController,
    required this.savedScrollController,
    required this.recentScrollController,
    this.navigationSource,
  });

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          // Handle Android back button - use smart back navigation
          _handleBackNavigation(context);
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              onPressed: () => _handleBackNavigation(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
            ),
            title: Text(
              context.tr(TranslationKeys.savedGuidesTitle),
              style: AppFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with tabs
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Tab Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.1)
                              : AppTheme.primaryColor.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                        indicator: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        padding: const EdgeInsets.all(4),
                        tabs: [
                          Tab(
                            icon: Icon(Icons.bookmark, size: 18),
                            text: context.tr(TranslationKeys.savedGuidesSaved),
                          ),
                          Tab(
                            icon: Icon(Icons.history, size: 18),
                            text: context.tr(TranslationKeys.savedGuidesRecent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Content
              Expanded(
                child: BlocConsumer<UnifiedSavedGuidesBloc, SavedGuidesState>(
                  listener: (context, state) {
                    if (state is SavedGuidesError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (state is SavedGuidesActionSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is SavedGuidesTabLoading) {
                      return _buildLoadingIndicator(context, state.isRefresh);
                    }

                    if (state is SavedGuidesAuthRequired) {
                      return _buildAuthRequiredState(context, state);
                    }

                    if (state is SavedGuidesApiLoaded) {
                      return TabBarView(
                        controller: tabController,
                        children: [
                          _buildSavedTab(context, state),
                          _buildRecentTab(context, state),
                        ],
                      );
                    }

                    if (state is SavedGuidesError) {
                      return _buildErrorState(context, state.message);
                    }

                    return _buildLoadingIndicator(context, false);
                  },
                ),
              ),
            ],
          ),
        ), // Scaffold
      ); // PopScope

  Widget _buildLoadingIndicator(BuildContext context, bool isRefresh) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              isRefresh ? 'Refreshing guides...' : 'Loading guides...',
              style: AppFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );

  Widget _buildErrorState(BuildContext context, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr(TranslationKeys.savedGuidesErrorTitle),
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppFonts.inter(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.read<UnifiedSavedGuidesBloc>().add(
                            const LoadSavedGuidesFromApi(refresh: true),
                          );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr(TranslationKeys.savedGuidesRetry),
                            style: AppFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildAuthRequiredState(
          BuildContext context, SavedGuidesAuthRequired state) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.15),
                      const Color(0xFF6366F1).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  state.isForSavedGuides
                      ? Icons.bookmark_border
                      : Icons.history,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr(TranslationKeys.savedGuidesAuthRequired),
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.message,
                style: AppFonts.inter(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/auth'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      child: Text(
                        context.tr(TranslationKeys.recentGuidesSignIn),
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSavedTab(BuildContext context, SavedGuidesApiLoaded state) {
    if (state.savedGuides.isEmpty && !state.isLoadingSaved) {
      return EmptyStateWidget(
        icon: Icons.bookmark_border,
        title: context.tr(TranslationKeys.savedGuidesEmptyTitle),
        subtitle: context.tr(TranslationKeys.savedGuidesEmptyMessage),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        context.read<UnifiedSavedGuidesBloc>().add(
              const LoadSavedGuidesFromApi(refresh: true),
            );
      },
      child: ListView.builder(
        controller: savedScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.savedGuides.length + (state.isLoadingSaved ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.savedGuides.length) {
            // Loading indicator at the bottom
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            );
          }

          final guide = state.savedGuides[index];
          return FadeInWidget(
            delay: AppAnimations.getStaggerDelay(index),
            slideOffset: const Offset(0, 0.05),
            child: GuideListItem(
              guide: guide,
              onTap: () => _openGuide(context, guide),
              onRemove: () => _toggleSaveStatus(context, guide, false),
              showRemoveOption: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentTab(BuildContext context, SavedGuidesApiLoaded state) {
    if (state.recentGuides.isEmpty && !state.isLoadingRecent) {
      return EmptyStateWidget(
        icon: Icons.history,
        title: context.tr(TranslationKeys.savedGuidesRecentEmptyTitle),
        subtitle: context.tr(TranslationKeys.savedGuidesRecentEmptyMessage),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        context.read<UnifiedSavedGuidesBloc>().add(
              const LoadRecentGuidesFromApi(refresh: true),
            );
      },
      child: ListView.builder(
        controller: recentScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.recentGuides.length + (state.isLoadingRecent ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.recentGuides.length) {
            // Loading indicator at the bottom
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            );
          }

          final guide = state.recentGuides[index];
          return FadeInWidget(
            delay: AppAnimations.getStaggerDelay(index),
            slideOffset: const Offset(0, 0.05),
            child: GuideListItem(
              guide: guide,
              onTap: () => _openGuide(context, guide),
              onSave: guide.isSaved
                  ? null
                  : () => _toggleSaveStatus(context, guide, true),
            ),
          );
        },
      ),
    );
  }

  void _openGuide(BuildContext context, SavedGuideEntity guide) {
    // Determine source based on current tab
    final source = tabController.index == 0 ? 'saved' : 'recent';

    // Navigate to study guide screen with source parameter
    context.go('/study-guide?source=$source', extra: {
      'study_guide': {
        'id': guide.id,
        'title': guide.displayTitle,
        'content': guide.content,
        'type': guide.type.name,
        'verse_reference': guide.verseReference,
        'topic_name': guide.topicName,
        'is_saved': guide.isSaved,
        'created_at': guide.createdAt.toIso8601String(),
        'last_accessed_at': guide.lastAccessedAt.toIso8601String(),
        // Include structured content fields for proper display
        'summary': guide.summary,
        'interpretation': guide.interpretation,
        'context': guide.context,
        'related_verses': guide.relatedVerses,
        'reflection_questions': guide.reflectionQuestions,
        'prayer_points': guide.prayerPoints,
        // Include reflection enhancement fields
        'interpretation_insights': guide.interpretationInsights,
        'summary_insights': guide.summaryInsights,
        'reflection_answers': guide.reflectionAnswers,
        'context_question': guide.contextQuestion,
        'summary_question': guide.summaryQuestion,
        'related_verses_question': guide.relatedVersesQuestion,
        'reflection_question': guide.reflectionQuestion,
        'prayer_question': guide.prayerQuestion,
      }
    });
  }

  void _toggleSaveStatus(
      BuildContext context, SavedGuideEntity guide, bool save) {
    context.read<UnifiedSavedGuidesBloc>().add(
          ToggleGuideApiEvent(
            guideId: guide.id,
            save: save,
          ),
        );
  }

  /// Handles smart back navigation based on navigation source
  void _handleBackNavigation(BuildContext context) {
    // Check if we came from Generate Study screen
    if (navigationSource == 'generate' ||
        navigationSource == 'generate-study') {
      // Go back to Generate Study screen
      context.go(AppRoutes.generateStudy);
      return;
    }

    // Check if there's a navigation stack to pop
    if (context.canPop()) {
      // Default pop behavior if there's a navigation stack
      context.pop();
      return;
    }

    // Fallback to home if no stack
    context.go(AppRoutes.generateStudy);
  }
}
