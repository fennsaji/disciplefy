import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_en.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_hi.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_ml.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';

import '../../helpers/text_fit.dart';
import 'redesign_keys.dart';

/// How much wider than English a one-line hi/ml label may be.
const maxRatio = 1.3;

/// Absolute allowance on top of [maxRatio], about one Devanagari/Malayalam
/// syllable at 12-15pt. Without it every one-word label ("All", "Skip",
/// "Join") fails although the script has no shorter word.
const ratioSlack = 16.0;

/// One-line labels allowed past the ratio (never past their slot), with why.
const ratioExempt = <String, String>{
  'intro.generate.chip3:ml': 'Bible book name keeps the app translation',
  'intro.fellowships.official:ml': 'no shorter word for "Official"',
  'first_run.skip:ml': 'no shorter natural word for "Skip"',
  'first_run.retry:ml': 'standard "Try again"; full-width button',
  'generate_simple.all_depths:ml': 'two short words; nothing shorter',
  'plan.renews_on:ml': 'mostly the date; 3px over',
  'all_paths.all:ml': 'no shorter word for "All"',
  'memory.save_todays_verse:ml': 'full-width button; 5px over',
  'settings.more:ml': 'no shorter word for "More"',
};

String? lookup(String code, String key) {
  if (key.startsWith('l10n:')) {
    final l10n = AppLocalizations(Locale(code));
    final name = key.substring(5);
    if (name == 'navDiscipler') return l10n.navDiscipler;
    return l10n.navLabel(name.substring(3).toLowerCase());
  }
  dynamic cur = switch (code) {
    'hi' => hindiTranslations,
    'ml' => malayalamTranslations,
    _ => englishTranslations,
  };
  for (final part in key.split('.')) {
    if (cur is! Map) return null;
    cur = cur[part];
  }
  return cur is String ? cur.replaceAll(RegExp(r'\{[a-z_]+\}'), '88') : null;
}

double measure(String text, AuditKey k) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: AppFonts.interFamily,
        fontFamilyFallback: AppFonts.indicFallback,
        fontSize: k.fontSize,
        fontWeight: k.weight,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = tp.width;
  tp.dispose();
  return width;
}

/// One row per string that does not fit its slot, or (one-line labels) is
/// more than [maxRatio] times the English width.
List<String> offenders() {
  final rows = <String>[];
  for (final k in redesignKeys) {
    final en = lookup('en', k.key);
    if (en == null) {
      rows.add('| ${k.key} | en | MISSING | |');
      continue;
    }
    final enW = measure(en, k);
    final slot = k.singleLine ? k.maxWidth : k.maxWidth * k.lines;
    for (final code in ['hi', 'ml']) {
      final v = lookup(code, k.key);
      if (v == null) {
        rows.add('| ${k.key} | $code | MISSING | |');
        continue;
      }
      final w = measure(v, k);
      final tooWide = w > slot;
      final tooLong = k.singleLine &&
          w > enW * maxRatio + ratioSlack &&
          !ratioExempt.containsKey('${k.key}:$code');
      if (tooWide || tooLong) {
        rows.add('| ${k.key} | $code | "$v" | '
            '${w.toStringAsFixed(0)}px vs en ${enW.toStringAsFixed(0)}px '
            '(${(w / enW).toStringAsFixed(2)}x), '
            'slot ${slot.toStringAsFixed(0)}px |');
      }
    }
  }
  return rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  test('the key list has no duplicates and every exemption is listed', () {
    final keys = redesignKeys.map((k) => k.key).toList();
    expect(keys.toSet().length, keys.length);
    final stale = ratioExempt.keys
        .where((e) => !keys.contains(e.substring(0, e.lastIndexOf(':'))));
    expect(stale, isEmpty);
  });

  test('hi/ml redesign strings fit their slot and stay near 1.3x English', () {
    final rows = offenders();
    expect(
      rows,
      isEmpty,
      reason: '\n| key | lang | value | width |\n|---|---|---|---|\n'
          '${rows.join('\n')}',
    );
  }, skip: 'until Task 2 shortens the strings');
}
