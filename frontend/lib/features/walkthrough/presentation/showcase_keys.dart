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

  /// Starts the Generate → Topics → Community nav-tab steps from AppShell's
  /// ShowCaseWidget (called when home body walkthrough finishes).
  static void triggerNavTabsAndCommunity() => _appShellState?.startShowCase([
        homeGenerateTab,
        homeTopicsTab,
        homeCommunityTab,
      ]);

  // Home screen
  static final GlobalKey homeDailyVerse =
      GlobalKey(debugLabel: 'homeDailyVerse');
  static final GlobalKey homeMemoryVerses =
      GlobalKey(debugLabel: 'homeMemoryVerses');
  static final GlobalKey homeGenerateTab =
      GlobalKey(debugLabel: 'homeGenerateTab');
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

  // AI Discipler screen
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
