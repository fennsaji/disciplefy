import 'dart:async';

import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';

/// Runs before every test file: Hindi/Malayalam translation maps are deferred
/// imports, so load them once so tests can read every language synchronously.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await AppTranslations.ensureAllLoaded();
  await testMain();
}
