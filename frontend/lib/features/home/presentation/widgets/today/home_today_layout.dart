import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_event.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/new_for_you_cubit.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_verse_hero.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/home_path_section.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/new_for_you_banner.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/save_progress_row.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/first_run_flags.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/models/user_profile_model.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_service.dart';

/// The path Home shows: the summary of the user's enrolled path, or null
/// when they have none yet (a featured recommendation is not their path).
ActivePathSummary? enrolledPathSummary(HomeCombinedState state) =>
    state.activeLearningPath?.isEnrolled == true
        ? state.activePathSummary
        : null;

/// Lesson mode shown on today's lesson card before the person picks one:
/// Quick for lesson 1 after the first-run goal, else [saved] (the
/// learning-path preference, see [resolveNextLessonMode]).
StudyMode defaultTodayLessonMode({
  required ActivePathSummary? summary,
  required bool hasFirstRunGoal,
  required StudyMode saved,
}) {
  if (summary?.next?.number == 1 && hasFirstRunGoal) return StudyMode.quick;
  return saved;
}

/// Saves the learning-path lesson mode [value] (a [StudyMode] name) on the
/// profile and on this device, as the lesson card's mode chip does on Home
/// and Topics. A guest without a profile row keeps it on the device only;
/// nothing is shown when either write fails.
Future<void> persistLessonModePreference(String value) async {
  try {
    await sl<LanguagePreferenceService>()
        .cacheLearningPathStudyModePreference(value);
  } catch (e) {
    Logger.warning('Today: could not cache lesson mode',
        tag: 'HOME_TODAY', context: {'error': e.runtimeType.toString()});
  }
  final auth = sl<AuthStateProvider>();
  try {
    final result = await sl<UserProfileService>()
        .updateLearningPathStudyModePreference(value);
    result.fold(
      (_) => _keepModeOnCachedProfile(auth, value),
      (profile) {
        final userId = auth.userId;
        if (userId != null) {
          auth.cacheProfile(
              userId, UserProfileModel.fromEntity(profile).toJson());
        }
      },
    );
  } catch (e) {
    Logger.warning('Today: could not save lesson mode',
        tag: 'HOME_TODAY', context: {'error': e.runtimeType.toString()});
    _keepModeOnCachedProfile(auth, value);
  }
}

/// The cached profile's mode is read before the device copy, so it must
/// carry the new mode too when the server write did not happen.
void _keepModeOnCachedProfile(AuthStateProvider auth, String value) {
  final userId = auth.userId;
  final profile = auth.userProfile;
  if (userId == null || profile == null) return;
  auth.cacheProfile(userId, {...profile, 'learning_path_study_mode': value});
}

/// Home's Today layout, in this order and nothing else: the verse hero, the
/// path section (header, progress strip, today's lesson, or the first-path
/// chooser), the "New for you" banner when there is one, and for a guest the
/// "Save progress to your account" row.
class HomeTodayLayout extends StatefulWidget {
  /// The verse-of-the-day hero, built by Home (it owns the study action).
  final Widget hero;

  const HomeTodayLayout({super.key, required this.hero});

  @override
  State<HomeTodayLayout> createState() => _HomeTodayLayoutState();
}

class _HomeTodayLayoutState extends State<HomeTodayLayout> {
  static const _sectionPadding = EdgeInsets.symmetric(horizontal: 18);
  static const _memoryWait = Duration(seconds: 4);

  late final NewForYouCubit _newForYou = sl<NewForYouCubit>();
  bool _newForYouRequested = false;

  /// The learning-path preference; [StudyMode.standard] until it is read.
  StudyMode _savedMode = StudyMode.standard;

  /// The mode picked on the card in this session, which wins over defaults.
  StudyMode? _chosenMode;

