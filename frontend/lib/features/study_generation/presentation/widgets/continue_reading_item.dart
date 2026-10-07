import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';

/// "Continue reading" card on the Generate tab: type label + icon, bookmark,
/// title, and "mode · time ago", on a card tinted by type (gold for
/// topics, a cool wash for scripture).
class GuideQuickItem extends StatelessWidget {
  final SavedGuideEntity guide;
  final VoidCallback onTap;

  /// Saves the guide; null when it is already saved (the bookmark is then
  /// shown filled and is not tappable).
  final VoidCallback? onSave;
  final bool showSaveAction;

  /// Injectable clock for the "time ago" label (tests).
  final DateTime? now;

  const GuideQuickItem({
    super.key,
    required this.guide,
    required this.onTap,
    this.onSave,
    this.showSaveAction = false,
    this.now,
  });

  static const double height = 96;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isScripture = guide.type == GuideType.verse;
    // Library tiles: a cool wash for Scripture, gold for topics and
    // questions, as the design's library grid.
    final tint = isScripture ? AppColors.info : AppColors.brandGold;
    final radius = BorderRadius.circular(18);

    final mode = studyModeFromString(guide.studyMode);
    final meta = [
      if (mode != null) mode.localizedShortName(context),
      if (mode != null) mode.localizedDuration(context),
      _timeAgo(context, guide.lastAccessedAt),
    ].join(' · ');

    return Semantics(
      button: true,
      label: guide.displayTitle,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: tint.withValues(alpha: palette.isDark ? 0.28 : 0.22),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: palette.isDark ? 0.34 : 0.12),
                tint.withValues(alpha: palette.isDark ? 0.10 : 0.03),
              ],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isScripture
                            ? Icons.menu_book_outlined
                            : Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: palette.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.tr(isScripture
                                ? TranslationKeys.generateStudyScriptureTab
                                : TranslationKeys.generateStudyTopicMode),
                            maxLines: 1,
                            style: AppFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ),
                      _Bookmark(
                        saved: guide.isSaved,
                        onSave: showSaveAction ? onSave : null,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      guide.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    // Mode · duration · when: shrinks rather than cutting.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        meta,
                        maxLines: 1,
                        style:
                            AppFonts.inter(fontSize: 12, color: palette.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

class _Bookmark extends StatelessWidget {
  final bool saved;
  final VoidCallback? onSave;

  const _Bookmark({required this.saved, this.onSave});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final icon = Icon(
      saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      size: 18,
      color: palette.accentIcon,
    );
    if (onSave == null) {
      return Padding(padding: const EdgeInsets.all(6), child: icon);
    }
    return InkResponse(
      onTap: onSave,
      radius: 18,
      child: Padding(padding: const EdgeInsets.all(6), child: icon),
    );
  }
}
