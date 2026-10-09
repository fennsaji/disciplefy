import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';

/// Number of numbered steps on every feature introduction.
const int featureIntroStepCount = 3;

/// Photo behind each kind's banner and introduction header.
const Map<NewForYouKind, String> newForYouPhotos = {
  NewForYouKind.paths: 'assets/images/hero/valley_mist.webp',
  NewForYouKind.memory: 'assets/images/hero/night_stars.webp',
  NewForYouKind.generate: 'assets/images/hero/snow_peaks.webp',
  NewForYouKind.discipler: 'assets/images/hero/mountains_fog.webp',
  NewForYouKind.fellowships: 'assets/images/hero/wheat_dawn.webp',
};

/// The passage "Start a study" and "See an example" open.
const String featureIntroExamplePassage = 'Romans 8';

/// The kind called [name] (its enum name, as used in `/intro/<kind>`), or
/// null when there is none.
NewForYouKind? newForYouKindNamed(String? name) {
  for (final kind in NewForYouKind.values) {
    if (kind.name == name) return kind;
  }
  return null;
}
