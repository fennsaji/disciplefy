/// Difficulty levels for cloze deletion practice.
///
/// Determines the frequency of blanks in the verse:
/// - [easy]: Every 5th word is a blank (easiest, fewer blanks)
/// - [medium]: Every 3rd word is a blank (moderate difficulty)
/// - [hard]: Every 2nd word is a blank (hardest, most blanks)
enum ClozeDifficulty {
  /// Easy difficulty: Every 5th word becomes a blank
  easy,

  /// Medium difficulty: Every 3rd word becomes a blank
  medium,

  /// Hard difficulty: Every 2nd word becomes a blank
  hard
}

/// Represents a single word entry in the cloze deletion exercise.
///
/// Each word can either be displayed normally or as a blank that the user
/// must fill in. The class tracks the user's input and correctness.
class WordEntry {
  /// The position of this word in the verse (0-indexed)
  final int index;

  /// The actual word from the verse text
  final String word;

  /// Whether this word should be displayed as a blank
  final bool isBlank;

  /// The user's input for this blank (empty string if not a blank or not filled)
  String userInput;

  /// Whether the user's input is correct (null if not yet checked)
  bool? isCorrect;

  WordEntry({
    required this.index,
    required this.word,
    required this.isBlank,
    required this.userInput,
    this.isCorrect,
  });
}
