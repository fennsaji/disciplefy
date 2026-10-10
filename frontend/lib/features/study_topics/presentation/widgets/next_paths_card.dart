import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/next_path_row.dart';

/// Which heading [NextPathsCard] shows.
enum NextPathsCardMode {
  /// "What next?": a path was just finished.
  whatNext,

  /// "Choose your first path", unless the server reports a finished path,
  /// which turns it into "What next?".
  firstPath,
}

/// Up to three paths to study next, from the server's next-path engine
/// (active path, then the growth goal's paths, then featured; a guest only
/// gets guest-accessible ones). Each row opens the path; "See all paths"
/// opens Topics. Calm and never blocking: a failed load shows a Retry link.
///
/// A guest with no guest path left gets one row that opens the account sheet.
class NextPathsCard extends StatefulWidget {
  final NextPathsCardMode mode;

  /// The path just finished, never listed (the server skips it too).
  final String? excludePathId;

  /// Where the path page was opened from (`source=` on its route).
  final String source;

  /// Called when a path page reports a change (enrolled, lesson done).
  final VoidCallback? onPathChanged;

  /// Content language; the app language when null.
  final String? language;

  const NextPathsCard({
    super.key,
    this.mode = NextPathsCardMode.whatNext,
    this.excludePathId,
    this.source = 'home',
    this.onPathChanged,
    this.language,
  });

  static const int limit = 3;

  @override
  State<NextPathsCard> createState() => _NextPathsCardState();
}

class _NextPathsCardState extends State<NextPathsCard> {
  NextPathsResult? _result;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _language =>
      widget.language ?? sl<TranslationService>().currentLanguage.code;

  Future<void> _load() async {
    final extra = widget.excludePathId == null ? 0 : 1;
    NextPathsResult? result;
    try {
      final either = await sl<LearningPathsRepository>().getNextPaths(
        language: _language,
        limit: NextPathsCard.limit + extra,
      );
      result = either.fold((failure) {
        Logger.warning('Next paths unavailable',
            tag: 'NEXT_PATHS', context: {'code': failure.code});
        return null;
      }, (r) => r);
    } catch (e) {
      Logger.warning('Next paths threw',
          tag: 'NEXT_PATHS', context: {'type': e.runtimeType.toString()});
    }
    if (!mounted) return;
    setState(() {
      _failed = result == null;
      _result = result;
    });
  }

  void _retry() {
    setState(() {
      _failed = false;
      _result = null;
    });
    _load();
  }

  List<LearningPath> get _paths => (_result?.paths ?? const <LearningPath>[])
      .where((p) => p.id != widget.excludePathId)
      .take(NextPathsCard.limit)
      .toList();

  bool get _whatNext =>
      widget.mode == NextPathsCardMode.whatNext ||
      _result?.finishedPath != null;

  void _open(LearningPath path) {
    guestPathGate(context, path, () async {
      if (!mounted) return;
      final changed = await context
          .push<bool>('/learning-path/${path.id}?source=${widget.source}');
      if (changed == true) widget.onPathChanged?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final loading = _result == null && !_failed;
    final paths = _paths;
    final guest = AccountGate.isActive;
    return Container(
      key: Key(_whatNext ? 'next_paths_what_next' : 'next_paths_first_path'),
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
          Semantics(
            header: true,
            child: Text(
              context.tr(_whatNext
                  ? TranslationKeys.goalWhatNext
                  : TranslationKeys.homeTodayChooseFirstPath),
              style: AppFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.text,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(_whatNext
                ? TranslationKeys.goalWhatNextSub
                : TranslationKeys.homeTodayChooseFirstPathSub),
            style: AppFonts.inter(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 8),
          if (loading)
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
          else if (_failed)
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(TranslationKeys.homeTodayPathsUnavailable),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.inter(fontSize: 13, color: palette.muted),
                  ),
                ),
                TextButton(
                  key: const Key('next_paths_retry'),
                  onPressed: _retry,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.gold,
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text(context.tr(TranslationKeys.commonRetry)),
                ),
              ],
            )
          else if (paths.isEmpty && guest)
            _GuestMoreRow(
              onTap: () => requireAccount(context, AccountReason.otherPath),
            )
          else
            for (var i = 0; i < paths.length; i++) ...[
              if (i > 0) Divider(height: 1, color: palette.hairline),
              NextPathRow(
                key: Key('next_path_${paths[i].slug}'),
                path: paths[i],
                onTap: () => _open(paths[i]),
              ),
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
                  Flexible(
                    child:
                        Text(context.tr(TranslationKeys.homeTodaySeeAllPaths)),
                  ),
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

/// A guest with no guest path left: one row that opens the account sheet.
class _GuestMoreRow extends StatelessWidget {
  final VoidCallback onTap;

  const _GuestMoreRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return InkWell(
      key: const Key('next_paths_guest_account'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.lock_open_rounded, size: 20, color: palette.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(TranslationKeys.goalMorePathsAccount),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.dim),
          ],
        ),
      ),
    );
  }
}
