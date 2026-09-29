import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/language_cache_coordinator.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/auth_service.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_service.dart';

import 'content_language_independence_test.mocks.dart';

/// App language (menus) and content language (study guides, paths, daily
/// verses) are separate settings. Changing the app language must not wipe a
/// content language the user chose; "Default" follows the app language.
@GenerateMocks([
  AuthService,
  AuthStateProvider,
  UserProfileService,
  LanguageCacheCoordinator,
])
void main() {
  late LanguagePreferenceService service;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_language_preference': 'en'});
    prefs = await SharedPreferences.getInstance();

    // Signed out: the save stays local, no server round-trip.
    final authState = MockAuthStateProvider();
    when(authState.isAuthenticated).thenReturn(false);
    when(authState.userId).thenReturn(null);

    service = LanguagePreferenceService(
      prefs: prefs,
      authService: MockAuthService(),
      authStateProvider: authState,
      userProfileService: MockUserProfileService(),
      cacheCoordinator: MockLanguageCacheCoordinator(),
    );
  });

  tearDown(() => service.dispose());

  test('an explicit content language survives an app-language change',
      () async {
    await service.saveStudyContentLanguage(AppLanguage.malayalam);

    await service.saveLanguagePreference(AppLanguage.hindi);

    expect(await service.isStudyContentLanguageDefault(), isFalse);
    expect(await service.getStudyContentLanguage(), AppLanguage.malayalam);
  });

  test('an explicit content language emits nothing on an app-language change',
      () async {
    await service.saveStudyContentLanguage(AppLanguage.malayalam);
    final emitted = <AppLanguage>[];
    final sub = service.studyContentLanguageChanges.listen(emitted.add);

    await service.saveLanguagePreference(AppLanguage.hindi);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, isEmpty);
    await sub.cancel();
  });

  test('content on Default follows the app language and announces it',
      () async {
    await service.saveStudyContentLanguage(null);
    await Future<void>.delayed(Duration.zero);
    final emitted = <AppLanguage>[];
    final sub = service.studyContentLanguageChanges.listen(emitted.add);

    await service.saveLanguagePreference(AppLanguage.hindi);
    await Future<void>.delayed(Duration.zero);

    expect(await service.isStudyContentLanguageDefault(), isTrue);
    expect(await service.getStudyContentLanguage(), AppLanguage.hindi);
    expect(emitted, [AppLanguage.hindi]);
    await sub.cancel();
  });
}
