import 'package:flutter/material.dart';

/// Utility functions for verse review functionality.
///
/// Provides helper methods for formatting time, determining quality icons,
/// and quality colors based on rating values.
class VerseReviewUtils {
  /// Formats elapsed seconds into MM:SS format.
  ///
  /// [seconds] - Total elapsed seconds to format.
  /// Returns a string in the format "MM:SS" (e.g., "02:45" for 165 seconds).
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Returns an appropriate icon based on quality rating.
  ///
  /// [rating] - Quality rating from 0 to 5.
  /// Returns:
  /// - Icons.celebration for ratings >= 4 (excellent recall)
  /// - Icons.thumb_up for ratings >= 3 (good recall)
  /// - Icons.refresh for ratings < 3 (needs more practice)
  static IconData getQualityIcon(int rating) {
    if (rating >= 4) return Icons.celebration;
    if (rating >= 3) return Icons.thumb_up;
    return Icons.refresh;
  }

  /// Returns an appropriate color based on quality rating.
  ///
  /// [rating] - Quality rating from 0 to 5.
  /// Returns:
  /// - Colors.green for ratings >= 4 (excellent recall)
  /// - Colors.blue for ratings >= 3 (good recall)
  /// - Colors.orange for ratings < 3 (needs more practice)
  static Color getQualityColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.blue;
    return Colors.orange;
  }
}
