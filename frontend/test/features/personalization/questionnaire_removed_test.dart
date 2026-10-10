import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/i18n/translations_en.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';

/// The 6-step questionnaire was retired (2026-10-10): the growth goal is the
/// only personalisation question. Nothing in the app may open it again.
void main() {
  test('no questionnaire route, page, prompt card or strings', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final needle in const [
        'personalization-questionnaire',
        'PersonalizationQuestionnairePage',
        'PersonalizationPromptCard',
        'LoadForYouTopics',
        'LoadPersonalizedPaths',
      ]) {
        if (text.contains(needle)) offenders.add('${entity.path}: $needle');
      }
    }
    expect(offenders, isEmpty);
    expect(englishTranslations.containsKey('questionnaire'), isFalse);
  });

  test('Settings > Change my goal has its own route', () {
    expect(AppRoutes.changeGoal, '/settings/goal');
  });
}
