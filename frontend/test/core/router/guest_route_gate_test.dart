import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';

void main() {
  test('every gated prefix and its reason', () {
    expect(GuestRouteGate.gatedPrefixes, {
      '/generate-study': 'generate',
      '/token-management': 'generate',
      '/premium-upgrade': 'generate',
      '/plus-upgrade': 'generate',
      '/standard-upgrade': 'generate',
      '/subscription-management': 'generate',
      '/my-plan': 'generate',
      '/pricing': 'generate',
      '/discipler': 'discipler',
      '/voice-conversation': 'discipler',
      '/voice-preferences': 'discipler',
      '/community': 'community',
      '/fellowship': 'community',
      '/memory-verses': 'memory_verses',
      '/memory-verse-review': 'memory_verses',
      '/intro/memory': 'memory_verses',
      '/intro/generate': 'generate',
      '/intro/discipler': 'discipler',
      '/intro/fellowships': 'community',
    });
  });

  group('gated', () {
    const gated = {
      AppRoutes.generateStudy: 'generate',
      AppRoutes.tokenManagement: 'generate',
      AppRoutes.tokenPurchase: 'generate',
      AppRoutes.purchaseHistory: 'generate',
      AppRoutes.usageHistory: 'generate',
      AppRoutes.premiumUpgrade: 'generate',
      AppRoutes.plusUpgrade: 'generate',
      AppRoutes.standardUpgrade: 'generate',
      AppRoutes.subscriptionManagement: 'generate',
      AppRoutes.myPlan: 'generate',
      AppRoutes.subscriptionPaymentHistory: 'generate',
      AppRoutes.pricing: 'generate',
      AppRoutes.discipler: 'discipler',
      AppRoutes.voiceConversation: 'discipler',
      AppRoutes.voicePreferences: 'discipler',
      AppRoutes.community: 'community',
      AppRoutes.communityJoin: 'community',
      AppRoutes.communityCreate: 'community',
      '/community/f1': 'community',
      '/community/f1/feed': 'community',
      '/community/f1/post/p1': 'community',
      '/fellowship/join/tok': 'community',
      '/fellowship/f1/post/p1': 'community',
      AppRoutes.memoryVerses: 'memory_verses',
      AppRoutes.verseReview: 'memory_verses',
      '/memory-verses/practice/v1': 'memory_verses',
      '/memory-verses/practice/word-bank/v1': 'memory_verses',
      '/memory-verses/practice/results': 'memory_verses',
      AppRoutes.memoryChampions: 'memory_verses',
      AppRoutes.memoryStats: 'memory_verses',
      '/intro/memory': 'memory_verses',
      '/intro/generate': 'generate',
      '/intro/discipler': 'discipler',
      '/intro/fellowships': 'community',
    };
    for (final entry in gated.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(GuestRouteGate.reasonFor(entry.key), entry.value);
      });
    }
  });

  group('open', () {
    const open = [
      AppRoutes.home,
      AppRoutes.studyTopics,
      AppRoutes.settings,
      AppRoutes.bibleAttribution,
      AppRoutes.notificationSettings,
      AppRoutes.statsDashboard,
      AppRoutes.reflectionJournal,
      AppRoutes.saved,
      AppRoutes.studyGuide,
      '/study-guide/g1',
      AppRoutes.studyGuideV2,
      AppRoutes.lessonComplete,
      '/learning-path/p1',
      '/learning-paths/category/faith',
      AppRoutes.dailyVerseShared,
      AppRoutes.leaderboard,
      AppRoutes.languageSelection,
      AppRoutes.login,
      AppRoutes.emailAuth,
      AppRoutes.authCallback,
      AppRoutes.welcome,
      AppRoutes.welcomeGoal,
      // A guest is introduced to learning paths only.
      '/intro/paths',
      // Shares characters with a gated prefix but is a different route.
      '/communityx',
      '/memory-versesx',
    ];
    for (final path in open) {
      test('$path is open', () {
        expect(GuestRouteGate.reasonFor(path), isNull);
      });
    }
  });

  test('query string and fragment are ignored', () {
    expect(GuestRouteGate.reasonFor('/community?x=1'), 'community');
    expect(GuestRouteGate.reasonFor('/discipler#a'), 'discipler');
  });

  test('homeWithReason', () {
    expect(GuestRouteGate.homeWithReason(AccountReasons.otherPath),
        '/?account=other_path');
  });
}
