import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/features/auth/data/repositories/local_store_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

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

  group('LocalStoreRepositoryImpl.clearAll', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_store_test');
      Hive.init(tempDir.path);
      SharedPreferences.setMockInitialValues({});

      // clearAll() calls Hive.close() + Hive.initFlutter(), which resolves
      // the storage directory via path_provider's platform channel. That
      // channel has no plugin registered in the test environment, so mock
      // it to answer with the same temp dir Hive.init() above already uses.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (Hive.isBoxOpen('app_settings')) {
        await Hive.box('app_settings').close();
      }
      await tempDir.delete(recursive: true);
    });

    test('preserves terms_accepted across sign-out (Guideline 1.2)', () async {
      final box = await Hive.openBox('app_settings');
      await box.put('terms_accepted', true);
      // Simulate user data that must NOT survive clearAll().
      await box.put('user_id', 'abc-123');

      final repository = LocalStoreRepositoryImpl();
      await repository.clearAll();

      final restoredBox = Hive.box('app_settings');
      expect(restoredBox.get('terms_accepted', defaultValue: false), isTrue,
          reason: 'terms acceptance is a per-device Guideline 1.2 flag and '
              'must not be wiped by sign-out');
      expect(restoredBox.get('user_id'), isNull);
    });

    test('defaults terms_accepted to false when it was never set', () async {
      await Hive.openBox('app_settings');

      final repository = LocalStoreRepositoryImpl();
      await repository.clearAll();

      final restoredBox = Hive.box('app_settings');
      expect(restoredBox.get('terms_accepted', defaultValue: false), isFalse);
    });
  });
}
