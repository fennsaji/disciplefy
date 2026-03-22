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

  /// Phase 1: 3-dot menu + Listen button (shown when guide first loads).
  studyGuide,

  /// Phase 2: fellowship share + follow-up chat + notes (shown on completion).
  studyGuideCompletion,
}

extension WalkthroughScreenName on WalkthroughScreen {
  String get key => name; // e.g. 'home', 'generate', 'disciplerHint'
}
