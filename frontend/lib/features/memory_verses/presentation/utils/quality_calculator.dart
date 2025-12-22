import 'package:flutter/material.dart';

/// Utility class to auto-calculate quality and confidence ratings
/// from practice session performance metrics.
///
/// Uses SM-2 spaced repetition algorithm scale (1-5):
/// - 5: Perfect response with complete recall (95%+)
/// - 4: Correct response with minor hesitation (85-94%)
/// - 3: Correct response with serious difficulty (65-84%)
/// - 2: Incorrect response but correct answer seemed easy to recall (45-64%)
/// - 1: Complete blackout, no recall (<45%)
class QualityCalculator {
  /// Calculate quality rating (1-5) based on performance metrics.
  ///
  /// Takes into account:
  /// - Accuracy percentage (primary factor):
  ///   - 95%+ → 5 stars
  ///   - 85%+ → 4 stars
  ///   - 65%+ → 3 stars
  ///   - 45%+ → 2 stars
  ///   - <45% → 1 star
  /// - Hints used (each hint reduces score by 0.2, max 1.0 reduction)
  /// - Whether answer was shown (caps rating at 2)
  static int calculateQuality({
    required double accuracy,
    required int hintsUsed,
    required bool showedAnswer,
  }) {
    // If user showed the answer, cap rating at 2
    if (showedAnswer) {
      return accuracy > 45 ? 2 : 1;
    }

    // Base score from accuracy
    double score;
    if (accuracy >= 95) {
      score = 5.0;
    } else if (accuracy >= 85) {
      score = 4.0;
    } else if (accuracy >= 65) {
      score = 3.0;
    } else if (accuracy >= 45) {
      score = 2.0;
    } else {
      score = 1.0;
    }

    // Hints penalty: 0.2 per hint, max 1.0 reduction
    final penalty = (hintsUsed * 0.2).clamp(0.0, 1.0);
    final finalScore = (score - penalty).clamp(1.0, 5.0);

    return finalScore.round();
  }

  /// Calculate confidence rating (1-5) based on performance.
  ///
  /// Confidence reflects how certain the user is about their knowledge:
  /// - 5: Very confident, no help needed
  /// - 4: Confident, minimal help
  /// - 3: Somewhat confident, moderate help
  /// - 2: Not confident, significant help
  /// - 1: No confidence, showed answer
  static int calculateConfidence({
    required double accuracy,
    required int hintsUsed,
    required bool showedAnswer,
  }) {
    if (showedAnswer) return 1;
    if (accuracy >= 95 && hintsUsed == 0) return 5;
    if (accuracy >= 85 && hintsUsed <= 1) return 4;
    if (accuracy >= 65 && hintsUsed <= 2) return 3;
    if (accuracy >= 45) return 2;
    return 1;
  }

  /// Get display label for quality rating.
  static String getQualityLabel(int rating) {
    switch (rating) {
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

  /// Get color for quality rating display.
  static Color getQualityColor(int rating) {
    switch (rating) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 2:
        return Colors.deepOrange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get color for accuracy percentage display.
  static Color getAccuracyColor(double accuracy) {
    if (accuracy >= 95) return Colors.green;
    if (accuracy >= 85) return Colors.lightGreen;
    if (accuracy >= 65) return Colors.orange;
    if (accuracy >= 45) return Colors.deepOrange;
    return Colors.red;
  }

  /// Get display name for practice mode.
  static String getModeName(String mode) {
    switch (mode) {
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
        return mode;
    }
  }

  /// Get icon for practice mode.
  static IconData getModeIcon(String mode) {
    switch (mode) {
      case 'flip_card':
        return Icons.flip;
      case 'first_letter':
        return Icons.abc;
      case 'progressive':
        return Icons.trending_up;
      case 'cloze':
        return Icons.edit_note;
      case 'word_scramble':
        return Icons.shuffle;
      case 'word_bank':
        return Icons.touch_app;
      case 'audio':
        return Icons.volume_up;
      case 'type_it_out':
        return Icons.keyboard;
      default:
        return Icons.quiz;
    }
  }
}
