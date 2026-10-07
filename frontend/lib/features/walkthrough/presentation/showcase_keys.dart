// frontend/lib/features/walkthrough/presentation/showcase_keys.dart

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// All GlobalKeys used as Showcase targets across the app.
/// Each key corresponds to a specific UI element that will be highlighted.
class ShowcaseKeys {
  ShowcaseKeys._();

  // --- AppShell showcase controller ---
  // ShowCaseWidget doesn't accept a Key, so we hold a direct state reference.
  static ShowCaseWidgetState? _appShellState;

  /// Called by AppShell inside its ShowCaseWidget.builder to register the state.
  static void registerAppShell(ShowCaseWidgetState state) =>
      _appShellState = state;

  /// Starts the community-tab highlight step from AppShell's ShowCaseWidget.
  static void triggerCommunityTab() =>
      _appShellState?.startShowCase([homeCommunityTab]);

  /// Dock tabs in the order the home tour visits them.
  static List<GlobalKey> get homeNavTabKeys => [
        homeGenerateTab,
        homeDisciplerTab,
        homeTopicsTab,
        homeCommunityTab,
      ];

  /// Ordered keys of the running home tour (body steps then dock tabs), used
  /// to number each step. Tabs hidden by feature flags are left out.
  static List<GlobalKey> _homeTour = const [];

  /// Records the home tour: [bodyKeys] plus every dock tab currently shown.
  static void beginHomeTour(List<GlobalKey> bodyKeys) =>
      _homeTour = [...bodyKeys, ..._mountedNavTabKeys()];

  /// 1-based step number and total for [key] in the running home tour, or
  /// null when [key] is not part of it.
  static ({int step, int total})? homeTourStepOf(GlobalKey key) {
    final index = _homeTour.indexOf(key);
    if (index < 0) return null;
    return (step: index + 1, total: _homeTour.length);
  }

  static List<GlobalKey> _mountedNavTabKeys() =>
      homeNavTabKeys.where((k) => k.currentContext != null).toList();

  /// Starts the dock-tab steps (Generate → Discipler → Topics → Community)
  /// from AppShell's ShowCaseWidget (called when home body walkthrough
  /// finishes). Returns false when there is nothing to show, so the caller
  /// can finish the tour itself.
  static bool triggerNavTabsAndCommunity() {
    final state = _appShellState;
    final keys = _mountedNavTabKeys();
    if (state == null || !state.mounted || keys.isEmpty) return false;
    state.startShowCase(keys);
    return true;
  }

  // Home screen dock tabs. The Home body's own targets (verse, Memory
  // Verses pill) are keys of each Home instance, since two Homes can be
  // mounted at once during a route transition.
  static final GlobalKey homeGenerateTab =
      GlobalKey(debugLabel: 'homeGenerateTab');
  static final GlobalKey homeDisciplerTab =
      GlobalKey(debugLabel: 'homeDisciplerTab');
  static final GlobalKey homeTopicsTab = GlobalKey(debugLabel: 'homeTopicsTab');
  static final GlobalKey homeCommunityTab =
      GlobalKey(debugLabel: 'homeCommunityTab');

  // Generate screen
  static final GlobalKey generateModeToggle =
      GlobalKey(debugLabel: 'generateModeToggle');
  static final GlobalKey generateInput = GlobalKey(debugLabel: 'generateInput');
  static final GlobalKey generateButton =
      GlobalKey(debugLabel: 'generateButton');
  static final GlobalKey disciplerHint = GlobalKey(debugLabel: 'disciplerHint');

  /// Separate key for the cross-promo hint shown on the Study Guide screen.
  /// Must differ from [disciplerHint] because both screens can be in the
  /// IndexedStack simultaneously, causing a duplicate-GlobalKey assertion.
  static final GlobalKey disciplerHintStudyGuide =
      GlobalKey(debugLabel: 'disciplerHintStudyGuide');

  // Memory Verses screen
  static final GlobalKey memoryAddVerse =
      GlobalKey(debugLabel: 'memoryAddVerse');
  static final GlobalKey memoryVerseCard =
      GlobalKey(debugLabel: 'memoryVerseCard');
  static final GlobalKey memoryPracticeMode =
      GlobalKey(debugLabel: 'memoryPracticeMode');

  // Learning Paths screen
  static final GlobalKey topicsPathList =
      GlobalKey(debugLabel: 'topicsPathList');
  static final GlobalKey topicsPathCard =
      GlobalKey(debugLabel: 'topicsPathCard');

  // Talk to Discipler screen
  static final GlobalKey disciplerInput =
      GlobalKey(debugLabel: 'disciplerInput');
  static final GlobalKey disciplerSend = GlobalKey(debugLabel: 'disciplerSend');

  // Community screen
  static final GlobalKey communityTabs = GlobalKey(debugLabel: 'communityTabs');
  static final GlobalKey communityFab = GlobalKey(debugLabel: 'communityFab');

  // Study Guide screen
  static final GlobalKey studyGuideMenuButton =
      GlobalKey(debugLabel: 'studyGuideMenuButton');
  static final GlobalKey studyGuideListen =
      GlobalKey(debugLabel: 'studyGuideListen');
  static final GlobalKey studyGuideFellowshipShare =
      GlobalKey(debugLabel: 'studyGuideFellowshipShare');
  static final GlobalKey studyGuideFollowUpChat =
      GlobalKey(debugLabel: 'studyGuideFollowUpChat');
  static final GlobalKey studyGuideNotes =
      GlobalKey(debugLabel: 'studyGuideNotes');

  // Practice mode pages (per-page first-launch walkthroughs)
  static final GlobalKey practiceFlipCard =
      GlobalKey(debugLabel: 'practiceFlipCard');
  static final GlobalKey practiceWordBank =
      GlobalKey(debugLabel: 'practiceWordBank');
  static final GlobalKey practiceCloze = GlobalKey(debugLabel: 'practiceCloze');
  static final GlobalKey practiceFirstLetter =
      GlobalKey(debugLabel: 'practiceFirstLetter');
  static final GlobalKey practiceProgressive =
      GlobalKey(debugLabel: 'practiceProgressive');
  static final GlobalKey practiceProgressiveAutoReveal =
      GlobalKey(debugLabel: 'practiceProgressiveAutoReveal');
  static final GlobalKey practiceProgressiveRevealAll =
      GlobalKey(debugLabel: 'practiceProgressiveRevealAll');
  static final GlobalKey practiceProgressiveSubmit =
      GlobalKey(debugLabel: 'practiceProgressiveSubmit');
  static final GlobalKey practiceWordScramble =
      GlobalKey(debugLabel: 'practiceWordScramble');
  static final GlobalKey practiceWordScrambleShowAnswer =
      GlobalKey(debugLabel: 'practiceWordScrambleShowAnswer');
  static final GlobalKey practiceWordScrambleReset =
      GlobalKey(debugLabel: 'practiceWordScrambleReset');
  static final GlobalKey practiceWordScrambleSubmit =
      GlobalKey(debugLabel: 'practiceWordScrambleSubmit');
  static final GlobalKey practiceAudio = GlobalKey(debugLabel: 'practiceAudio');
  static final GlobalKey practiceTypeItOut =
      GlobalKey(debugLabel: 'practiceTypeItOut');
}
