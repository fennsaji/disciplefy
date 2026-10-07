import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/usecases/get_daily_verse.dart';
import 'package:disciplefy_bible_study/features/home/data/services/feature_intro_source_impl.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/feature_intro_source.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/add_verse_from_daily.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

class _MockPaths extends Mock implements LearningPathsRepository {}

class _MockGetDailyVerse extends Mock implements GetDailyVerse {}

class _MockAdd extends Mock implements AddVerseFromDaily {}

class _MockCommunity extends Mock implements CommunityRepository {}

const _verse =
    IntroVerse(id: 'v1', text: 't', reference: 'Psalm 23:1', language: 'en');

PublicFellowshipEntity _f(String id, {bool official = true}) =>
    PublicFellowshipEntity(
      id: id,
      name: id,
      language: 'en',
      memberCount: 1,
      maxMembers: null,
      isOfficial: official,
    );

void main() {
  late _MockAdd add;
  late _MockCommunity community;
  late FeatureIntroSourceImpl source;

  setUp(() {
    add = _MockAdd();
    community = _MockCommunity();
    source = FeatureIntroSourceImpl(
      paths: _MockPaths(),
      getDailyVerse: _MockGetDailyVerse(),
      addVerseFromDaily: add,
      community: community,
    );
  });

  void addReturns(Failure failure) =>
      when(() => add(any(), language: any(named: 'language')))
          .thenAnswer((_) async => Left(failure));

  group('saveVerse', () {
    test('already saved counts as saved', () async {
      addReturns(const ServerFailure(code: 'VERSE_ALREADY_EXISTS'));
      expect(await source.saveVerse(_verse), isTrue);
    });

    test('queued offline counts as saved', () async {
      addReturns(const NetworkFailure());
      expect(await source.saveVerse(_verse), isTrue);
    });

    test('any other failure is not saved', () async {
      addReturns(const ServerFailure());
      expect(await source.saveVerse(_verse), isFalse);
    });

    test('a throw is not saved', () async {
      when(() => add(any(), language: any(named: 'language')))
          .thenThrow(Exception('boom'));
      expect(await source.saveVerse(_verse), isFalse);
    });
  });

  test('officialFellowships keeps official groups only', () async {
    when(() => community.discoverFellowships(limit: any(named: 'limit')))
        .thenAnswer((_) async => Right(DiscoverPage(
              fellowships: [_f('a'), _f('b', official: false), _f('c')],
              hasMore: false,
            )));
    expect((await source.officialFellowships()).map((f) => f.id), ['a', 'c']);
  });

  test('joinFellowship reports failure as false', () async {
    when(() => community.joinPublicFellowship('a'))
        .thenAnswer((_) async => const Left(ServerFailure()));
    expect(await source.joinFellowship('a'), isFalse);
  });
}
