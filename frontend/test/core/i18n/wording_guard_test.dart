import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_en.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_hi.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_ml.dart';

Iterable<MapEntry<String, String>> flatten(Map<String, dynamic> m,
    [String p = '']) sync* {
  for (final e in m.entries) {
    final k = p.isEmpty ? e.key : '$p.${e.key}';
    if (e.value is Map<String, dynamic>) {
      yield* flatten(e.value as Map<String, dynamic>, k);
    } else if (e.value is String) {
      yield MapEntry(k, e.value as String);
    }
  }
}

/// Namespaces shown to new users. Later phases add theirs here.
const guardedNamespaces = [
  'home',
  'home_today',
  'learning_paths',
  'lesson',
  'generate_simple',
  'credits',
  'plan',
  'tokens',
  'first_run',
  'account',
  'nfy',
  'intro',
  'topics',
  'all_paths',
  'memory',
];

/// Known exceptions, each to be removed once its widget stops showing it.
/// `learning_paths.xp` is the unit after a path's XP total on the path card
/// and the fellowship path picker (widget change, not wording).
const allowedXpKeys = {'learning_paths.xp'};

/// Keys that name path items; these must say "lesson", never "topic".
const pathItemKeys = [
  'learning_paths.',
  'learning_path.',
  'home.topics_progress',
  'home.start_here',
];

/// Placeholders such as `{tokens}` are not user-visible words.
String _visible(String v) => v.replaceAll(RegExp(r'\{[^}]*\}'), '');

void main() {
  bool guarded(String k) => guardedNamespaces.any((n) => k.startsWith('$n.'));

  test(
      'English: credits not tokens, lessons not topics in paths, '
      'no XP on new-user surfaces, no "AI"', () {
    final bad = <String>[];
    for (final e in flatten(englishTranslations).where((e) => guarded(e.key))) {
      final v = _visible(e.value);
      if (RegExp(r'\btokens?\b', caseSensitive: false).hasMatch(v)) {
        bad.add('${e.key}: token');
      }
      if (RegExp(r'\bXP\b').hasMatch(v) &&
          !e.key.contains('leaderboard') &&
          !allowedXpKeys.contains(e.key)) {
        bad.add('${e.key}: XP');
      }
      if (RegExp(r'\bAI\b').hasMatch(v)) bad.add('${e.key}: AI');
    }
    for (final e in flatten(englishTranslations)
        .where((e) => pathItemKeys.any(e.key.startsWith))) {
      if (RegExp(r'\btopics?\b', caseSensitive: false)
          .hasMatch(_visible(e.value))) {
        bad.add('${e.key}: topic');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('no "AI" in any user copy, in any language', () {
    final bad = [
      for (final m in [
        englishTranslations,
        hindiTranslations,
        malayalamTranslations,
      ])
        ...flatten(m)
            .where((e) => RegExp(r'\bAI\b').hasMatch(_visible(e.value)))
            .map((e) => e.key),
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('Hindi uses one memory-verse term (याद वचन) and no स्ट्रीक', () {
    const oldTerms = [
      'याद वर्सेज',
      'स्मृति आयत',
      'स्मृति वचन',
      'स्मरण पद',
      'याद आयत',
      'मेमोरी डेक',
    ];
    final values = flatten(hindiTranslations).map((e) => e.value);
    expect(values.where((v) => oldTerms.any(v.contains)), isEmpty);
    expect(values.where((v) => v.contains('स्ट्रीक')), isEmpty);
  });

  test('Malayalam uses one memory-verse term (സ്മരണ വാക്യം)', () {
    const oldTerms = [
      'മെമ്മറി വേഴ്',
      'മെമ്മറി വെർസ',
      'മെമ്മറി വചന',
      'മെമ്മറി വാക്യ',
      'മെമ്മറി ഡെക്ക',
      'ഓർമ്മ വാക്യ',
      'ഓർമ്മ വചന',
      'മനഃപാഠ വാക്യ',
      'മനഃപാഠ വചന',
    ];
    final values = flatten(malayalamTranslations).map((e) => e.value);
    expect(values.where((v) => oldTerms.any(v.contains)), isEmpty);
  });

  test('every guarded en key exists in hi and ml', () {
    final hi = Map.fromEntries(flatten(hindiTranslations));
    final ml = Map.fromEntries(flatten(malayalamTranslations));
    final missing = flatten(englishTranslations)
        .where((e) => guarded(e.key))
        .where((e) => !hi.containsKey(e.key) || !ml.containsKey(e.key))
        .map((e) => e.key)
        .toList();
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
