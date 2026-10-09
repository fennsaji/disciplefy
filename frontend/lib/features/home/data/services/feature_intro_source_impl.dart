import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/usecases/get_daily_verse.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/feature_intro_source.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/first_path_choices.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/add_verse_from_daily.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

/// [FeatureIntroSource] over the existing repositories and use cases.
class FeatureIntroSourceImpl implements FeatureIntroSource {
  static const String _tag = 'FEATURE_INTRO';

  final LearningPathsRepository _paths;
  final GetDailyVerse _getDailyVerse;
  final AddVerseFromDaily _addVerseFromDaily;
  final CommunityRepository _community;

  FeatureIntroSourceImpl({
    required LearningPathsRepository paths,
    required GetDailyVerse getDailyVerse,
    required AddVerseFromDaily addVerseFromDaily,
    required CommunityRepository community,
  })  : _paths = paths,
        _getDailyVerse = getDailyVerse,
        _addVerseFromDaily = addVerseFromDaily,
        _community = community;

  @override
  Future<List<LearningPath>> startPaths({
    required bool guest,
    required String language,
  }) async {
    try {
      final result = await _paths.getLearningPaths(
        language: language,
        limit: 20,
      );
      return result.fold((failure) {
        _warn('Start paths failed', failure);
        return const [];
      }, (r) => selectFirstPaths(r.paths, guest: guest, limit: 2));
    } catch (e) {
      _warnType('Start paths threw', e);
      return const [];
    }
  }

  @override
  Future<IntroVerse?> todaysVerse(String language) async {
    final verseLanguage = switch (language) {
      'hi' => VerseLanguage.hindi,
      'ml' => VerseLanguage.malayalam,
      _ => VerseLanguage.english,
    };
    try {
      final result =
          await _getDailyVerse(GetDailyVerseParams.today(verseLanguage));
      return result.fold((failure) {
        _warn('Daily verse failed', failure);
        return null;
      }, (verse) {
        final text = verse.getVerseText(verseLanguage).trim();
        if (text.isEmpty) return null;
        return IntroVerse(
          id: verse.id,
          text: text,
          reference: verse.getReferenceText(verseLanguage),
          language: verseLanguage.code,
        );
      });
    } catch (e) {
      _warnType('Daily verse threw', e);
      return null;
    }
  }

  @override
  Future<bool> saveVerse(IntroVerse verse) async {
    try {
      final result =
          await _addVerseFromDaily(verse.id, language: verse.language);
      return result.fold((failure) {
        // Already in the deck, or queued to sync while offline: either way
        // the verse will be there to practise.
        if (failure.code == 'VERSE_ALREADY_EXISTS' ||
            failure is NetworkFailure) {
          return true;
        }
        _warn('Save verse failed', failure);
        return false;
      }, (_) => true);
    } catch (e) {
      _warnType('Save verse threw', e);
      return false;
    }
  }

  @override
  Future<List<PublicFellowshipEntity>> officialFellowships() async {
    try {
      final result = await _community.discoverFellowships(limit: 20);
      return result.fold((failure) {
        _warn('Fellowship discovery failed', failure);
        return const [];
      }, (page) => page.fellowships.where((f) => f.isOfficial).toList());
    } catch (e) {
      _warnType('Fellowship discovery threw', e);
      return const [];
    }
  }

  @override
  Future<bool> joinFellowship(String id) async {
    try {
      final result = await _community.joinPublicFellowship(id);
      return result.fold((failure) {
        _warn('Join fellowship failed', failure);
        return false;
      }, (_) => true);
    } catch (e) {
      _warnType('Join fellowship threw', e);
      return false;
    }
  }

  void _warn(String message, Failure failure) =>
      Logger.warning(message, tag: _tag, context: {'code': failure.code});

  void _warnType(String message, Object e) => Logger.warning(message,
      tag: _tag, context: {'type': e.runtimeType.toString()});
}
