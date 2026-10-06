import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/study_launch_service.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocal extends Mock implements StudyLocalDataSource {}

StudyGuide cachedGuide({
  required String input,
  required String type,
  required String language,
  String? mode,
}) =>
    StudyGuide(
      id: 'g1',
      input: input,
      inputType: type,
      summary: 's',
      interpretation: 'i',
      context: 'c',
      relatedVerses: const [],
      reflectionQuestions: const [],
      prayerPoints: const [],
      language: language,
      createdAt: DateTime(2026),
      studyMode: mode,
    );

TokenStatus statusWith({
  required int total,
  bool isPremium = false,
  bool unlimited = false,
}) =>
    TokenStatus(
      availableTokens: total,
      purchasedTokens: 0,
      totalTokens: total,
      dailyLimit: 20,
      totalConsumedToday: 0,
      userPlan: isPremium ? UserPlan.premium : UserPlan.free,
      lastReset: DateTime(2026),
      nextResetTime: DateTime(2026, 1, 2),
      authenticationType: AuthenticationType.authenticated,
      isPremium: isPremium,
      unlimitedUsage: unlimited,
      canPurchaseTokens: false,
      planDescription: '',
    );

void main() {
  late _MockLocal local;
  late StudyLaunchService svc;

  setUp(() {
    local = _MockLocal();
    svc = StudyLaunchService(local);
  });

  group('decide', () {
    test('cached guide never needs credits', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async => [
            cachedGuide(
                input: 'John 3:16',
                type: 'scripture',
                language: 'en',
                mode: 'quick'),
          ]);
      expect(
        await svc.decide(
            input: 'John 3:16',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.quick,
            status: statusWith(total: 0),
            cost: 10),
        LaunchDecision.openCached,
      );
    });

    test('cache match ignores case and surrounding spaces', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async =>
          [cachedGuide(input: 'john 3:16', type: 'scripture', language: 'en')]);
      expect(
        await svc.decide(
            input: '  John 3:16 ',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.standard,
            status: statusWith(total: 0),
            cost: 10),
        LaunchDecision.openCached,
      );
    });

    test('a guide in another language or type is not a cache hit', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async => [
            cachedGuide(input: 'John 3:16', type: 'scripture', language: 'hi'),
            cachedGuide(input: 'John 3:16', type: 'topic', language: 'en'),
          ]);
      expect(
        await svc.decide(
            input: 'John 3:16',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.quick,
            status: statusWith(total: 0),
            cost: 10),
        LaunchDecision.needCredits,
      );
    });

    test('a cache read error falls through to the credit check', () async {
      when(() => local.getCachedStudyGuides()).thenThrow(Exception('hive'));
      expect(
        await svc.decide(
            input: 'Romans 8',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.quick,
            status: statusWith(total: 50),
            cost: 10),
        LaunchDecision.openNew,
      );
    });

    test('not enough credits', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async => []);
      expect(
        await svc.decide(
            input: 'Romans 8',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.standard,
            status: statusWith(total: 5),
            cost: 20),
        LaunchDecision.needCredits,
      );
    });

    test('exactly enough credits opens a new guide', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async => []);
      expect(
        await svc.decide(
            input: 'Romans 8',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.standard,
            status: statusWith(total: 20),
            cost: 20),
        LaunchDecision.openNew,
      );
    });

    test('premium never needs credits', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async => []);
      expect(
        await svc.decide(
            input: 'Romans 8',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.deep,
            status: statusWith(total: 0, isPremium: true),
            cost: 30),
        LaunchDecision.openNew,
      );
    });

    test('unlimited usage never needs credits', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async => []);
      expect(
        await svc.decide(
            input: 'Romans 8',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.deep,
            status: statusWith(total: 0, unlimited: true),
            cost: 30),
        LaunchDecision.openNew,
      );
    });

    test('unknown status or unknown cost lets the backend decide', () async {
      when(() => local.getCachedStudyGuides()).thenAnswer((_) async => []);
      expect(
        await svc.decide(
            input: 'Romans 8',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.quick,
            status: null,
            cost: 10),
        LaunchDecision.openNew,
      );
      expect(
        await svc.decide(
            input: 'Romans 8',
            type: 'scripture',
            language: 'en',
            mode: StudyMode.quick,
            status: statusWith(total: 0),
            cost: 0),
        LaunchDecision.openNew,
      );
    });
  });

  test('location encodes input', () {
    expect(
      svc.location(
          input: 'What is grace?',
          type: 'question',
          language: 'ml',
          mode: StudyMode.quick),
      '/study-guide-v2?input=What%20is%20grace%3F&type=question&language=ml&mode=quick&source=generate',
    );
  });
}
