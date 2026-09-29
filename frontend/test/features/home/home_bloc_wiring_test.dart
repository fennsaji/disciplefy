import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DailyVerseBloc is registered as a GetIt *factory*: every
/// `sl<DailyVerseBloc>()` builds a fresh, never-loaded instance. Home must
/// use the app-wide bloc provided in main.dart, or a widget silently watches
/// an empty bloc — which is how the streak tile showed "No streak yet" while
/// the database held a 1-day streak (29 Sept 2026).
void main() {
  test('home never looks DailyVerseBloc up from the service locator', () {
    const homeFiles = [
      'lib/features/home/presentation/pages/home_screen.dart',
      'lib/features/home/presentation/widgets/home_verse_hero.dart',
      'lib/features/home/presentation/widgets/home_sections.dart',
    ];
    for (final path in homeFiles) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('sl<DailyVerseBloc>()'), isFalse,
          reason: '$path must read the provided DailyVerseBloc');
    }
  });
}
