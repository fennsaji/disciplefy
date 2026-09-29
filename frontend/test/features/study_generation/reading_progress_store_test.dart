import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/features/study_generation/data/services/reading_progress_store.dart';

void main() {
  late ReadingProgressStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = ReadingProgressStore();
  });

  test('returns null for a guide never read', () async {
    expect(await store.get('g1'), isNull);
  });

  test('saves and reads progress per guide id', () async {
    await store.save('g1', 3, 7);
    await store.save('g2', 1, 6);

    final g1 = await store.get('g1');
    expect(g1!.section, 3);
    expect(g1.total, 7);
    expect(g1.fraction, closeTo(3 / 7, 1e-9));
    expect(g1.isComplete, isFalse);
    expect((await store.get('g2'))!.section, 1);
    expect((await store.getAll()).keys, containsAll(['g1', 'g2']));
  });

  test('never moves backwards for the same total', () async {
    await store.save('g1', 5, 7);
    await store.save('g1', 2, 7);
    expect((await store.get('g1'))!.section, 5);
  });

  test('a different total replaces the entry', () async {
    await store.save('g1', 5, 7);
    await store.save('g1', 2, 6);
    final progress = (await store.get('g1'))!;
    expect(progress.section, 2);
    expect(progress.total, 6);
  });

  test('clamps the section to the total and marks complete', () async {
    await store.save('g1', 12, 7);
    final progress = (await store.get('g1'))!;
    expect(progress.section, 7);
    expect(progress.isComplete, isTrue);
  });

  test('ignores empty ids and non-positive totals', () async {
    await store.save('', 1, 7);
    await store.save('g1', 1, 0);
    expect(await store.getAll(), isEmpty);
  });

  test('remove forgets a guide', () async {
    await store.save('g1', 2, 7);
    await store.remove('g1');
    expect(await store.get('g1'), isNull);
  });

  test('survives corrupt stored data', () async {
    SharedPreferences.setMockInitialValues(
        {ReadingProgressStore.prefsKey: 'not json'});
    expect(await ReadingProgressStore().getAll(), isEmpty);
  });
}