  @override
  void initState() {
    super.initState();
    _readSavedMode();
    // HomeBloc outside its combined state never reports a finished path
    // load, so the banner is worked out straight away.
    final state = context.read<HomeBloc>().state;
    if (state is! HomeCombinedState) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNewForYou(null));
    }
  }

  @override
  void dispose() {
    _newForYou.close();
    super.dispose();
  }

  Future<void> _readSavedMode() async {
    try {
      final mode = await resolveNextLessonMode();
      if (mounted) setState(() => _savedMode = mode);
    } catch (e) {
      Logger.warning('Today: lesson mode preference unavailable',
          tag: 'HOME_TODAY', context: {'error': e.runtimeType.toString()});
    }
  }

  StudyMode _modeFor(ActivePathSummary? summary) =>
      _chosenMode ??
      defaultTodayLessonMode(
        summary: summary,
        hasFirstRunGoal: FirstRunFlags.hasGoal,
        saved: _savedMode,
      );

  void _onModeChanged(StudyMode mode) {
    setState(() => _chosenMode = mode);
    unawaited(persistLessonModePreference(mode.name));
  }

  void _refreshPath() =>
      context.read<HomeBloc>().add(const LoadActiveLearningPath(
            forceRefresh: true,
          ));

  // ---------------------------------------------------------------------------
  // New for you
  // ---------------------------------------------------------------------------

  Future<void> _loadNewForYou(ActivePathSummary? summary) async {
    if (_newForYouRequested) return;
    final userId = sl<AuthStateProvider>().userId;
    // No user yet (session still starting): try again on the next path load.
    if (userId == null) return;
    _newForYouRequested = true;
    try {
      final guest = GuestRouteGate.currentUserIsGuest();
      final plan = currentPlanCode(sl<TokenBloc>().state);
      final config = sl<SystemConfigService>();
      final hidden =
          hiddenNewForYouKinds((key) => config.shouldHideFeature(key, plan));
      // A guest is only ever offered paths: no memory or fellowship calls,
      // both need an account.
      final used = guest ? const <NewForYouKind>{} : await _usedKinds();
      final eligibility = buildEligibility(
        isGuest: guest,
        firstLessonCompleted: FirstRunFlags.firstLessonCompleted ||
            (summary?.lessonsCompleted ?? 0) > 0,
        hiddenFeatures: hidden,
        usedFeatures: used,
      );
      if (!mounted) return;
      await _newForYou.load(userId, eligibility);
    } catch (e) {
      Logger.warning('Today: New for you unavailable',
          tag: 'HOME_TODAY', context: {'error': e.runtimeType.toString()});
    }
  }

  /// Features already in use. When a signal cannot be read, the feature
  /// counts as used: it is not promoted this time and can be later.
  Future<Set<NewForYouKind>> _usedKinds() async {
    final results = await Future.wait([_memoryUsed(), _fellowshipsUsed()]);
    return {
      if (results[0]) NewForYouKind.memory,
      if (results[1]) NewForYouKind.fellowships,
    };
  }

  Future<bool> _memoryUsed() async {
    try {
      final bloc = context.read<MemoryVerseBloc>();
      var state = bloc.state;
      if (state is! DueVersesLoaded && state is! MemoryVerseError) {
        state = await bloc.stream
            .firstWhere((s) => s is DueVersesLoaded || s is MemoryVerseError)
            .timeout(_memoryWait);
      }
      return state is DueVersesLoaded ? state.statistics.totalVerses > 0 : true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _fellowshipsUsed() async {
    try {
      final language =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();
      final result =
          await sl<CommunityRepository>().getFellowships(language.code);
      return result.fold((_) => true, (list) => list.isNotEmpty);
    } catch (_) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NewForYouCubit>.value(
      value: _newForYou,
      child: BlocConsumer<HomeBloc, HomeState>(
        // The path load has settled: Home is showing its data.
        listenWhen: (previous, current) =>
            current is HomeCombinedState &&
            !current.isLoadingActivePath &&
            (previous is! HomeCombinedState || previous.isLoadingActivePath),
        listener: (context, state) =>
            _loadNewForYou(enrolledPathSummary(state as HomeCombinedState)),
        builder: (context, state) {
          final home =
              state is HomeCombinedState ? state : const HomeCombinedState();
          final summary = enrolledPathSummary(home);
          return Column(
            key: const Key('home_today_layout'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.hero,
              Padding(
                padding: _sectionPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HomeEntrance(
                      index: 0,
                      child: HomePathSection(
                        key: const Key('home_today_path'),
                        summary: summary,
                        loading: home.isLoadingActivePath,
                        mode: _modeFor(summary),
                        onModeChanged: _onModeChanged,
                        onProgressMayHaveChanged: _refreshPath,
                      ),
                    ),
                    _NewForYou(pathTitle: summary?.displayTitle),
                    if (AccountGate.isActive) ...[
                      const SizedBox(height: 10),
                      SaveProgressRow(
                        key: const Key('home_today_save_progress'),
                        onTap: () =>
                            requireAccount(context, AccountReason.saveProgress),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// The banner, spaced from the lesson card only when there is one.
class _NewForYou extends StatelessWidget {
  final String? pathTitle;

  const _NewForYou({this.pathTitle});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewForYouCubit, NewForYouKind?>(
      builder: (context, kind) {
        if (kind == null) return const SizedBox.shrink();
        return BlocBuilder<DailyVerseBloc, DailyVerseState>(
          builder: (context, verse) {
            final reference = verse is DailyVerseLoaded
                ? verse.verse.getReferenceText(verse.currentLanguage)
                : null;
            return Padding(
              key: const Key('home_today_new_for_you'),
              padding: const EdgeInsets.only(top: 12),
              child: NewForYouSection(
                verseReference: reference,
                pathTitle: pathTitle,
              ),
            );
          },
        );
      },
    );
  }
}
