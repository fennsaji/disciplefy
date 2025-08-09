import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../saved_guides/domain/entities/saved_guide_entity.dart';
import '../../../saved_guides/presentation/bloc/unified_saved_guides_bloc.dart';
import '../../../saved_guides/presentation/bloc/saved_guides_event.dart';
import '../../../saved_guides/presentation/bloc/saved_guides_state.dart';
import 'guide_quick_item.dart';

/// Recent guides section widget for the bottom of GenerateStudyScreen
///
/// Features:
/// - Shows 3-5 most recent study guides
/// - Loading states and empty states
/// - Quick access to recent guides with save/unsave actions
class RecentGuidesSection extends StatefulWidget {
  const RecentGuidesSection({super.key});

  @override
  State<RecentGuidesSection> createState() => _RecentGuidesSectionState();
}

class _RecentGuidesSectionState extends State<RecentGuidesSection> {
  UnifiedSavedGuidesBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _initializeBloc();
  }

  void _initializeBloc() {
    _bloc = sl<UnifiedSavedGuidesBloc>();
    _bloc?.add(const LoadRecentGuidesFromApi(refresh: true, limit: 5));
  }

  @override
  void dispose() {
    _bloc = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc!,
      child: BlocBuilder<UnifiedSavedGuidesBloc, SavedGuidesState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.primaryColor.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Recent Studies section
              if (state is SavedGuidesApiLoaded) ...[
                _buildRecentStudiesSection(state),
              ] else if (state is SavedGuidesTabLoading) ...[
                _buildLoadingSection(),
              ] else if (state is SavedGuidesAuthRequired) ...[
                _buildAuthRequiredSection(),
              ] else if (state is SavedGuidesError) ...[
                _buildErrorSection(state.message),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentStudiesSection(SavedGuidesApiLoaded state) {
    if (state.recentGuides.isEmpty) {
      return _buildEmptyRecentSection();
    }

    // Show only first 3 guides for compact display
    final displayGuides = state.recentGuides.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Studies',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (state.recentGuides.length > 3)
              GestureDetector(
                onTap: () => context.push('/saved?tab=recent'),
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Recent guides list
        ...displayGuides.map((guide) => GuideQuickItem(
              guide: guide,
              onTap: () => _openGuide(guide),
              onSave:
                  guide.isSaved ? null : () => _toggleSaveStatus(guide, true),
              showSaveAction: !guide.isSaved,
            )),
      ],
    );
  }

  Widget _buildEmptyRecentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 40,
            color: AppTheme.onSurfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'No Recent Studies',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate your first study guide to see it here',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Studies',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        // Shimmer loading placeholders
        ...List.generate(
          3,
          (index) => Container(
            height: 60,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.onSurfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthRequiredSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_outline,
            size: 40,
            color: AppTheme.primaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign In for Recent Studies',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'View your recent study guides across devices',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to Load Recent Studies',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _bloc
                ?.add(const LoadRecentGuidesFromApi(refresh: true, limit: 5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGuide(SavedGuideEntity guide) {
    // Navigate to study guide screen with source parameter
    context.go('/study-guide?source=recent', extra: {
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
        // Include structured content fields
        'summary': guide.summary,
        'interpretation': guide.interpretation,
        'context': guide.context,
        'related_verses': guide.relatedVerses,
        'reflection_questions': guide.reflectionQuestions,
        'prayer_points': guide.prayerPoints,
      }
    });
  }

  void _toggleSaveStatus(SavedGuideEntity guide, bool save) {
    _bloc?.add(
      ToggleGuideApiEvent(
        guideId: guide.id,
        save: save,
      ),
    );
  }
}
