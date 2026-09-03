import 'dart:io';

import 'package:disciplefy_bible_study/features/daily_verse/data/services/daily_verse_cache_service.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logout calls a global `Hive.close()` (LocalStoreRepositoryImpl.clearAll),
/// which closes every open box. Services that cached a Box reference used to
/// keep the closed handle and threw "Box has already been closed" on the next
/// write, silently losing the cache for the rest of the session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_logout_test');
    Hive.init(dir.path);
    SharedPreferences.setMockInitialValues({});
    // The service calls Hive.initFlutter() (which needs path_provider) unless
    // an adapter is already registered, so stand one in for the test.
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(_NoopAdapter());
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  DailyVerseEntity verse(DateTime date) => DailyVerseEntity(
        id: 'test-id',
        reference: 'John 3:16',
        referenceTranslations: const ReferenceTranslations(
          en: 'John 3:16',
          hi: 'John 3:16',
          ml: 'John 3:16',
        ),
        translations: const DailyVerseTranslations(
          esv: 'For God so loved the world...',
          hindi: '',
          malayalam: '',
        ),
        date: date,
      );

  test('cacheVerse still works after a global Hive.close()', () async {
    final service = DailyVerseCacheService();
    await service.initialize();

    final today = DateTime(2026, 9, 2);
    await service.cacheVerse(verse(today));
    expect(await service.getCachedVerse(today), isNotNull);

    // Simulate logout closing every box underneath the service.
    await Hive.close();

    // Previously threw: "HiveError: Box has already been closed."
    await service.cacheVerse(verse(today));
    expect(await service.getCachedVerse(today), isNotNull);
  });
}

class _Noop {}

class _NoopAdapter extends TypeAdapter<_Noop> {
  @override
  final int typeId = 0;

  @override
  _Noop read(BinaryReader reader) => _Noop();

  @override
  void write(BinaryWriter writer, _Noop obj) {}
}
