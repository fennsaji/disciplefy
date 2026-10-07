import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/error/account_required.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_state.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

/// Drives the first-run goal screen: saves the language and goal, starts a
/// guest when nobody is signed in, enrols the goal's path and hands back the
/// location of lesson 1 in Quick Read.
///
/// Never logs ids or user input; goal and slug names only.
class FirstRunCubit extends Cubit<FirstRunState> {
  final GuestSessionService _guest;
  final LearningPathsRepository _paths;
  final RolloutFlags _flags;
  final LanguagePreferenceService _language;
  final Box _settings;
  final WalkthroughRepository _walkthrough;

  /// Hive `app_settings` key of the picked goal ([GrowthGoal.name]).
  static const String goalKey = 'first_run_goal';
  static const String termsAcceptedKey = 'terms_accepted';
  static const String onboardingCompletedKey = 'onboarding_completed';

  /// Query parameter added to lesson 1's location; the guide and the
  /// complete page show the sign-up block when it is present.
  static const String firstRunParam = 'first_run';

  /// Page size and page cap when looking up the goal paths' titles.
  static const int _starterPageSize = 20;
  static const int _starterMaxPages = 4;

  FirstRunCubit({
    required GuestSessionService guest,
    required LearningPathsRepository paths,
    required RolloutFlags flags,
    required LanguagePreferenceService language,
    required Box settings,
    required WalkthroughRepository walkthrough,
  })  : _guest = guest,
        _paths = paths,
        _flags = flags,
        _language = language,
        _settings = settings,
        _walkthrough = walkthrough,
        super(const FirstRunIdle());

  /// True when the helper under the title should speak to a guest ("create
  /// an account later to unlock all paths"): guest mode is on and the person
  /// is signed out or a guest.
  bool get showsGuestHelper =>
      _flags.guestMode && (!_guest.hasSession || _guest.isGuest);

  /// Starts [goal]'s path and emits the location of lesson 1.
  ///
  /// Order: save the language (and the terms acceptance shown on this
  /// screen) → start a guest when signed out → enrol by slug → store the
  /// goal → open lesson 1. Any failure ends in [FirstRunFailed]; calling
  /// again retries (a guest created by the first attempt is reused).
  Future<void> startLessonOne(GrowthGoal goal, String language) async {
    if (state is FirstRunStarting) return;
    emit(const FirstRunStarting());
    try {
      await _start(goal, language);
    } catch (e) {
      // Never leave the screen spinning: anything unexpected is a retry.
      Logger.error('First run could not start lesson 1',
          tag: 'FIRST_RUN', error: e.runtimeType);
      _emit(const FirstRunFailed(TranslationKeys.firstRunError));
    }
  }

  Future<void> _start(GrowthGoal goal, String language) async {
    await _language.saveLanguagePreference(AppLanguage.fromCode(language));
    await _settings.putAll({
      termsAcceptedKey: true,
      onboardingCompletedKey: true,
    });

    if (!_guest.hasSession) {
      if (!_flags.guestMode) {
        await _settings.put(goalKey, goal.name);
        Logger.info('First run needs login before lesson 1',
            tag: 'FIRST_RUN', context: {'goal': goal.name});
        _emit(const FirstRunNeedsLogin());
        return;
      }
      await _guest.startGuest();
    }

    final enrolled = await _paths.enrollInPathBySlug(goal.pathSlug);
    final pathId = enrolled.fold((failure) {
      final accountRequired = isAccountRequired(failure);
      Logger.warning('First run enrolment failed', tag: 'FIRST_RUN', context: {
        'slug': goal.pathSlug,
        'code': failure.code,
      });
      _emit(accountRequired
          ? const FirstRunFailed(TranslationKeys.firstRunErrorHasPath,
              accountRequired: true)
          : const FirstRunFailed(TranslationKeys.firstRunError));
      return null;
    }, (result) => result.learningPathId);
    if (pathId == null) return;

    await _settings.put(goalKey, goal.name);

    final details = await _paths.getLearningPathDetails(
      pathId: pathId,
      language: language,
      forceRefresh: true,
    );
    final location = details.fold<String?>((failure) {
      Logger.warning('First run path details failed',
          tag: 'FIRST_RUN',
          context: {'slug': goal.pathSlug, 'code': failure.code});
      return null;
    }, (path) => _lessonOneLocation(path, language));

    if (location == null) {
      _emit(const FirstRunFailed(TranslationKeys.firstRunError));
      return;
    }
    Logger.info('First run opens lesson 1',
        tag: 'FIRST_RUN', context: {'goal': goal.name});
    await _markToursSeen();
    _emit(FirstRunReady(location));
  }

  /// First run stays quiet: no tour opens before lesson 1 is done. Writes to
  /// Hive only for a guest. A failure here must not block lesson 1.
  Future<void> _markToursSeen() async {
    for (final screen in WalkthroughScreen.values) {
      try {
        await _walkthrough.markSeen(screen);
      } catch (e) {
        Logger.warning('First run could not mark a tour seen',
            tag: 'FIRST_RUN',
            context: {'screen': screen.key, 'error': e.runtimeType.toString()});
      }
    }
  }

  /// Emits unless the screen (and so the cubit) is already gone.
  void _emit(FirstRunState next) {
    if (!isClosed) emit(next);
  }

  String? _lessonOneLocation(LearningPathDetail path, String language) {
    if (path.topics.isEmpty) return null;
    final first = path.topics.reduce((a, b) => b.position < a.position ? b : a);
    final location = buildLessonLaunchLocation(
      path: path,
      topic: first,
      mode: StudyMode.quick,
      language: language,
    );
    return '$location&$firstRunParam=1';
  }

  /// Leaves the first run with no goal: Home (or the login screen, for a
  /// signed-out person) shows "Choose your first path".
  Future<void> skip(String language) async {
    if (state is FirstRunStarting) return;
    try {
      await _language.saveLanguagePreference(AppLanguage.fromCode(language));
      await _settings.delete(goalKey);
      await _settings.put(onboardingCompletedKey, true);
    } catch (e) {
      // Skipping must always leave the screen.
      Logger.warning('First run skip could not save settings',
          tag: 'FIRST_RUN', context: {'error': e.runtimeType.toString()});
    }
    Logger.info('First run goal skipped', tag: 'FIRST_RUN');
    _emit(const FirstRunSkipped());
  }

  /// Titles and lesson counts of the goal paths, and the number of active
  /// paths. Pages through the path list until every goal path is found.
  /// Never throws: whatever could not be loaded is left out.
  Future<StarterPaths> loadStarterPaths(String language) async {
    final wanted = GrowthGoal.values.map((g) => g.pathSlug).toSet();
    final found = <String, StarterPathInfo>{};
    int? total;
    var offset = 0;
    for (var page = 0; page < _starterMaxPages; page++) {
      final result = await _paths.getLearningPaths(
        language: language,
        offset: offset,
        limit: _starterPageSize,
      );
      final LearningPathsResult? listed =
          result.fold((failure) => null, (r) => r);
      if (listed == null) break;
      total = listed.total;
      for (final path in listed.paths) {
        if (wanted.contains(path.slug)) {
          found[path.slug] = StarterPathInfo(
            title: path.title,
            lessonCount: path.topicsCount,
          );
        }
      }
      offset += listed.paths.length;
      if (found.length == wanted.length ||
          !listed.hasMore ||
          listed.paths.isEmpty) {
        break;
      }
    }
    return StarterPaths(bySlug: found, totalPaths: total);
  }
}
