import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/features/auth/data/repositories/local_store_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStoreRepositoryImpl.clearSharedPreferences', () {
    test('preserves language preferences across logout', () async {
      SharedPreferences.setMockInitialValues({
        'user_language_preference': 'hi',
        'has_completed_language_selection': true,
        'study_content_language': 'default',
        'user_id': 'abc-123',
        'auth_token': 'token',
      });

      final repository = LocalStoreRepositoryImpl();
      await repository.clearSharedPreferences();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_language_preference'), 'hi');
      expect(prefs.getBool('has_completed_language_selection'), true);
      expect(prefs.getString('study_content_language'), 'default');
      expect(prefs.getString('user_id'), isNull);
      expect(prefs.getString('auth_token'), isNull);
    });

    test('clears everything when no language keys are set', () async {
      SharedPreferences.setMockInitialValues({
        'user_id': 'abc-123',
      });

      final repository = LocalStoreRepositoryImpl();
      await repository.clearSharedPreferences();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
