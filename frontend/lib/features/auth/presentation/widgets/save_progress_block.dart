import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_link_panel.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_level_style.dart';

/// Sign-up block on "Lesson complete" for a guest: a title and the Google /
/// Apple / email buttons, with "Not now" when [onNotNow] is given.
///
/// On the last lesson of the path it also lists [nextPaths] ("Your next
/// paths"), each with "Sign up to start", which opens the account sheet.
class SaveProgressBlock extends StatelessWidget {
  /// Hides the block and keeps the guest going. No "Not now" when null.
  final VoidCallback? onNotNow;

  /// Translation key of the title.
  final String titleKey;

  /// Up to two paths the guest could start next.
  final List<LearningPath> nextPaths;

  const SaveProgressBlock({
    super.key,
    this.onNotNow,
    this.titleKey = TranslationKeys.accountSaveProgressTitle,
    this.nextPaths = const [],
  });

  /// Boxed unless it is lesson 1's block (the one with "Not now").
  bool get boxed => onNotNow == null;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('save_progress_block'),
            // Lesson 1: the sign-up block stands on the page, centred. At the
            // end of a path it is a card above the next paths.
            padding: boxed
                ? const EdgeInsets.fromLTRB(14, 14, 14, 10)
                : EdgeInsets.zero,
            decoration: boxed
                ? BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.hairline),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(titleKey),
                  textAlign: boxed ? TextAlign.start : TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: boxed ? 15 : 15.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                AccountLinkPanel(
                  onLinked: (_) =>
                      GoRouter.maybeOf(context)?.go(AppRoutes.home),
                ),
                if (onNotNow != null)
                  TextButton(
                    key: const Key('save_progress_not_now'),
                    onPressed: () {
                      ActivationAnalytics.maybeTrack(
                          NuxEvent.guestContinued, {'source': 'save_progress'});
                      onNotNow!();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: palette.muted,
                      minimumSize: const Size.fromHeight(40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    child: Text(context.tr(TranslationKeys.accountNotNow)),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
          if (nextPaths.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              context.tr(TranslationKeys.accountNextPaths).toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: palette.gold,
              ),
            ),
            const SizedBox(height: 6),
            for (final path in nextPaths.take(2)) _NextPathRow(path: path),
          ],
        ],
      ),
    );
  }
}

class _NextPathRow extends StatelessWidget {
  final LearningPath path;

  const _NextPathRow({required this.path});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      key: Key('next_path_${path.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: PathLevelStyle.gradientFor(path.discipleLevel),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              iconForPath(path.iconName, category: path.category),
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                Text(
                  context.tr(TranslationKeys.accountLessonsCount,
                      {'n': path.topicsCount}),
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: () =>
                  AccountNeededSheet.show(context, AccountReason.otherPath),
              icon: Icon(Icons.lock_outline_rounded,
                  size: 14, color: palette.ctaInk),
              label: Text(
                context.tr(TranslationKeys.accountSignUpToStart),
                maxLines: 1,
              ),
              style: OutlinedButton.styleFrom(
                // A solid pill, as in the design: the one action per path.
                foregroundColor: palette.ctaInk,
                backgroundColor: palette.ctaFill,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
                textStyle:
                    AppFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line dismissible card after every lesson that has no sign-up block:
/// "Keep these {n} days
/// safe · Sign up to keep them →".
class KeepProgressCard extends StatelessWidget {
  final int days;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const KeepProgressCard({
    super.key,
    required this.days,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('keep_progress_card'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.cloud_upload_outlined,
                      size: 18, color: palette.gold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        days == 1
                            ? context.tr(TranslationKeys.accountKeepDaySafe)
                            : context.tr(TranslationKeys.accountKeepDaysSafe,
                                {'n': days}),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.tr(TranslationKeys.accountKeepCta)} →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('keep_progress_dismiss'),
                  onPressed: onDismiss,
                  tooltip: context.tr(TranslationKeys.accountDismiss),
                  icon:
                      Icon(Icons.close_rounded, size: 18, color: palette.muted),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
