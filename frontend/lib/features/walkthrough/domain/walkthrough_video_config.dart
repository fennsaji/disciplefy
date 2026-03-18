// frontend/lib/features/walkthrough/domain/walkthrough_video_config.dart

import 'walkthrough_screen.dart';

class WalkthroughVideoConfig {
  static const Map<WalkthroughScreen, String> videoUrls = {
    WalkthroughScreen.home: 'https://youtube.com/placeholder-home',
    WalkthroughScreen.generate: 'https://youtube.com/placeholder-generate',
    WalkthroughScreen.memoryVerses: 'https://youtube.com/placeholder-memory',
    WalkthroughScreen.learningPaths: 'https://youtube.com/placeholder-paths',
    WalkthroughScreen.discipler: 'https://youtube.com/placeholder-discipler',
    // disciplerHint intentionally omitted — single-step nudge, no video
  };

  /// Returns the YouTube URL for a screen, or null if no video exists.
  /// Callers must omit the "Watch video" button when this returns null.
  static String? getVideoUrl(WalkthroughScreen screen) => videoUrls[screen];
}
