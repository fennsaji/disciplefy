import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/widgets/guide_list_item.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';

/// One "Continue reading" row on the Generate tab: the guide's type icon in a
/// gold-tinted square, its title, "Type · mode · duration · when" and a
/// bookmark that saves or unsaves it.
class ContinueReadingItem extends StatelessWidget {
  final SavedGuideEntity guide;
  final VoidCallback onTap;

  /// Saves the guide when unsaved, removes it from saved when saved.
  final VoidCallback onToggleSave;

  /// Injectable clock for the "time ago" label (tests).
  final DateTime? now;

  const ContinueReadingItem({
    super.key,
    required this.guide,
    required this.onTap,
    required this.onToggleSave,
    this.now,
  });

  /// Size of the leading type tile.
  static const double tileSize = 36;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final kind = guide.libraryKind;
    final mode = studyModeFromString(guide.studyMode);
    final meta = [
      context.tr(_kindLabelKey(kind)),
      if (mode != null) mode.localizedShortName(context),
      if (mode != null) mode.localizedDuration(context),
      _timeAgo(context, guide.lastAccessedAt),
    ].join(' · ');

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '${guide.displayTitle}, $meta',
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _TypeTile(kind: kind),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            guide.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.inter(
                                fontSize: 12, color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _Bookmark(saved: guide.isSaved, onToggle: onToggleSave),
      ],
    );
  }

  static String _kindLabelKey(LibraryGuideKind kind) {
    switch (kind) {
      case LibraryGuideKind.scripture:
        return TranslationKeys.generateStudyScriptureTab;
      case LibraryGuideKind.question:
        return TranslationKeys.generateStudyQuestionMode;
      case LibraryGuideKind.topic:
        return TranslationKeys.generateStudyTopicMode;
    }
  }

  String _timeAgo(BuildContext context, DateTime dateTime) {
    final difference = (now ?? DateTime.now()).difference(dateTime);

    if (difference.inDays > 0) {
      return context.tr(TranslationKeys.recentGuidesDaysAgo,
          {'count': difference.inDays.toString()});
    } else if (difference.inHours > 0) {
      return context.tr(TranslationKeys.recentGuidesHoursAgo,
          {'count': difference.inHours.toString()});
    } else if (difference.inMinutes > 0) {
      return context.tr(TranslationKeys.recentGuidesMinutesAgo,
          {'count': difference.inMinutes.toString()});
    }
    return context.tr(TranslationKeys.recentGuidesJustNow);
  }
}

/// Leading type icon on a gold tint, as the design's rows (the same tint
/// for scripture, topic and question).
class _TypeTile extends StatelessWidget {
  final LibraryGuideKind kind;

  const _TypeTile({required this.kind});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final icon = switch (kind) {
      LibraryGuideKind.scripture => Icons.menu_book_outlined,
      LibraryGuideKind.topic => Icons.lightbulb_outline_rounded,
      LibraryGuideKind.question => Icons.help_outline_rounded,
    };
    return Container(
      width: ContinueReadingItem.tileSize,
      height: ContinueReadingItem.tileSize,
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: palette.isDark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: palette.accentIcon),
    );
  }
}

class _Bookmark extends StatelessWidget {
  final bool saved;
  final VoidCallback onToggle;

  const _Bookmark({required this.saved, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return IconButton(
      onPressed: onToggle,
      tooltip: context.tr(saved
          ? TranslationKeys.savedGuidesRemove
          : TranslationKeys.savedGuidesSave),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        size: 20,
        color: saved ? palette.accentIcon : palette.dim,
      ),
    );
  }
}
