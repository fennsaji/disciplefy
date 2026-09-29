import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';

/// Kind of guide as the library labels it. Topics phrased as a question are
/// shown as "Question", like the Generate tab's input modes.
enum LibraryGuideKind { scripture, topic, question }

extension LibraryGuideKindOf on SavedGuideEntity {
  LibraryGuideKind get libraryKind {
    if (type == GuideType.verse) return LibraryGuideKind.scripture;
    return displayTitle.trim().endsWith('?')
        ? LibraryGuideKind.question
        : LibraryGuideKind.topic;
  }
}

/// Library card tints, cycled by grid position (indigo, gold, teal, violet)
/// as in the library design.
const List<Color> kLibraryCardTints = [
  AppColors.brandPrimary,
  AppColors.brandGold,
  Color(0xFF14B8A6),
  Color(0xFF9B5DE5),
];

/// "Mode · date" line of a library card: "Quick Read · Yesterday", or
/// "Quick Read · 3 min · Yesterday" [withDuration].
String libraryGuideMeta(BuildContext context, SavedGuideEntity guide,
    {DateTime? now, bool withDuration = false}) {
  final mode = studyModeFromString(guide.studyMode);
  return [
    if (mode != null) mode.localizedShortName(context),
    if (mode != null && withDuration) mode.localizedDuration(context),
    libraryRelativeDate(context, guide.lastAccessedAt, now: now),
  ].join(' · ');
}

/// "5 min ago" today, "Yesterday", a weekday within the week, else "Sep 21".
String libraryRelativeDate(BuildContext context, DateTime date,
    {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;

  if (days <= 0) {
    final diff = current.difference(date);
    if (diff.inHours > 0) {
      return context.tr(TranslationKeys.recentGuidesHoursAgo,
          {'count': diff.inHours.toString()});
    }
    if (diff.inMinutes > 0) {
      return context.tr(TranslationKeys.recentGuidesMinutesAgo,
          {'count': diff.inMinutes.toString()});
    }
    return context.tr(TranslationKeys.recentGuidesJustNow);
  }
  if (days == 1) return context.tr(TranslationKeys.savedGuidesYesterday);

  final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  try {
    return days < 7
        ? DateFormat.E(locale).format(date)
        : DateFormat.MMMd(locale).format(date);
  } catch (_) {
    // Date symbols for this locale not loaded (no flutter_localizations
    // ancestor, e.g. isolated widgets): fall back to intl's built-in default.
    return days < 7
        ? DateFormat.E().format(date)
        : DateFormat.MMMd().format(date);
  }
}

/// A guide in the library grid: type icon + label and bookmark on top, then
/// the title and "mode · date", on a card tinted by [tintIndex].
///
/// Sizes to its content; the grid gives cards in one row equal heights.
class GuideListItem extends StatelessWidget {
  final SavedGuideEntity guide;
  final VoidCallback onTap;

  /// Removes the guide from Saved (Saved tab; shown when [showRemoveOption]).
  final VoidCallback? onRemove;

  /// Saves a guide that is not saved yet (Recent tab).
  final VoidCallback? onSave;
  final bool showRemoveOption;
  final bool isLoading;

  /// Position in the grid; picks the card tint.
  final int tintIndex;

  /// Injectable clock for the date label (tests).
  final DateTime? now;

  const GuideListItem({
    super.key,
    required this.guide,
    required this.onTap,
    this.onRemove,
    this.onSave,
    this.showRemoveOption = false,
    this.isLoading = false,
    this.tintIndex = 0,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final tint = kLibraryCardTints[tintIndex % kLibraryCardTints.length];
    final radius = BorderRadius.circular(20);
    final kind = guide.libraryKind;

    final (IconData kindIcon, String kindLabel) = switch (kind) {
      LibraryGuideKind.scripture => (
          Icons.menu_book_outlined,
          context.tr(TranslationKeys.generateStudyScriptureTab),
        ),
      LibraryGuideKind.question => (
          Icons.help_outline_rounded,
          context.tr(TranslationKeys.generateStudyQuestionMode),
        ),
      LibraryGuideKind.topic => (
          Icons.lightbulb_outline_rounded,
          context.tr(TranslationKeys.generateStudyTopicMode),
        ),
    };

    return Semantics(
      button: true,
      label: guide.displayTitle,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: tint.withValues(alpha: palette.isDark ? 0.26 : 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: palette.isDark ? 0.32 : 0.13),
                tint.withValues(alpha: palette.isDark ? 0.08 : 0.02),
              ],
            ),
          ),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            child: Opacity(
              opacity: isLoading ? 0.6 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(kindIcon, size: 17, color: palette.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            kindLabel,
                            style: AppFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: palette.muted,
                            ),
                          ),
                        ),
                        _buildBookmark(context, palette),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        guide.displayTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                    ),
                    // Summary preview (guide content; may ellipsize).
                    if (guide.contentPreview.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          guide.contentPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            color: palette.muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        libraryGuideMeta(context, guide,
                            now: now, withDuration: true),
                        style: AppFonts.inter(
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Filled gold bookmark for saved guides (tap to remove on the Saved tab),
  /// outline for unsaved ones (tap to save on the Recent tab).
  Widget _buildBookmark(BuildContext context, ReaderPalette palette) {
    final VoidCallback? action;
    final String? tooltip;
    if (showRemoveOption && onRemove != null) {
      action = onRemove;
      tooltip = context.tr(TranslationKeys.savedGuidesRemove);
    } else if (onSave != null && !guide.isSaved) {
      action = onSave;
      tooltip = context.tr(TranslationKeys.savedGuidesSave);
    } else {
      action = null;
      tooltip = null;
    }

    final icon = Icon(
      guide.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      size: 20,
      color: palette.gold,
    );
    if (action == null) {
      return Padding(padding: const EdgeInsets.all(10), child: icon);
    }
    return IconButton(
      onPressed: isLoading ? null : action,
      tooltip: tooltip,
      icon: icon,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}
