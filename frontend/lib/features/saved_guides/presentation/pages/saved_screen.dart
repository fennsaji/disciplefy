import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/saved_guide_entity.dart';
import '../bloc/saved_guides_bloc.dart';
import '../bloc/saved_guides_event.dart';
import '../bloc/saved_guides_state.dart';
import '../widgets/guide_list_item.dart';
import '../widgets/empty_state_widget.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<SavedGuidesBloc>()
        ..add(LoadSavedGuides())
        ..add(WatchSavedGuidesEvent())
        ..add(WatchRecentGuidesEvent()),
      child: _SavedScreenContent(tabController: _tabController),
    );
  }
}

class _SavedScreenContent extends StatelessWidget {
  final TabController tabController;

  const _SavedScreenContent({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  'Saved Guides',
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
            child: BlocConsumer<SavedGuidesBloc, SavedGuidesState>(
              listener: (context, state) {
                if (state is SavedGuidesError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                } else if (state is SavedGuidesActionSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is SavedGuidesLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  );
                }

                if (state is SavedGuidesLoaded) {
                  return TabBarView(
                    controller: tabController,
                    children: [
                      _buildSavedTab(context, state.savedGuides),
                      _buildRecentTab(context, state.recentGuides),
                    ],
                  );
                }

                return const Center(
                  child: Text('Failed to load guides'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTab(BuildContext context, List<SavedGuideEntity> guides) {
    if (guides.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.bookmark_border,
        title: 'No Saved Guides',
        subtitle: 'Save your favorite study guides to access them here',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<SavedGuidesBloc>().add(LoadSavedGuides());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: guides.length,
        itemBuilder: (context, index) {
          final guide = guides[index];
          return GuideListItem(
            guide: guide,
            onTap: () => _openGuide(context, guide),
            onRemove: () => _showRemoveDialog(context, guide),
            showRemoveOption: true,
          );
        },
      ),
    );
  }

  Widget _buildRecentTab(BuildContext context, List<SavedGuideEntity> guides) {
    if (guides.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history,
        title: 'No Recent Guides',
        subtitle: 'Your recently viewed study guides will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<SavedGuidesBloc>().add(LoadRecentGuides());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: guides.length,
        itemBuilder: (context, index) {
          final guide = guides[index];
          return GuideListItem(
            guide: guide,
            onTap: () => _openGuide(context, guide),
            onRemove: () => _showRemoveDialog(context, guide),
            showRemoveOption: false,
          );
        },
      ),
    );
  }

  void _openGuide(BuildContext context, SavedGuideEntity guide) {
    // Add to recent when opening
    context.read<SavedGuidesBloc>().add(AddToRecentEvent(
      guide.copyWith(lastAccessedAt: DateTime.now()),
    ));

    // Navigate to study guide screen
    context.go('/study-guide', extra: {
      'study_guide': {
        'id': guide.id,
        'title': guide.displayTitle,
        'content': guide.content,
        'type': guide.type.name,
        'verse_reference': guide.verseReference,
        'topic_name': guide.topicName,
      }
    });
  }

  void _showRemoveDialog(BuildContext context, SavedGuideEntity guide) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Guide'),
        content: Text('Are you sure you want to remove "${guide.displayTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SavedGuidesBloc>().add(RemoveGuideEvent(guide.id));
              Navigator.of(context).pop();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}