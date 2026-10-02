// frontend/lib/features/walkthrough/domain/walkthrough_video_config.dart

import 'walkthrough_screen.dart';

class WalkthroughVideoConfig {
  // Short explainer videos. Screens without a matching topic use the
  // one-minute app overview.
  static const String _appOverview =
      'https://youtube.com/shorts/gzAfX3KVBh8'; // Disciplefy in 1 minute
  static const String _verseMeaning =
      'https://youtube.com/shorts/7bbssMtHemE'; // What does this verse mean?
  static const String _confusedByBible =
      'https://youtube.com/shorts/FvpfH-xWmcs'; // Confused by what you read?

  static const Map<WalkthroughScreen, String> videoUrls = {
    WalkthroughScreen.home: _appOverview,
    WalkthroughScreen.generate: _verseMeaning,
    WalkthroughScreen.memoryVerses: _appOverview,
    WalkthroughScreen.learningPaths: _appOverview,
    WalkthroughScreen.discipler: _confusedByBible,
    // disciplerHint intentionally omitted — single-step nudge, no video
  };

  /// Returns the YouTube URL for a screen, or null if no video exists.
  /// Callers must omit the "Watch video" button when this returns null.
  static String? getVideoUrl(WalkthroughScreen screen) => videoUrls[screen];
}
