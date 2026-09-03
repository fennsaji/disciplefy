import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/presentation/widgets/bottom_nav.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bottom navigation labels were hardcoded English strings, so the tab bar
/// read "Home / Generate / Topics / Community" even with the app in Hindi or
/// Malayalam.
void main() {
  const locales = ['en', 'hi', 'ml'];

  test('every tab has a label in every supported language', () {
    for (final code in locales) {
      final l10n = AppLocalizations(Locale(code));
      for (final tab in DisciplefyBottomNav.defaultTabs) {
        expect(l10n.navLabel(tab.id), isNotEmpty,
            reason: '${tab.id} missing for $code');
      }
    }
  });

  test('Hindi and Malayalam labels are actually translated', () {
    final en = AppLocalizations(const Locale('en'));
    for (final code in ['hi', 'ml']) {
      final l10n = AppLocalizations(Locale(code));
      for (final tab in DisciplefyBottomNav.defaultTabs) {
        expect(l10n.navLabel(tab.id), isNot(en.navLabel(tab.id)),
            reason: '${tab.id} is still English in $code');
      }
    }
  });

  test('tab ids are stable and distinct from display labels', () {
    final ids = DisciplefyBottomNav.defaultTabs.map((t) => t.id).toList();
    expect(ids, ['home', 'generate', 'topics', 'community']);
    expect(ids.toSet().length, ids.length);
  });
}
