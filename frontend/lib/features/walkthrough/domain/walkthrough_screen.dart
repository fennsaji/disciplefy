// frontend/lib/features/walkthrough/domain/walkthrough_screen.dart

enum WalkthroughScreen {
  home,
  generate,
  memoryVerses,

  /// First-time tooltip on the Practice Mode selection screen.
  practiceModes,
  learningPaths,
  discipler,

  /// Cross-promo hint on Generate tab. No video URL — omit "Watch video" button.
  disciplerHint,
  community,
}

extension WalkthroughScreenName on WalkthroughScreen {
  String get key => name; // e.g. 'home', 'generate', 'disciplerHint'
}
