import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/saved_guide_entity.dart';
import '../bloc/unified_saved_guides_bloc.dart';
import '../bloc/saved_guides_event.dart';
import '../bloc/saved_guides_state.dart';
import '../widgets/guide_list_item.dart';
import '../widgets/empty_state_widget.dart';

/// Unified Saved Guides Screen with Clean Architecture
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

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
    _tabController = TabController(length: 2, vsync: this);
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

          // Load initial tab data based on the default tab (0 = saved)
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
        ),
      );
}

class _SavedScreenContent extends StatelessWidget {
  final TabController tabController;
  final ScrollController savedScrollController;
  final ScrollController recentScrollController;

  const _SavedScreenContent({
    required this.tabController,
    required this.savedScrollController,
    required this.recentScrollController,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and tabs
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Study Guides',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Custom Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: tabController,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.onSurfaceVariant,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.bookmark, size: 20),
                          text: 'Saved',
                        ),
                        Tab(
                          icon: Icon(Icons.history, size: 20),
                          text: 'Recent',
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
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (state is SavedGuidesActionSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: AppTheme.successColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is SavedGuidesTabLoading) {
                    return _buildLoadingIndicator(state.isRefresh);
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

                  return _buildLoadingIndicator(false);
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildLoadingIndicator(bool isRefresh) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              isRefresh ? 'Refreshing guides...' : 'Loading guides...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.onSurfaceVariant,
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
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Guides',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.read<UnifiedSavedGuidesBloc>().add(
                        const LoadSavedGuidesFromApi(refresh: true),
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
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
              Icon(
                state.isForSavedGuides ? Icons.bookmark_border : Icons.history,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign In Required',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.go('/auth');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: AppTheme.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSavedTab(BuildContext context, SavedGuidesApiLoaded state) {
    if (state.savedGuides.isEmpty && !state.isLoadingSaved) {
      return const EmptyStateWidget(
        icon: Icons.bookmark_border,
        title: 'No Saved Guides',
        subtitle: 'Save your favorite study guides to access them here',
      );
    }

    return RefreshIndicator(
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
          return GuideListItem(
            guide: guide,
            onTap: () => _openGuide(context, guide),
            onRemove: () => _toggleSaveStatus(context, guide, false),
            showRemoveOption: true,
          );
        },
      ),
    );
  }

  Widget _buildRecentTab(BuildContext context, SavedGuidesApiLoaded state) {
    if (state.recentGuides.isEmpty && !state.isLoadingRecent) {
      return const EmptyStateWidget(
        icon: Icons.history,
        title: 'No Recent Guides',
        subtitle: 'Your recently viewed study guides will appear here',
      );
    }

    return RefreshIndicator(
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
          return GuideListItem(
            guide: guide,
            onTap: () => _openGuide(context, guide),
            onSave: guide.isSaved
                ? null
                : () => _toggleSaveStatus(context, guide, true),
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
}
