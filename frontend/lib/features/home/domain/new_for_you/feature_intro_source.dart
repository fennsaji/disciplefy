import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

/// Today's verse as the memory introduction shows and saves it.
class IntroVerse {
  /// Daily-verse id, used to add it to the memory deck.
  final String id;
  final String text;
  final String reference;

  /// Language code the verse is shown in (en, hi, ml).
  final String language;

  const IntroVerse({
    required this.id,
    required this.text,
    required this.reference,
    required this.language,
  });
}

/// Data and actions behind the feature introductions' "Start with" cards.
///
/// Every method is safe to call: failures are logged and come back as an
/// empty result or false, so an introduction never shows an error state.
abstract class FeatureIntroSource {
  /// Up to two paths to start with, in [language].
  Future<List<LearningPath>> startPaths({
    required bool guest,
    required String language,
  });

  /// Today's verse in [language], or null.
  Future<IntroVerse?> todaysVerse(String language);

  /// Adds [verse] to the memory deck. True when it is saved, was already
  /// there, or was queued to sync.
  Future<bool> saveVerse(IntroVerse verse);

  /// The official open fellowships, every language.
  Future<List<PublicFellowshipEntity>> officialFellowships();

  /// Joins the public fellowship [id]. True on success.
  Future<bool> joinFellowship(String id);
}
