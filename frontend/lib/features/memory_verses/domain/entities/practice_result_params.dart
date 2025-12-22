import 'package:equatable/equatable.dart';

/// Comparison data for a single blank in Fill in the Blanks mode.
class BlankComparison extends Equatable {
  /// The word/phrase that was expected (correct answer)
  final String expected;

  /// What the user actually typed
  final String userInput;

  /// Whether the answer was marked as correct
  final bool isCorrect;

  const BlankComparison({
    required this.expected,
    required this.userInput,
    required this.isCorrect,
  });

  @override
  List<Object?> get props => [expected, userInput, isCorrect];
}

/// Parameters passed to the Practice Results Page after completing any practice mode.
///
/// This unified entity ensures all 8 practice modes pass consistent data
/// to the results page for display and BLoC submission.
class PracticeResultParams extends Equatable {
  /// ID of the verse that was practiced
  final String verseId;

  /// Bible reference (e.g., "John 3:16")
  final String verseReference;

  /// The verse text content
  final String verseText;

  /// Practice mode type (e.g., 'flip_card', 'cloze', 'word_bank')
  final String practiceMode;

  /// Time spent on the practice in seconds
  final int timeSpentSeconds;

  /// Accuracy percentage (0.0 - 100.0)
  final double accuracyPercentage;

  /// Number of hints used during practice
  final int hintsUsed;

  /// Whether the user revealed the answer (penalty applies)
  final bool showedAnswer;

  /// Auto-calculated quality rating (1-5 SM-2 scale)
  final int qualityRating;

  /// Auto-calculated confidence rating (1-5)
  final int confidenceRating;

  /// Optional next verse ID for queue navigation
  final String? nextVerseId;

  /// Blank comparisons for Fill in the Blanks mode (null for other modes)
  final List<BlankComparison>? blankComparisons;

  const PracticeResultParams({
    required this.verseId,
    required this.verseReference,
    required this.verseText,
    required this.practiceMode,
    required this.timeSpentSeconds,
    required this.accuracyPercentage,
    required this.hintsUsed,
    required this.showedAnswer,
    required this.qualityRating,
    required this.confidenceRating,
    this.nextVerseId,
    this.blankComparisons,
  });

  @override
  List<Object?> get props => [
        verseId,
        verseReference,
        verseText,
        practiceMode,
        timeSpentSeconds,
        accuracyPercentage,
        hintsUsed,
        showedAnswer,
        qualityRating,
        confidenceRating,
        nextVerseId,
        blankComparisons,
      ];

  /// Get display name for the practice mode
  String get practiceModeDisplayName {
    switch (practiceMode) {
      case 'flip_card':
        return 'Flip Card';
      case 'first_letter':
        return 'First Letter Hints';
      case 'progressive':
        return 'Progressive Reveal';
      case 'cloze':
        return 'Fill in the Blanks';
      case 'word_scramble':
        return 'Phrase Scramble';
      case 'word_bank':
        return 'Word Bank';
      case 'audio':
        return 'Audio Practice';
      case 'type_it_out':
        return 'Type It Out';
      default:
        return practiceMode;
    }
  }

  /// Get quality label based on rating
  String get qualityLabel {
    switch (qualityRating) {
      case 5:
        return 'Perfect';
      case 4:
        return 'Good';
      case 3:
        return 'OK';
      case 2:
        return 'Needs Work';
      case 1:
        return 'Try Again';
      default:
        return 'Unknown';
    }
  }

  /// Format time spent as MM:SS
  String get formattedTime {
    final minutes = timeSpentSeconds ~/ 60;
    final seconds = timeSpentSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
