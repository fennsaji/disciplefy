/// Extensions for Duration to provide UI formatting utilities
extension DurationFormatting on Duration {
  /// Format duration as human-readable time label
  String toShortLabel() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Soon';
    }
  }
}
