import 'dart:math' as math;

import 'package:disciplefy_bible_study/core/constants/hero_images.dart';
import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/services/reading_progress_store.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';

/// Picks the guide the library's Continue card resumes: the one among
/// [guides] read most recently (by [ReadingProgress.updatedAt]) and not yet
/// finished; without any progress, the most recently accessed guide.
/// Null when [guides] is empty.
SavedGuideEntity? pickContinueGuide(
  List<SavedGuideEntity> guides,
  Map<String, ReadingProgress> progress,
) {
  if (guides.isEmpty) return null;
  SavedGuideEntity? best;
  DateTime? bestAt;
  for (final guide in guides) {
    final p = progress[guide.id];
    if (p == null || p.isComplete) continue;
    if (bestAt == null || p.updatedAt.isAfter(bestAt)) {
      best = guide;
      bestAt = p.updatedAt;
    }
  }
  if (best != null) return best;
  return guides
      .reduce((a, b) => b.lastAccessedAt.isAfter(a.lastAccessedAt) ? b : a);
}

/// Photo card at the top of the library resuming the last guide:
/// "CONTINUE · SECTION X OF Y", the title and a gold progress line, or just
/// "CONTINUE" when no progress is known. Dark scrim and white text in both
/// themes.
class LibraryContinueCard extends StatelessWidget {
  /// Same scenery as the guide's own header (keyed by its title).
  String get photoAsset => heroImageForKey(guide.title);
  static const double height = 148;

  final SavedGuideEntity guide;
  final ReadingProgress? progress;
  final VoidCallback onTap;

  const LibraryContinueCard({
    super.key,
    required this.guide,
    required this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final hasProgress = p != null && p.total > 0 && p.section > 0;
    final eyebrow = hasProgress
        ? context.tr(TranslationKeys.savedGuidesContinueSection, {
            'current': '${p.section}',
            'total': '${p.total}',
          })
        : context.tr(TranslationKeys.savedGuidesContinue);
    final radius = BorderRadius.circular(22);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Semantics(
      button: true,
      label: '$eyebrow. ${guide.displayTitle}',
      excludeSemantics: true,
      child: Material(
        color: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      photoAsset,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.2),
                      cacheWidth: math.min(2000, (width * dpr).round()),
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    // Dark bottom scrim so white text reads over the fog.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.78),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              eyebrow.toUpperCase(),
                              maxLines: 1,
                              style: AppFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppColors.brandGold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            guide.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          if (hasProgress) ...[
                            const SizedBox(height: 12),
                            _ProgressLine(fraction: p.fraction),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final double fraction;

  const _ProgressLine({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.22)),
            FractionallySizedBox(
              key: const Key('library_continue_progress_fill'),
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: const ColoredBox(color: AppColors.brandGold),
            ),
          ],
        ),
      ),
    );
  }
}
