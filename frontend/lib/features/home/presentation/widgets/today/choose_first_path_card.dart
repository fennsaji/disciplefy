import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/first_path_choices.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_level_style.dart';

/// "Choose your first path": shown on Home when the user has no path yet.
///
/// Lists up to three paths ([selectFirstPaths]): the first-run goal's path
/// first, then the guest starter paths for a guest or featured paths for
/// everyone else. Each row opens the path; "See all paths" opens Topics.
class ChooseFirstPathCard extends StatefulWidget {
  /// The stored first-run goal ([GrowthGoal.name]). Read from Hive
  /// `app_settings` when null.
  final String? firstRunGoal;

  const ChooseFirstPathCard({super.key, this.firstRunGoal});

  @override
  State<ChooseFirstPathCard> createState() => _ChooseFirstPathCardState();
}

class _ChooseFirstPathCardState extends State<ChooseFirstPathCard> {
  static const int _pageSize = 20;
  static const int _maxPages = 4;
  static const String _settingsBox = 'app_settings';

  List<LearningPath>? _paths;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _goalSlug() {
    Object? name = widget.firstRunGoal;
    if (name == null) {
      try {
        if (Hive.isBoxOpen(_settingsBox)) {
          name = Hive.box(_settingsBox).get(FirstRunCubit.goalKey);
        }
      } catch (_) {
        name = null;
      }
    }
    return GrowthGoal.fromName(name)?.pathSlug;
  }

  Future<void> _load() async {
    final guest = AccountGate.isActive;
    final goalSlug = _goalSlug();
    final language = sl<TranslationService>().currentLanguage.code;
    final repository = sl<LearningPathsRepository>();
    final listed = <LearningPath>[];
    var offset = 0;
    try {
      for (var page = 0; page < _maxPages; page++) {
        final result = await repository.getLearningPaths(
          language: language,
          offset: offset,
          limit: _pageSize,
        );
        final LearningPathsResult? data = result.fold((failure) {
          Logger.warning('Home first-path list failed',
              tag: 'HOME', context: {'code': failure.code});
          return null;
        }, (r) => r);
        if (data == null) break;
        listed.addAll(data.paths);
        offset += data.paths.length;
        if (!data.hasMore ||
            data.paths.isEmpty ||
            _enough(listed, guest, goalSlug)) {
          break;
        }
      }
    } catch (e) {
      Logger.warning('Home first-path list threw',
          tag: 'HOME', context: {'type': e.runtimeType.toString()});
    }
    if (!mounted) return;
    setState(() {
      _paths = selectFirstPaths(listed, guest: guest, goalSlug: goalSlug);
    });
  }

  /// True once every path the card could show has been seen.
  bool _enough(List<LearningPath> listed, bool guest, String? goal) {
    final slugs = listed.map((p) => p.slug).toSet();
    if (guest) return guestStarterSlugs.every(slugs.contains);
    return (goal == null || slugs.contains(goal)) &&
        listed.where((p) => p.isFeatured).length >= 3;
  }

  void _open(LearningPath path) {
    guestPathGate(context, path, () async {
      if (!mounted) return;
      await context.push<bool>('/learning-path/${path.id}?source=home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final paths = _paths;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(TranslationKeys.homeTodayChooseFirstPath),
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(TranslationKeys.homeTodayChooseFirstPathSub),
            style: AppFonts.inter(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 8),
          if (paths == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            for (var i = 0; i < paths.length; i++) ...[
              if (i > 0) Divider(height: 1, color: palette.hairline),
              FirstPathRow(path: paths[i], onTap: () => _open(paths[i])),
            ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.studyTopics),
              style: TextButton.styleFrom(
                foregroundColor: palette.gold,
                minimumSize: const Size(0, 40),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    AppFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr(TranslationKeys.homeTodaySeeAllPaths)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon tile, title and "{n} lessons · {days} days".
class FirstPathRow extends StatelessWidget {
  final LearningPath path;
  final VoidCallback onTap;

  const FirstPathRow({super.key, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return GuestLockedPathTile(
      path: path,
      badgeAlignment: Alignment.topLeft,
      badgePadding: const EdgeInsets.only(left: 26, top: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: PathLevelStyle.gradientFor(path.discipleLevel),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconForPath(path.iconName, category: path.category),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys.homeTodayLessonsDays, {
                        'lessons': path.topicsCount,
                        'days': path.estimatedDays,
                      }),
                      style: AppFonts.inter(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.dim),
            ],
          ),
        ),
      ),
    );
  }
}
