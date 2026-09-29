import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_event.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_state.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/unified_saved_guides_bloc.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/guide_quick_item.dart';

/// "Continue reading" section at the bottom of the Generate tab.
///
/// Loads the most recent guides and shows the latest two as tinted cards,
/// with "See all" opening the Recent tab of the library. Also covers the
/// loading, empty, signed-out and error states.
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

  void _seeAll() => context.push('/saved?tab=recent&source=generate');

  Widget _buildRecentStudiesSection(SavedGuidesApiLoaded state) {
    if (state.recentGuides.isEmpty) {
      return _buildEmptyRecentSection();
    }

    return ContinueReadingRow(
      guides: state.recentGuides,
      onOpen: _openGuide,
      onSave: (guide) => _toggleSaveStatus(guide, true),
      onSeeAll: _seeAll,
    );
  }

  Widget _buildEmptyRecentSection() {
    return _StatusCard(
      icon: Icons.history_rounded,
      title: context.tr(TranslationKeys.recentGuidesEmpty),
      message: context.tr(TranslationKeys.recentGuidesEmptyMessage),
    );
  }

  Widget _buildLoadingSection() {
    final palette = ReaderPalette.of(context);
    Widget placeholder() => Expanded(
          child: Container(
            height: GuideQuickItem.height,
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContinueReadingHeader(onSeeAll: _seeAll),
        const SizedBox(height: 12),
        Row(children: [
          placeholder(),
          const SizedBox(width: 10),
          placeholder()
        ]),
      ],
    );
  }

  Widget _buildAuthRequiredSection() {
    return _StatusCard(
      icon: Icons.person_outline_rounded,
      title: context.tr(TranslationKeys.recentGuidesAuthRequired),
      message: context.tr(TranslationKeys.recentGuidesAuthMessage),
      actionLabel: context.tr(TranslationKeys.recentGuidesSignIn),
      onAction: () => context.push('/login'),
    );
  }

  Widget _buildErrorSection(String message) {
    return _StatusCard(
      icon: Icons.error_outline_rounded,
      title: context.tr(TranslationKeys.recentGuidesError),
      message: context.tr(TranslationKeys.recentGuidesErrorMessage),
      actionLabel: context.tr(TranslationKeys.homeTryAgain),
      onAction: () =>
          _bloc?.add(const LoadRecentGuidesFromApi(refresh: true, limit: 5)),
    );
  }

  void _openGuide(SavedGuideEntity guide) {
    // Navigate to study guide screen with source parameter
    context.push('/study-guide?source=recent', extra: {
      'study_guide': {
        'id': guide.id,
        'title': guide.displayTitle,
        'content': guide.content,
        'type': guide.type.name,
        'study_mode': guide.studyMode,
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
        'passage': guide.passage,
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

/// "Continue reading" title with the "See all" link to the library.
class ContinueReadingHeader extends StatelessWidget {
  final VoidCallback onSeeAll;

  const ContinueReadingHeader({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr(TranslationKeys.generateStudyContinueReading),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: palette.muted,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 36),
          ),
          child: Text(
            context.tr(TranslationKeys.generateStudySeeAll),
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Header plus the two most recent guides side by side.
class ContinueReadingRow extends StatelessWidget {
  final List<SavedGuideEntity> guides;
  final ValueChanged<SavedGuideEntity> onOpen;
  final ValueChanged<SavedGuideEntity> onSave;
  final VoidCallback onSeeAll;

  /// Injectable clock for the cards' "time ago" labels (tests).
  final DateTime? now;

  const ContinueReadingRow({
    super.key,
    required this.guides,
    required this.onOpen,
    required this.onSave,
    required this.onSeeAll,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final shown = guides.take(2).toList();
    Widget card(SavedGuideEntity guide) => GuideQuickItem(
          guide: guide,
          now: now,
          onTap: () => onOpen(guide),
          onSave: guide.isSaved ? null : () => onSave(guide),
          showSaveAction: !guide.isSaved,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContinueReadingHeader(onSeeAll: onSeeAll),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: card(shown[0])),
            const SizedBox(width: 10),
            Expanded(
              child: shown.length > 1 ? card(shown[1]) : const SizedBox(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Empty / signed-out / error state in the reader card style.
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: palette.accentIcon),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.text,
                side: BorderSide(color: palette.outline),
                shape: const StadiumBorder(),
              ),
              child: Text(
                actionLabel!,
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
