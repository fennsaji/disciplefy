/// Translation key constants for type-safe translation access
class TranslationKeys {
  // App status: maintenance, error page, exit/join prompts, shell toasts.
  static const appStatusMaintenanceEyebrow = 'app_status.maintenance_eyebrow';
  static const appStatusMaintenanceTitle = 'app_status.maintenance_title';
  static const appStatusMaintenanceCheck = 'app_status.maintenance_check';
  static const appStatusMaintenanceChecking = 'app_status.maintenance_checking';
  static const appStatusMaintenanceBackSoon =
      'app_status.maintenance_back_soon';
  static const appStatusMaintenanceCheckFailed =
      'app_status.maintenance_check_failed';
  static const appStatusErrorEyebrow = 'app_status.error_eyebrow';
  static const appStatusErrorTryLater = 'app_status.error_try_later';
  static const appStatusErrorReport = 'app_status.error_report';
  static const appStatusErrorNoEmailApp = 'app_status.error_no_email_app';
  static const appStatusSubscriptionActivated =
      'app_status.subscription_activated';
  static const appStatusPurchaseValidationFailed =
      'app_status.purchase_validation_failed';
  static const appStatusSettingsOpenFailed = 'app_status.settings_open_failed';
  static const appStatusLockedPathsBody = 'app_status.locked_paths_body';

  // App chrome: lock overlay, update dialogs, offline banner,
  // notification prompt eyebrow.
  static const appChromeLockTapToUpgrade = 'app_chrome.lock.tap_to_upgrade';
  static const appChromeLockNotAvailableOffline =
      'app_chrome.lock.not_available_offline';
  static const appChromeLockConnectToUpgrade =
      'app_chrome.lock.connect_to_upgrade';
  static const appChromeUpdateEyebrow = 'app_chrome.update.eyebrow';
  static const appChromeUpdateRequiredTitle =
      'app_chrome.update.required_title';
  static const appChromeUpdateRequiredBody = 'app_chrome.update.required_body';
  static const appChromeUpdateRequiredHint = 'app_chrome.update.required_hint';
  static const appChromeUpdateAvailableTitle =
      'app_chrome.update.available_title';
  static const appChromeUpdateAvailableBody =
      'app_chrome.update.available_body';
  static const appChromeUpdateCurrentVersion =
      'app_chrome.update.current_version';
  static const appChromeUpdateRequiredVersion =
      'app_chrome.update.required_version';
  static const appChromeUpdateLatestVersion =
      'app_chrome.update.latest_version';
  static const appChromeUpdateUpdateNow = 'app_chrome.update.update_now';
  static const appChromeUpdateUpdate = 'app_chrome.update.update';
  static const appChromeUpdateLater = 'app_chrome.update.later';
  static const appChromeOfflineOffline = 'app_chrome.offline.offline';
  static const appChromeOfflineBackOnline = 'app_chrome.offline.back_online';
  static const appChromeNotifyPromptEyebrow =
      'app_chrome.notify_prompt.eyebrow';
  // Memory recall practice modes (flip card, progressive reveal,
  // first letter hints, type it out)
  static const memoryRecallFlipFront = 'memory_recall_modes.flip_card.front';
  static const memoryRecallFlipBack = 'memory_recall_modes.flip_card.back';
  static const memoryRecallFlipReciteHint =
      'memory_recall_modes.flip_card.recite_hint';
  static const memoryRecallFlipAction = 'memory_recall_modes.flip_card.flip';
  static const memoryRecallProgressiveWords =
      'memory_recall_modes.progressive.words_progress';
  static const memoryRecallProgressivePhrases =
      'memory_recall_modes.progressive.phrases_progress';
  static const memoryRecallProgressiveAuto =
      'memory_recall_modes.progressive.auto';
  static const memoryRecallProgressivePause =
      'memory_recall_modes.progressive.pause';
  static const memoryRecallProgressiveAll =
      'memory_recall_modes.progressive.all';
  static const memoryRecallFirstLetterHint =
      'memory_recall_modes.first_letter.hint';
  static const memoryRecallFirstLetterCheck =
      'memory_recall_modes.first_letter.check';
  static const memoryRecallFirstLetterHintsUsed =
      'memory_recall_modes.first_letter.hints_used';
  static const memoryRecallFirstLetterTileLabel =
      'memory_recall_modes.first_letter.tile_label';
  static const memoryRecallTypeWordCount =
      'memory_recall_modes.type_it_out.word_count';
  static const memoryRecallTypeAnswer =
      'memory_recall_modes.type_it_out.answer';
  static const memoryRecallTypeRomanizedHint =
      'memory_recall_modes.type_it_out.romanized_hint';
  static const memoryRecallTypeHinglish =
      'memory_recall_modes.type_it_out.hinglish';
  static const memoryRecallTypeManglish =
      'memory_recall_modes.type_it_out.manglish';

  // Study Guide Section Titles
  static const studyGuideSummary = 'study_guide.sections.summary';
  static const studyGuideInterpretation = 'study_guide.sections.interpretation';
  static const studyGuideContext = 'study_guide.sections.context';
  static const studyGuidePassageReading =
      'study_guide.sections.passage_reading';
  static const studyGuideRelatedVerses = 'study_guide.sections.related_verses';
  static const studyGuideDiscussionQuestions =
      'study_guide.sections.discussion_questions';
  static const studyGuidePrayerPoints = 'study_guide.sections.prayer_points';
  static const studyGuidePersonalNotes = 'study_guide.sections.personal_notes';

  // Study Guide Actions
  static const studyGuideSaveStudy = 'study_guide.actions.save_study';
  static const studyGuideSaved = 'study_guide.actions.saved';
  static const studyGuideShare = 'study_guide.actions.share';
  static const studyGuideCopy = 'study_guide.actions.copy';
  static const studyGuideSignIn = 'study_guide.actions.sign_in';
  static const studyGuideGeneratingPdf = 'study_guide.actions.generating_pdf';
  static const studyGuidePdfWaitMessage =
      'study_guide.actions.pdf_wait_message';
  static const studyGuidePdfFinalizing = 'study_guide.actions.pdf_finalizing';
  static const studyGuidePdfSavedTo = 'study_guide.actions.pdf_saved_to';

  // Study Guide Streaming
  static const studyGuideStreamingLoading = 'study_guide.streaming.loading';
  static const studyGuideStreamingSections = 'study_guide.streaming.sections';

  // Study Guide TTS
  static const studyGuideListen = 'study_guide.tts.listen';
  static const studyGuideMenuMore = 'study_guide.menu.more';
  static const studyGuideMenuTextSize = 'study_guide.menu.text_size';
  static const studyGuideMenuShare = 'study_guide.menu.share';
  static const studyGuideMenuShareFellowship =
      'study_guide.menu.share_fellowship';
  static const studyGuideMenuDownloadPdf = 'study_guide.menu.download_pdf';
  static const studyGuideMenuSave = 'study_guide.menu.save';
  static const studyGuideMenuSaved = 'study_guide.menu.saved';
  static const studyGuideMenuComplete = 'study_guide.menu.complete';
  static const studyGuideMenuCompleted = 'study_guide.menu.completed';
  static const studyGuideTextSizeEyebrow = 'study_guide.text_size.eyebrow';
  static const studyGuideTextSizePreview = 'study_guide.text_size.preview';
  static const studyGuideTextSizeDone = 'study_guide.text_size.done';
  static const studyGuideTextSizeReset = 'study_guide.text_size.reset';
  static const studyGuidePause = 'study_guide.tts.pause';
  static const studyGuideResume = 'study_guide.tts.resume';
  static const studyGuideLoading = 'study_guide.tts.loading';
  static const studyGuideTtsControls = 'study_guide.tts.controls';
  static const studyGuideTtsSpeed = 'study_guide.tts.speed';
  static const studyGuideTtsNowReading = 'study_guide.tts.now_reading';
  static const studyGuideTtsStop = 'study_guide.tts.stop';

  // Study Guide Messages
  static const studyGuideAuthRequired = 'study_guide.messages.auth_required';
  static const studyGuideAuthRequiredMessage =
      'study_guide.messages.auth_required_message';
  static const studyGuideCopiedToClipboard =
      'study_guide.messages.copied_to_clipboard';
  static const studyGuideSaveSuccess = 'study_guide.messages.save_success';
  static const studyGuideSaveError = 'study_guide.messages.save_error';

  // Study Guide Placeholders
  static const studyGuidePersonalNotesPlaceholder =
      'study_guide.placeholders.personal_notes';

  // Common Actions
  static const commonRetry = 'common.retry';
  static const commonPurchaseCancelled = 'common.purchase_cancelled';
  static const commonCancel = 'common.actions.cancel';
  static const commonShare = 'common.actions.share';
  static const commonCopy = 'common.actions.copy';
  static const commonSave = 'common.actions.save';
  static const commonDelete = 'common.actions.delete';
  static const commonEdit = 'common.actions.edit';
  static const commonShowMore = 'common.actions.show_more';
  static const commonShowLess = 'common.actions.show_less';
  static const commonOpenSettings = 'common.actions.open_settings';

  // ==========================================================================
  // Memory verse practice
  // ==========================================================================

  static const practiceUnlockedModesToday = 'practice.unlocked_modes_today';
  static const practiceModesProgress = 'practice.modes_progress';
  static const practiceChooseOneMode = 'practice.choose_one_mode';
  static const practiceChooseModes = 'practice.choose_modes';
  static const practiceUnlockOneMore = 'practice.unlock_one_more';
  static const practiceUnlockMoreModes = 'practice.unlock_more_modes';
  static const practiceStepRead = 'practice.step_read';
  static const practiceStepSpeak = 'practice.step_speak';
  static const practiceStepResults = 'practice.step_results';

  // Common Messages
  static const commonError = 'common.messages.error';

  /// Shared generic failure text. Preferred over repeating the English literal
  /// at each call site — it used to appear untranslated on Hindi and Malayalam
  /// screens in ~40 files.
  static const commonErrorTryAgain = 'common.messages.error_try_again';
  static const commonSuccess = 'common.messages.success';

  // App Exit Confirmation
  static const commonExitTitle = 'common.exit.title';
  static const commonExitMessage = 'common.exit.message';
  static const commonExitConfirm = 'common.exit.confirm';

  // Follow-up Chat
  static const followUpChatTitle = 'follow_up_chat.title';
  static const followUpChatExpandTooltip = 'follow_up_chat.expand_tooltip';
  static const followUpChatCollapseTooltip = 'follow_up_chat.collapse_tooltip';
  static const followUpChatStartingConversation =
      'follow_up_chat.starting_conversation';
  static const followUpChatError = 'follow_up_chat.error';
  static const followUpChatTryAgain = 'follow_up_chat.try_again';
  static const followUpChatInsufficientTokens =
      'follow_up_chat.insufficient_tokens';
  static const followUpChatInsufficientTokensMessage =
      'follow_up_chat.insufficient_tokens_message';
  static const followUpChatDismiss = 'follow_up_chat.dismiss';
  static const followUpChatGetMoreTokens = 'follow_up_chat.get_more_tokens';
  static const followUpChatNotAvailable = 'follow_up_chat.not_available';
  static const followUpChatUpgradeMessage = 'follow_up_chat.upgrade_message';
  static const followUpChatUpgradePlan = 'follow_up_chat.upgrade_plan';
  static const followUpChatLimitReached = 'follow_up_chat.limit_reached';
  static const followUpChatLimitMessage = 'follow_up_chat.limit_message';
  static const followUpChatInitialTitle = 'follow_up_chat.initial_title';
  static const followUpChatInitialMessage = 'follow_up_chat.initial_message';
  static const followUpChatInputHint = 'follow_up_chat.input_hint';
  static const followUpChatGettingResponse = 'follow_up_chat.getting_response';
  static const followUpChatCancel = 'follow_up_chat.cancel';
  static const followUpChatSend = 'follow_up_chat.send';
  static const followUpChatTokenCost = 'follow_up_chat.token_cost';
  static const followUpChatResponding = 'follow_up_chat.responding';
  static const followUpChatFailedToSend = 'follow_up_chat.failed_to_send';
  static const followUpChatSending = 'follow_up_chat.sending';
  static const followUpChatTokens = 'follow_up_chat.tokens';
  static const followUpChatJustNow = 'follow_up_chat.just_now';
  static const followUpChatMinutesAgo = 'follow_up_chat.minutes_ago';
  static const followUpChatHoursAgo = 'follow_up_chat.hours_ago';
  static const followUpChatDaysAgo = 'follow_up_chat.days_ago';
  static const followUpChatMessageCopied = 'follow_up_chat.message_copied';
  static const followUpChatExpanded = 'follow_up_chat.expanded';
  static const followUpChatCollapsed = 'follow_up_chat.collapsed';
  static const followUpChatDoubleTapTo = 'follow_up_chat.double_tap_to';
  static const followUpChatCollapse = 'follow_up_chat.collapse';
  static const followUpChatExpand = 'follow_up_chat.expand';
  static const followUpChatGenerateNewStudy =
      'follow_up_chat.generate_new_study';
  static const followUpChatNoMessagesYet = 'follow_up_chat.no_messages_yet';
  static const followUpChatStartByAsking = 'follow_up_chat.start_by_asking';
  static const followUpChatGreeting = 'follow_up_chat.greeting';
  static const followUpChatPromptExplain = 'follow_up_chat.prompt_explain';
  static const followUpChatPromptApply = 'follow_up_chat.prompt_apply';
  static const followUpChatPromptVerses = 'follow_up_chat.prompt_verses';
  static const followUpChatListening = 'follow_up_chat.listening';
  static const followUpChatStop = 'follow_up_chat.stop';
  static const followUpChatStopListening = 'follow_up_chat.stop_listening';
  static const followUpChatTapToSpeak = 'follow_up_chat.tap_to_speak';
  static const followUpChatSpeechNotAvailable =
      'follow_up_chat.speech_not_available';

  // Home Today
  static const homeTodayLabel = 'home_today.today_label';
  static const homeTodayLessonEyebrow = 'home_today.lesson_eyebrow';
  static const homeTodayStartLesson = 'home_today.start_lesson';
  static const homeTodayModeQuick = 'home_today.mode_quick';
  static const homeTodayModeStandard = 'home_today.mode_standard';
  static const homeTodayPathFinished = 'home_today.path_finished';
  static const homeTodayChooseNextPath = 'home_today.choose_next_path';
  static const homeTodaySeePath = 'home_today.see_path';
  static const homeTodayLessonOf = 'home_today.lesson_of';
  static const homeTodayToGo = 'home_today.to_go';
  static const homeTodayChooseFirstPath = 'home_today.choose_first_path';
  static const homeTodayChooseFirstPathSub = 'home_today.choose_first_path_sub';
  static const homeTodayLessonsDays = 'home_today.lessons_days';
  static const homeTodaySeeAllPaths = 'home_today.see_all_paths';
  static const homeTodaySaveProgress = 'home_today.save_progress';
  static const homeTodayReflect = 'home_today.reflect';
  static const homeTodayLoadingPath = 'home_today.loading_path';

  // New for you banners and feature introductions. Per-kind keys are built
  // from the kind's name (NewForYouKind.name) by the helpers below.
  static const nfyEyebrow = 'nfy.eyebrow';
  static const nfyDismiss = 'nfy.dismiss';
  static String nfyBannerTitle(String kind) => 'nfy.$kind.banner_title';
  static String nfyBannerSub(String kind) => 'nfy.$kind.banner_sub';
  static String nfyBannerSubAny(String kind) => 'nfy.$kind.banner_sub_any';
  static String nfyBannerCta(String kind) => 'nfy.$kind.banner_cta';
  static const introStartWith = 'intro.start_with';
  static const introClose = 'intro.close';
  static String introEyebrow(String kind) => 'intro.$kind.eyebrow';
  static String introTitle(String kind) => 'intro.$kind.title';
  static String introStepTitle(String kind, int step) =>
      'intro.$kind.step${step}_title';
  static String introStepBody(String kind, int step) =>
      'intro.$kind.step${step}_body';
  static String introPrimary(String kind) => 'intro.$kind.primary';
  static String introSecondary(String kind) => 'intro.$kind.secondary';
  static const introMemorySaved = 'intro.memory.saved';
  static const introGenerateChip1 = 'intro.generate.chip1';
  static const introGenerateChip2 = 'intro.generate.chip2';
  static const introGenerateChip3 = 'intro.generate.chip3';
  static const introDisciplerQuestion = 'intro.discipler.question';
  static const introFellowshipsJoin = 'intro.fellowships.join';
  static const introFellowshipsMembers = 'intro.fellowships.members';
  static const introFellowshipsMemberOne = 'intro.fellowships.member_one';
  static const introFellowshipsMembersOpen = 'intro.fellowships.members_open';
  static const introFellowshipsOfficial = 'intro.fellowships.official';
  static const introFellowshipsStudying = 'intro.fellowships.studying';
  static const introFellowshipsJoinFailed = 'intro.fellowships.join_failed';

  // Home Screen
  static const homeWelcomeBack = 'home.welcome_back';
  static const homeGoodMorning = 'home.good_morning';
  static const homeGoodAfternoon = 'home.good_afternoon';
  static const homeGoodEvening = 'home.good_evening';
  static const homeStudyNow = 'home.study_now';
  static const homeContinueLearning = 'home.continue_learning';
  static const homeAllPaths = 'home.all_paths';
  static const homeBrowsePaths = 'home.browse_paths';
  static const homeBrowsePathsHint = 'home.browse_paths_hint';
  static const homeTopicsProgress = 'home.topics_progress';
  static const homeTopicsProgressNext = 'home.topics_progress_next';
  static const homeStartHere = 'home.start_here';
  static const homeDayStreak = 'home.day_streak';
  static const homeKeepItAlive = 'home.keep_it_alive';
  static const homeNoStreakYet = 'home.no_streak_yet';
  static const homeStartStreakHint = 'home.start_streak_hint';
  static const homeToReview = 'home.to_review';
  static const homeAllCaughtUp = 'home.all_caught_up';
  static const homeNothingDue = 'home.nothing_due';
  static const homeReviewMore = 'home.review_more';
  static const homeMeetingToday = 'home.meeting_today';
  static const homeMeetingTodayAt = 'home.meeting_today_at';
  static const homeMeetingNowEnds = 'home.meeting_now_ends';
  static const homeMeetingLive = 'home.meeting_live';
  static const homeContinueJourney = 'home.continue_journey';
  static const homeMemoryVerses = 'home.memory_verses';
  static const homeGenerateStudyGuide = 'home.generate_study_guide';
  static const homeExploreLearningPaths = 'home.explore_learning_paths';
  static const homeResumeLastStudy = 'home.resume_last_study';
  static const homeContinueStudying = 'home.continue_studying';
  static const homeRecommendedTopics = 'home.recommended_topics';
  static const homeViewAll = 'home.view_all';
  static const homeFailedToLoadTopics = 'home.failed_to_load_topics';
  static const homeSomethingWentWrong = 'home.something_went_wrong';
  static const homeTryAgain = 'home.try_again';
  static const homeNoTopicsAvailable = 'home.no_topics_available';
  static const homeCheckConnection = 'home.check_connection';
  static const homeGenerationInProgress = 'home.generation_in_progress';
  static const homeGeneratingStudyGuide = 'home.generating_study_guide';
  static const homeFailedToGenerate = 'home.failed_to_generate';
  static const homeDismiss = 'home.dismiss';
  static const homeVerseNotLoaded = 'home.verse_not_loaded';
  static const homeForYou = 'home.for_you';
  static const homeForYouSubtitle = 'home.for_you_subtitle';
  static const communityVerseStudyLabel = 'community.verse_study_label';
  static const communityTopicStudyLabel = 'community.topic_study_label';
  static const communityStudyGuideLabel = 'community.study_guide_label';
  static const homeReadyForNextStep = 'home.ready_for_next_step';
  static const homeAvailableOffline = 'home.available_offline';
  static const homeExploreTopics = 'home.explore_topics';
  static const homePersonalizePromptTitle = 'home.personalize_prompt_title';
  static const homePersonalizePromptSubtitle =
      'home.personalize_prompt_subtitle';
  static const homePersonalizePromptDescription =
      'home.personalize_prompt_description';
  static const homePersonalizeGetStarted = 'home.personalize_get_started';
  static const homePersonalizeMaybeLater = 'home.personalize_maybe_later';

  // Daily Verse
  static const dailyVerseRefreshing = 'daily_verse.refreshing';
  static const dailyVerseLoading = 'daily_verse.loading';
  static const dailyVerseOfTheDay = 'daily_verse.of_the_day';
  static const dailyVerseCached = 'daily_verse.cached';
  static const dailyVerseOfflineMode = 'daily_verse.offline_mode';
  static const dailyVerseTapToGenerate = 'daily_verse.tap_to_generate';
  static const dailyVerseUnableToLoad = 'daily_verse.unable_to_load';
  static const dailyVerseSomethingWentWrong =
      'daily_verse.something_went_wrong';
  static const dailyVerseCopy = 'daily_verse.copy';
  static const dailyVerseShare = 'daily_verse.share';
  static const dailyVerseCopied = 'daily_verse.copied';
  static const dailyVerseAddToMemory = 'daily_verse.add_to_memory';
  static const dailyVerseAlreadyInMemory = 'daily_verse.already_in_memory';

  // Generate Study Screen
  static const generateStudyTitle = 'generate_study.title';
  static const generateStudyScriptureMode = 'generate_study.scripture_mode';
  static const generateStudyTopicMode = 'generate_study.topic_mode';
  static const generateStudyQuestionMode = 'generate_study.question_mode';
  static const generateStudyLanguage = 'generate_study.language';
  static const generateStudyEnglish = 'generate_study.english';
  static const generateStudyHindi = 'generate_study.hindi';
  static const generateStudyMalayalam = 'generate_study.malayalam';
  static const generateStudyDefaultLanguage = 'generate_study.default_language';
  static const generateStudyDefaultLanguageOption =
      'generate_study.default_language_option';
  static const generateStudyEnterScripture = 'generate_study.enter_scripture';
  static const generateStudyEnterTopic = 'generate_study.enter_topic';
  static const generateStudyAskQuestion = 'generate_study.ask_question';
  static const generateStudyScriptureHint = 'generate_study.scripture_hint';
  static const generateStudyTopicHint = 'generate_study.topic_hint';
  static const generateStudyQuestionHint = 'generate_study.question_hint';
  static const generateStudyScriptureError = 'generate_study.scripture_error';
  static const generateStudyQuestionError = 'generate_study.question_error';
  static const generateStudyTopicError = 'generate_study.topic_error';
  static const generateStudySuggestions = 'generate_study.suggestions';
  static const generateStudyScriptureSuggestions =
      'generate_study.scripture_suggestions';
  static const generateStudyTopicSuggestions =
      'generate_study.topic_suggestions';
  static const generateStudyQuestionSuggestions =
      'generate_study.question_suggestions';
  static const generateStudyGenerating = 'generate_study.generating';
  static const generateStudyConsumingTokens = 'generate_study.consuming_tokens';
  static const generateStudyButtonGenerating =
      'generate_study.button_generating';
  static const generateStudyButtonGenerate = 'generate_study.button_generate';
  static const generateStudyViewSaved = 'generate_study.view_saved';
  static const generateStudyTalkToAiBuddy = 'generate_study.talk_to_ai_buddy';
  static const generateStudyTalkToAiBuddySubtitle =
      'generate_study.talk_to_ai_buddy_subtitle';
  static const generateStudyAiDisciplerBadgeNew =
      'generate_study.ai_discipler_badge_new';
  static const generateStudyInProgress = 'generate_study.in_progress';
  static const generateStudyGenerationFailed =
      'generate_study.generation_failed';
  static const generateStudyGenerationFailedMessage =
      'generate_study.generation_failed_message';
  static const generateStudyManageTokens = 'generate_study.manage_tokens';

  // Generate tab (Scripture hero)
  static const generateStudyEyebrow = 'generate_study.eyebrow';
  static const generateStudyHeadline = 'generate_study.headline';
  static const generateStudyScriptureTab = 'generate_study.scripture_tab';
  static const generateStudyChooseDepth = 'generate_study.choose_depth';

  /// "All {count}" link that opens the full depth chooser.
  static const generateStudyAllModes = 'generate_study.all_modes';
  static const generateStudyButtonGenerateShort =
      'generate_study.button_generate_short';
  static const generateStudyContinueReading = 'generate_study.continue_reading';
  static const generateStudySeeAll = 'generate_study.see_all';

  // Recent Guides Section
  static const recentGuidesTitle = 'recent_guides.title';
  static const recentGuidesViewAll = 'recent_guides.view_all';
  static const recentGuidesEmpty = 'recent_guides.empty';
  static const recentGuidesEmptyMessage = 'recent_guides.empty_message';
  static const recentGuidesAuthRequired = 'recent_guides.auth_required';
  static const recentGuidesAuthMessage = 'recent_guides.auth_message';
  static const recentGuidesSignIn = 'recent_guides.sign_in';
  static const recentGuidesError = 'recent_guides.error';
  static const recentGuidesErrorMessage = 'recent_guides.error_message';
  static const recentGuidesJustNow = 'recent_guides.just_now';
  static const recentGuidesDaysAgo = 'recent_guides.days_ago';
  static const recentGuidesHoursAgo = 'recent_guides.hours_ago';
  static const recentGuidesMinutesAgo = 'recent_guides.minutes_ago';

  // Login Screen
  static const loginWelcome = 'login.welcome';
  static const loginSubtitle = 'login.subtitle';
  static const loginContinueWithGoogle = 'login.continue_with_google';
  static const loginContinueWithApple = 'login.continue_with_apple';

  static const loginFeaturesTitle = 'login.features_title';
  static const loginFeatureAiStudyGuides = 'login.feature_ai_study_guides';
  static const loginFeatureAiStudyGuidesSubtitle =
      'login.feature_ai_study_guides_subtitle';
  static const loginFeatureStructuredLearning =
      'login.feature_structured_learning';
  static const loginFeatureStructuredLearningSubtitle =
      'login.feature_structured_learning_subtitle';
  static const loginFeatureMultiLanguage = 'login.feature_multi_language';
  static const loginFeatureMultiLanguageSubtitle =
      'login.feature_multi_language_subtitle';
  static const loginFeatureDailyVerse = 'login.feature_daily_verse';
  static const loginFeatureDailyVerseSubtitle =
      'login.feature_daily_verse_subtitle';
  static const loginFeatureVoiceDiscipler = 'login.feature_voice_discipler';
  static const loginFeatureVoiceDisciplerSubtitle =
      'login.feature_voice_discipler_subtitle';
  static const loginFeatureMemoryVerse = 'login.feature_memory_verse';
  static const loginFeatureMemoryVerseSubtitle =
      'login.feature_memory_verse_subtitle';
  static const loginPrivacyPolicy = 'login.privacy_policy';
  static const loginTermsOfUse = 'login.terms_of_use';
  static const loginTermsAnd = 'login.terms_and';
  static const loginPrivacyPolicyLink = 'login.privacy_policy_link';
  static const loginTermsNotice = 'login.terms_notice';
  static const loginTermsNoticeSuffix = 'login.terms_notice_suffix';
  static const loginContinueWithEmail = 'login.continue_with_email';
  static const loginChipStudyGuides = 'login.chip_study_guides';
  static const loginChipDailyVerse = 'login.chip_daily_verse';
  static const loginChipDiscipler = 'login.chip_discipler';
  static const loginChipMemoryVerses = 'login.chip_memory_verses';
  static const loginLanguagesLine = 'login.languages_line';

  // Email Auth Screen
  static const emailAuthTitle = 'email_auth.title';
  static const emailAuthSignIn = 'email_auth.sign_in';
  static const emailAuthSignUp = 'email_auth.sign_up';
  static const emailAuthEmail = 'email_auth.email';
  static const emailAuthEmailHint = 'email_auth.email_hint';
  static const emailAuthPassword = 'email_auth.password';
  static const emailAuthPasswordHint = 'email_auth.password_hint';
  static const emailAuthFullName = 'email_auth.full_name';
  static const emailAuthFullNameHint = 'email_auth.full_name_hint';
  static const emailAuthForgotPassword = 'email_auth.forgot_password';
  static const emailAuthSignInButton = 'email_auth.sign_in_button';
  static const emailAuthSignUpButton = 'email_auth.sign_up_button';
  static const emailAuthNoAccount = 'email_auth.no_account';
  static const emailAuthHaveAccount = 'email_auth.have_account';
  static const emailAuthCreateAccount = 'email_auth.create_account';
  static const emailAuthSignInLink = 'email_auth.sign_in_link';
  static const emailAuthInvalidEmail = 'email_auth.invalid_email';
  static const emailAuthInvalidPassword = 'email_auth.invalid_password';
  static const emailAuthInvalidName = 'email_auth.invalid_name';
  static const emailAuthEmailExists = 'email_auth.email_exists';
  static const emailAuthInvalidCredentials = 'email_auth.invalid_credentials';
  static const emailAuthWeakPassword = 'email_auth.weak_password';
  static const emailAuthSignInEyebrow = 'email_auth.sign_in_eyebrow';
  static const emailAuthSignUpEyebrow = 'email_auth.sign_up_eyebrow';
  static const emailAuthSignInTitle = 'email_auth.sign_in_title';
  static const emailAuthSignUpTitle = 'email_auth.sign_up_title';
  static const emailAuthNewPasswordHint = 'email_auth.new_password_hint';

  // Auth / profile-setup notices
  static const authSignInCancelled = 'auth_notices.sign_in_cancelled';
  static const authOtpCodeSent = 'auth_notices.otp_code_sent';
  static const authOtpIncomplete = 'auth_notices.otp_incomplete';
  static const profileSetupImageWebOnly = 'auth_notices.profile_image_web_only';
  static const profileSetupImageFailed = 'auth_notices.profile_image_failed';
  static const profileSetupSelectAgeGroup =
      'auth_notices.profile_select_age_group';
  static const profileSetupSelectInterest =
      'auth_notices.profile_select_interest';

  // Phone sign-in and profile setup screens
  static const phoneAuthEyebrow = 'phone_auth.eyebrow';
  static const phoneAuthTitle = 'phone_auth.title';
  static const phoneAuthSubtitle = 'phone_auth.subtitle';
  static const phoneAuthPhoneLabel = 'phone_auth.phone_label';
  static const phoneAuthPhoneHint = 'phone_auth.phone_hint';
  static const phoneAuthCountryCode = 'phone_auth.country_code';
  static const phoneAuthPhoneRequired = 'phone_auth.phone_required';
  static const phoneAuthPhoneTooShort = 'phone_auth.phone_too_short';
  static const phoneAuthSecureTitle = 'phone_auth.secure_title';
  static const phoneAuthSecureBody = 'phone_auth.secure_body';
  static const phoneAuthSendCode = 'phone_auth.send_code';
  static const phoneAuthOtpEyebrow = 'phone_auth.otp_eyebrow';
  static const phoneAuthOtpTitle = 'phone_auth.otp_title';
  static const phoneAuthOtpSentTo = 'phone_auth.otp_sent_to';
  static const phoneAuthOtpLabel = 'phone_auth.otp_label';
  static const phoneAuthOtpDigit = 'phone_auth.otp_digit';
  static const phoneAuthOtpExpiresIn = 'phone_auth.otp_expires_in';
  static const phoneAuthOtpResend = 'phone_auth.otp_resend';
  static const phoneAuthOtpResendIn = 'phone_auth.otp_resend_in';
  static const phoneAuthOtpHelp = 'phone_auth.otp_help';
  static const phoneAuthOtpVerify = 'phone_auth.otp_verify';
  static const profileSetupEyebrow = 'profile_setup.eyebrow';
  static const profileSetupTitle = 'profile_setup.title';
  static const profileSetupSubtitle = 'profile_setup.subtitle';
  static const profileSetupAddPhoto = 'profile_setup.add_photo';
  static const profileSetupName = 'profile_setup.name';
  static const profileSetupFirstName = 'profile_setup.first_name';
  static const profileSetupLastName = 'profile_setup.last_name';
  static const profileSetupFirstNameRequired =
      'profile_setup.first_name_required';
  static const profileSetupLastNameRequired =
      'profile_setup.last_name_required';
  static const profileSetupAgeGroup = 'profile_setup.age_group';
  static const profileSetupInterests = 'profile_setup.interests';
  static const profileSetupInterestsHint = 'profile_setup.interests_hint';
  static const profileSetupContinue = 'profile_setup.continue';
  static const profileSetupInterestPrayer = 'profile_setup.interest_prayer';
  static const profileSetupInterestWorship = 'profile_setup.interest_worship';
  static const profileSetupInterestCommunity =
      'profile_setup.interest_community';
  static const profileSetupInterestBibleStudy =
      'profile_setup.interest_bible_study';
  static const profileSetupInterestTheology = 'profile_setup.interest_theology';
  static const profileSetupInterestMissions = 'profile_setup.interest_missions';
  static const profileSetupInterestYouthMinistry =
      'profile_setup.interest_youth_ministry';
  static const profileSetupInterestFamily = 'profile_setup.interest_family';
  static const profileSetupInterestLeadership =
      'profile_setup.interest_leadership';
  static const profileSetupInterestEvangelism =
      'profile_setup.interest_evangelism';

  // Password Reset Screen
  static const passwordResetTitle = 'password_reset.title';
  static const passwordResetSubtitle = 'password_reset.subtitle';
  static const passwordResetEmail = 'password_reset.email';
  static const passwordResetEmailHint = 'password_reset.email_hint';
  static const passwordResetSendButton = 'password_reset.send_button';
  static const passwordResetBackToSignIn = 'password_reset.back_to_sign_in';
  static const passwordResetSuccess = 'password_reset.success';
  static const passwordResetSuccessTitle = 'password_reset.success_title';
  static const passwordResetSuccessMessage = 'password_reset.success_message';
  static const passwordResetInvalidEmail = 'password_reset.invalid_email';
  static const passwordResetResend = 'password_reset.resend';
  static const passwordResetError = 'password_reset.error';
  static const passwordResetEyebrow = 'password_reset.eyebrow';

  // Email Verification Banner
  static const emailVerificationTitle = 'email_verification.title';
  static const emailVerificationDescription = 'email_verification.description';
  static const emailVerificationResend = 'email_verification.resend';
  static const emailVerificationResendShort = 'email_verification.resend_short';
  static const emailVerificationSent = 'email_verification.sent';

  // Onboarding
  static const onboardingWelcome = 'onboarding.welcome';
  static const onboardingSelectLanguageSubtitle =
      'onboarding.select_language_subtitle';
  static const onboardingSelectLanguage = 'onboarding.select_language';
  static const onboardingContinue = 'onboarding.continue';
  static const onboardingSkip = 'onboarding.skip';
  static const onboardingLanguageSavedLocally =
      'onboarding.language_saved_locally';
  static const onboardingDefaultLanguageSet = 'onboarding.default_language_set';
  static const onboardingLanguageSaveFailed = 'onboarding.language_save_failed';
  static const onboardingSkipIntro = 'onboarding.skip_intro';
  static const onboardingGetStarted = 'onboarding.get_started';
  static const onboardingLanguageEyebrow = 'onboarding.language_eyebrow';
  static const onboardingLanguageDefault = 'onboarding.language_default';
  static const onboardingSlide1Eyebrow = 'onboarding.slide1_eyebrow';
  static const onboardingSlide1Title = 'onboarding.slide1_title';
  static const onboardingSlide1Description = 'onboarding.slide1_description';
  static const onboardingSlide1Verse = 'onboarding.slide1_verse';
  static const onboardingSlide2Eyebrow = 'onboarding.slide2_eyebrow';
  static const onboardingSlide2Title = 'onboarding.slide2_title';
  static const onboardingSlide2Description = 'onboarding.slide2_description';
  static const onboardingSlide2Verse = 'onboarding.slide2_verse';
  static const onboardingSlide3Eyebrow = 'onboarding.slide3_eyebrow';
  static const onboardingSlide3Title = 'onboarding.slide3_title';
  static const onboardingSlide3Description = 'onboarding.slide3_description';
  static const onboardingSlide3Verse = 'onboarding.slide3_verse';
  static const onboardingSlide4Eyebrow = 'onboarding.slide4_eyebrow';
  static const onboardingSlide4Title = 'onboarding.slide4_title';
  static const onboardingSlide4Description = 'onboarding.slide4_description';
  static const onboardingSlide4Verse = 'onboarding.slide4_verse';
  static const onboardingPreviewTopicMeta = 'onboarding.preview_topic_meta';
  static const onboardingPreviewTopic = 'onboarding.preview_topic';
  static const onboardingPreviewSummary = 'onboarding.preview_summary';
  static const onboardingPreviewContext = 'onboarding.preview_context';
  static const onboardingPreviewInterpretation =
      'onboarding.preview_interpretation';
  static const onboardingPreviewVerseOfDay = 'onboarding.preview_verse_of_day';
  static const onboardingPreviewStudyNow = 'onboarding.preview_study_now';
  static const onboardingPreviewScriptureMeta =
      'onboarding.preview_scripture_meta';
  static const onboardingPreviewSummaryBody = 'onboarding.preview_summary_body';
  static const onboardingPreviewContextBody = 'onboarding.preview_context_body';
  static const onboardingPreviewListening = 'onboarding.preview_listening';
  static const onboardingPreviewQuestion = 'onboarding.preview_question';
  static const onboardingPreviewAnswer = 'onboarding.preview_answer';
  static const onboardingPreviewReviewMeta = 'onboarding.preview_review_meta';
  static const onboardingPreviewBlankStart = 'onboarding.preview_blank_start';
  static const onboardingPreviewBlankEnd = 'onboarding.preview_blank_end';
  static const onboardingPreviewAgain = 'onboarding.preview_again';
  static const onboardingPreviewGood = 'onboarding.preview_good';
  static const onboardingPreviewEasy = 'onboarding.preview_easy';

  // Settings Screen
  static const settingsTitle = 'settings.title';
  static const settingsAccount = 'settings.account';
  static const settingsEditNameTitle = 'settings.edit_name_title';
  static const settingsEditNameHint = 'settings.edit_name_hint';
  static const settingsEditNameSave = 'settings.edit_name_save';
  static const settingsEditNameSuccess = 'settings.edit_name_success';
  static const settingsEditNameFailed = 'settings.edit_name_failed';
  static const settingsEditNameInvalid = 'settings.edit_name_invalid';
  static const settingsSignInToSync = 'settings.sign_in_to_sync';
  static const settingsSignInToSavePreferences =
      'settings.sign_in_to_save_preferences';
  static const settingsSignIn = 'settings.sign_in';
  static const settingsMyPlan = 'settings.my_plan';
  static const settingsMyPlanSubtitle = 'settings.my_plan_subtitle';
  static const settingsAppearance = 'settings.appearance';
  static const settingsNotifications = 'settings.notifications';
  static const settingsNotificationPreferences =
      'settings.notification_preferences';
  static const settingsNotificationSubtitle = 'settings.notification_subtitle';
  static const settingsBlockedUsers = 'settings.blocked_users';
  static const settingsBlockedUsersSubtitle = 'settings.blocked_users_subtitle';
  static const settingsTheme = 'settings.theme';
  static const settingsContentLanguage = 'settings.content_language';
  static const settingsContentLanguageFollowsApp =
      'settings.content_language_follows_app';
  static const settingsAppLanguage = 'settings.app_language';
  static const settingsAppLanguageDescription =
      'settings.app_language_description';
  static const settingsAccountActions = 'settings.account_actions';
  static const settingsSignOut = 'settings.sign_out';
  static const settingsSaveProgress = 'settings.save_progress';
  static const settingsSaveProgressSubtitle = 'settings.save_progress_subtitle';
  static const settingsGuestNote = 'settings.guest_note';
  static const settingsDeleteAccount = 'settings.delete_account';
  static const settingsDeleteAccountSubtitle =
      'settings.delete_account_subtitle';
  static const settingsDeleteAccountTitle = 'settings.delete_account_title';
  static const settingsDeleteAccountMessage = 'settings.delete_account_message';
  static const settingsDeleteAccountConfirm = 'settings.delete_account_confirm';

  static const settingsSignOutOfAccount = 'settings.sign_out_of_account';
  static const settingsAbout = 'settings.about';
  static const settingsAppVersion = 'settings.app_version';
  static const settingsSupportDeveloper = 'settings.support_developer';
  static const settingsSupportDeveloperSubtitle =
      'settings.support_developer_subtitle';
  static const settingsPrivacyPolicy = 'settings.privacy_policy';
  static const settingsPrivacyPolicySubtitle =
      'settings.privacy_policy_subtitle';
  static const settingsTermsOfService = 'settings.terms_of_service';
  static const settingsTermsOfServiceSubtitle =
      'settings.terms_of_service_subtitle';
  static const settingsRefundPolicy = 'settings.refund_policy';
  static const settingsRefundPolicySubtitle = 'settings.refund_policy_subtitle';
  static const settingsFeedback = 'settings.feedback';
  static const settingsFeedbackSubtitle = 'settings.feedback_subtitle';
  static const settingsFailedToLoad = 'settings.failed_to_load';
  static const settingsSelectTheme = 'settings.select_theme';
  static const settingsSystemDefault = 'settings.system_default';
  static const settingsSystemDefaultSubtitle =
      'settings.system_default_subtitle';
  static const settingsLightMode = 'settings.light_mode';
  static const settingsLightModeSubtitle = 'settings.light_mode_subtitle';
  static const settingsDarkMode = 'settings.dark_mode';
  static const settingsDarkModeSubtitle = 'settings.dark_mode_subtitle';
  static const settingsSelectLanguage = 'settings.select_language';
  static const settingsSignOutTitle = 'settings.sign_out_title';
  static const settingsSignOutMessage = 'settings.sign_out_message';
  static const settingsSupportTitle = 'settings.support_title';
  static const settingsSupportMessage = 'settings.support_message';
  static const settingsClose = 'settings.close';
  static const settingsSupport = 'settings.support';
  static const settingsTipThanks = 'settings.tip_thanks';
  static const settingsTipUnavailable = 'settings.tip_unavailable';
  static const settingsNoEmail = 'settings.no_email';

  // Settings - Personalization
  static const settingsPersonalization = 'settings.personalization';
  static const settingsRetakeQuestionnaire = 'settings.retake_questionnaire';
  static const settingsRetakeQuestionnaireSubtitle =
      'settings.retake_questionnaire_subtitle';
  static const settingsTakeQuestionnaire = 'settings.take_questionnaire';
  static const settingsTakeQuestionnaireSubtitle =
      'settings.take_questionnaire_subtitle';

  // Settings - Text Size
  static const settingsTextSize = 'settings.text_size';
  static const settingsTextSizeSubtitle = 'settings.text_size_subtitle';
  static const settingsTextSizeSmall = 'settings.text_size_small';
  static const settingsTextSizeNormal = 'settings.text_size_normal';
  static const settingsTextSizeLarge = 'settings.text_size_large';
  static const settingsTextSizeExtraLarge = 'settings.text_size_extra_large';
  static const settingsTextSizePercentage = 'settings.text_size_percentage';

  // Settings (grouped cards)
  static const settingsSectionYou = 'settings.section_you';
  static const settingsSectionPreferences = 'settings.section_preferences';
  static const settingsSectionStudy = 'settings.section_study';
  static const settingsMore = 'settings.more';
  static const settingsMoreSubtitle = 'settings.more_subtitle';
  static const settingsOfflineGuides = 'settings.offline_guides';
  static const settingsOfflineGuidesSubtitle =
      'settings.offline_guides_subtitle';
  static const settingsOfflineGuidesCount = 'settings.offline_guides_count';
  static const settingsOfflineClearAll = 'settings.offline_clear_all';
  static const settingsOfflineRemove = 'settings.offline_remove';
  static const settingsOfflineEmptyTitle = 'settings.offline_empty_title';
  static const settingsOfflineEmptySubtitle = 'settings.offline_empty_subtitle';
  static const settingsOfflinePathEmpty = 'settings.offline_path_empty';
  static const settingsOfflinePathProgress = 'settings.offline_path_progress';
  static const settingsOfflineClearAllTitle =
      'settings.offline_clear_all_title';
  static const settingsOfflineClearAllMessage =
      'settings.offline_clear_all_message';
  static const settingsThemeSystem = 'settings.theme_system';
  static const settingsThemeLight = 'settings.theme_light';
  static const settingsThemeDark = 'settings.theme_dark';
  static const settingsThemeSystemCaption = 'settings.theme_system_caption';
  static const settingsLanguageDefault = 'settings.language_default';
  static const settingsDeleteAccountLoseTitle =
      'settings.delete_account_lose_title';
  static const settingsDeleteAccountLoseGuides =
      'settings.delete_account_lose_guides';
  static const settingsDeleteAccountLoseVerses =
      'settings.delete_account_lose_verses';
  static const settingsDeleteAccountLoseProgress =
      'settings.delete_account_lose_progress';
  static const settingsDeleteAccountLosePlan =
      'settings.delete_account_lose_plan';
  static const settingsBibleAttribution = 'settings.bible_attribution';
  static const settingsBibleAttributionSubtitle =
      'settings.bible_attribution_subtitle';

  // Settings - Help & Support
  static const settingsHelpSupport = 'settings.help_support';
  static const settingsReportPurchaseIssue = 'settings.report_purchase_issue';
  static const settingsReportPurchaseIssueSubtitle =
      'settings.report_purchase_issue_subtitle';
  static const settingsContactUs = 'settings.contact_us';
  static const settingsContactUsSubtitle = 'settings.contact_us_subtitle';
  static const settingsContactEmail = 'settings.contact_email';
  static const settingsContactError = 'settings.contact_error';
  static const settingsReplayWalkthrough = 'settings.replay_walkthrough';
  static const settingsReplayWalkthroughSubtitle =
      'settings.replay_walkthrough_subtitle';
  static const settingsReplayWalkthroughSuccess =
      'settings.replay_walkthrough_success';
  static const settingsReplayWalkthroughError =
      'settings.replay_walkthrough_error';

  // Personalization Questionnaire - Common
  static const questionnaireYourJourney = 'questionnaire.your_journey';
  static const questionnaireYourGoals = 'questionnaire.your_goals';
  static const questionnaireYourTime = 'questionnaire.your_time';
  static const questionnaireYourStyle = 'questionnaire.your_style';
  static const questionnaireYourFocus = 'questionnaire.your_focus';
  static const questionnaireYourChallenge = 'questionnaire.your_challenge';
  static const questionnairePersonalize = 'questionnaire.personalize';
  static const questionnaireSkip = 'questionnaire.skip';
  static const questionnaireContinue = 'questionnaire.continue';
  static const questionnaireBack = 'questionnaire.back';
  static const questionnaireDone = 'questionnaire.done';
  static const questionnaireSkipTitle = 'questionnaire.skip_title';
  static const questionnaireSkipMessage = 'questionnaire.skip_message';
  static const questionnaireCancel = 'questionnaire.cancel';
  static const questionnaireStepOf = 'questionnaire.step_of';

  // Memory verse add feedback (Home verse bookmark snackbars)
  static const memoryAddFeedbackAdded = 'memory_add_feedback.added';
  static const memoryAddFeedbackReviewNow = 'memory_add_feedback.review_now';
  static const memoryAddFeedbackAlreadyExists =
      'memory_add_feedback.already_exists';
  static const memoryAddFeedbackLimitReached =
      'memory_add_feedback.limit_reached';
  static const memoryAddFeedbackQueued = 'memory_add_feedback.queued';
  static const memoryAddFeedbackReview = 'memory_add_feedback.review';

  // Streak protection (freeze day) dialog
  static const streakProtectionEyebrow = 'streak_protection.eyebrow';
  static const streakProtectionTitle = 'streak_protection.title';
  static const streakProtectionAtRisk = 'streak_protection.at_risk';
  static const streakProtectionExplanation = 'streak_protection.explanation';
  static const streakProtectionAvailable = 'streak_protection.available';
  static const streakProtectionEarnMore = 'streak_protection.earn_more';
  static const streakProtectionCancel = 'streak_protection.cancel';
  static const streakProtectionUse = 'streak_protection.use';

  // Streak milestone celebration dialog
  static const streakMilestoneEyebrow = 'streak_milestone.eyebrow';
  static const streakMilestoneTitleDays = 'streak_milestone.title_days';
  static const streakMilestoneTitleYear = 'streak_milestone.title_year';
  static const streakMilestoneMessage10 = 'streak_milestone.message_10';
  static const streakMilestoneMessage30 = 'streak_milestone.message_30';
  static const streakMilestoneMessage100 = 'streak_milestone.message_100';
  static const streakMilestoneMessage365 = 'streak_milestone.message_365';
  static const streakMilestoneMessageDefault =
      'streak_milestone.message_default';
  static const streakMilestoneContinue = 'streak_milestone.continue';

  // Question 1: Faith Stage
  static const questionnaireFaithStageTitle = 'questionnaire.faith_stage.title';
  static const questionnaireFaithStageSubtitle =
      'questionnaire.faith_stage.subtitle';
  static const questionnaireFaithStageNewBeliever =
      'questionnaire.faith_stage.new_believer';
  static const questionnaireFaithStageGrowingBeliever =
      'questionnaire.faith_stage.growing_believer';
  static const questionnaireFaithStageCommittedDisciple =
      'questionnaire.faith_stage.committed_disciple';

  // Question 2: Spiritual Goals
  static const questionnaireSpiritualGoalsTitle =
      'questionnaire.spiritual_goals.title';
  static const questionnaireSpiritualGoalsSubtitle =
      'questionnaire.spiritual_goals.subtitle';
  static const questionnaireSpiritualGoalsFoundationalFaith =
      'questionnaire.spiritual_goals.foundational_faith';
  static const questionnaireSpiritualGoalsSpiritualDepth =
      'questionnaire.spiritual_goals.spiritual_depth';
  static const questionnaireSpiritualGoalsRelationships =
      'questionnaire.spiritual_goals.relationships';
  static const questionnaireSpiritualGoalsApologetics =
      'questionnaire.spiritual_goals.apologetics';
  static const questionnaireSpiritualGoalsService =
      'questionnaire.spiritual_goals.service';
  static const questionnaireSpiritualGoalsTheology =
      'questionnaire.spiritual_goals.theology';
  static const questionnaireSpiritualGoalsSelectionCounter =
      'questionnaire.spiritual_goals.selection_counter';

  // Question 3: Time Availability
  static const questionnaireTimeAvailabilityTitle =
      'questionnaire.time_availability.title';
  static const questionnaireTimeAvailabilitySubtitle =
      'questionnaire.time_availability.subtitle';
  static const questionnaireTimeAvailability5To10Min =
      'questionnaire.time_availability.5_to_10_min';
  static const questionnaireTimeAvailability10To20Min =
      'questionnaire.time_availability.10_to_20_min';
  static const questionnaireTimeAvailability20PlusMin =
      'questionnaire.time_availability.20_plus_min';

  // Question 4: Learning Style
  static const questionnaireLearningStyleTitle =
      'questionnaire.learning_style.title';
  static const questionnaireLearningStyleSubtitle =
      'questionnaire.learning_style.subtitle';
  static const questionnaireLearningStylePracticalApplication =
      'questionnaire.learning_style.practical_application';
  static const questionnaireLearningStyleDeepUnderstanding =
      'questionnaire.learning_style.deep_understanding';
  static const questionnaireLearningStyleReflectionMeditation =
      'questionnaire.learning_style.reflection_meditation';
  static const questionnaireLearningStyleBalancedApproach =
      'questionnaire.learning_style.balanced_approach';

  // Question 5: Life Stage Focus
  static const questionnaireLifeStageFocusTitle =
      'questionnaire.life_stage_focus.title';
  static const questionnaireLifeStageFocusSubtitle =
      'questionnaire.life_stage_focus.subtitle';
  static const questionnaireLifeStageFocusPersonalFoundation =
      'questionnaire.life_stage_focus.personal_foundation';
  static const questionnaireLifeStageFocusFamilyRelationships =
      'questionnaire.life_stage_focus.family_relationships';
  static const questionnaireLifeStageFocusCommunityImpact =
      'questionnaire.life_stage_focus.community_impact';
  static const questionnaireLifeStageFocusIntellectualGrowth =
      'questionnaire.life_stage_focus.intellectual_growth';

  // Question 6: Biggest Challenge
  static const questionnaireBiggestChallengeTitle =
      'questionnaire.biggest_challenge.title';
  static const questionnaireBiggestChallengeSubtitle =
      'questionnaire.biggest_challenge.subtitle';
  static const questionnaireBiggestChallengeStartingBasics =
      'questionnaire.biggest_challenge.starting_basics';
  static const questionnaireBiggestChallengeStayingConsistent =
      'questionnaire.biggest_challenge.staying_consistent';
  static const questionnaireBiggestChallengeHandlingDoubts =
      'questionnaire.biggest_challenge.handling_doubts';
  static const questionnaireBiggestChallengeSharingFaith =
      'questionnaire.biggest_challenge.sharing_faith';
  static const questionnaireBiggestChallengeGrowingStagnant =
      'questionnaire.biggest_challenge.growing_stagnant';

  // Saved Guides Screen
  static const savedGuidesTitle = 'saved_guides.title';
  static const savedGuidesSaved = 'saved_guides.saved';
  static const savedGuidesRecent = 'saved_guides.recent';
  static const savedGuidesEmptyTitle = 'saved_guides.empty_title';
  static const savedGuidesEmptyMessage = 'saved_guides.empty_message';
  static const savedGuidesRecentEmptyTitle = 'saved_guides.recent_empty_title';
  static const savedGuidesRecentEmptyMessage =
      'saved_guides.recent_empty_message';
  static const savedGuidesAuthRequired = 'saved_guides.auth_required';
  static const savedGuidesAuthMessage = 'saved_guides.auth_message';
  static const savedGuidesErrorTitle = 'saved_guides.error_title';
  static const savedGuidesErrorMessage = 'saved_guides.error_message';
  static const savedGuidesRetry = 'saved_guides.retry';
  static const savedGuidesLibraryTitle = 'saved_guides.library_title';
  static const savedGuidesSearch = 'saved_guides.search';
  static const savedGuidesSearchHint = 'saved_guides.search_hint';
  static const savedGuidesCloseSearch = 'saved_guides.close_search';
  static const savedGuidesNoResults = 'saved_guides.no_results';
  static const savedGuidesContinue = 'saved_guides.continue';
  static const savedGuidesContinueSection = 'saved_guides.continue_section';
  static const savedGuidesRemove = 'saved_guides.remove';
  static const savedGuidesSave = 'saved_guides.save';
  static const savedGuidesLoading = 'saved_guides.loading';
  static const savedGuidesYesterday = 'saved_guides.yesterday';

  // Popups (achievement, guide complete, upgrade, credits, sign-in)
  static const popupAchievementEyebrow = 'popups.achievement_eyebrow';
  static const popupAchievementCta = 'popups.achievement_cta';
  static const popupGuideCompleteEyebrow = 'popups.guide_complete_eyebrow';
  static const popupGuideCompleteNext = 'popups.guide_complete_next';
  static const popupGuideCompleteNextPath = 'popups.guide_complete_next_path';
  static const popupAddNotes = 'popups.add_notes';
  static const popupShareFellowship = 'popups.share_fellowship';
  static const popupAskDiscipler = 'popups.ask_discipler';
  static const popupDone = 'popups.done';
  static const popupContinuePath = 'popups.continue_path';
  static const popupNotNow = 'popups.not_now';
  static const popupUpgradeEyebrow = 'popups.upgrade_eyebrow';
  static const popupYourPlan = 'popups.your_plan';
  static const popupAvailableOn = 'popups.available_on';
  static const popupUpgradeNow = 'popups.upgrade_now';
  static const popupMaybeLater = 'popups.maybe_later';
  static const popupCreditsEyebrow = 'popups.credits_eyebrow';
  static const popupSignInEyebrow = 'popups.sign_in_eyebrow';
  static const savedGuidesUnsaveSuccess = 'saved_guides.unsave_success';
  static const savedGuidesUnsaveError = 'saved_guides.unsave_error';

  // Feedback Screen
  static const feedbackSendFeedback = 'feedback.send_feedback';
  static const feedbackSubtitle = 'feedback.subtitle';
  static const feedbackIsHelpful = 'feedback.is_helpful';
  static const feedbackYes = 'feedback.yes';
  static const feedbackNotYet = 'feedback.not_yet';
  static const feedbackTopic = 'feedback.topic';
  static const feedbackCategoryGeneral = 'feedback.category.general';
  static const feedbackCategoryBugReport = 'feedback.category.bug_report';
  static const feedbackCategoryFeatureRequest =
      'feedback.category.feature_request';
  static const feedbackCategoryContentFeedback =
      'feedback.category.content_feedback';
  static const feedbackCategoryStudyGuide = 'feedback.category.study_guide';
  static const feedbackCategoryMemoryVerse = 'feedback.category.memory_verse';
  static const feedbackHintText = 'feedback.hint_text';
  static const feedbackButtonSend = 'feedback.button_send';
  static const feedbackEmptyMessage = 'feedback.empty_message';
  static const feedbackSubmitError = 'feedback.submit_error';

  // Bug Report Screen
  static const bugReportTitle = 'bug_report.title';
  static const bugReportSubtitle = 'bug_report.subtitle';
  static const bugReportHintText = 'bug_report.hint_text';
  static const bugReportButtonReport = 'bug_report.button_report';
  static const bugReportEmptyMessage = 'bug_report.empty_message';
  static const bugReportSubmitError = 'bug_report.submit_error';

  // Study Topics Screen
  static const studyTopicsTitle = 'study_topics.title';
  static const studyTopicsSearchHint = 'study_topics.search_hint';
  static const studyTopicsGenerationError = 'study_topics.generation_error';
  static const studyTopicsGenerationInProgress =
      'study_topics.generation_in_progress';
  static const studyTopicsGenerating = 'study_topics.generating';
  static const studyTopicsFailedToLoad = 'study_topics.failed_to_load';
  static const studyTopicsSomethingWentWrong =
      'study_topics.something_went_wrong';
  static const studyTopicsTryAgain = 'study_topics.try_again';
  static const studyTopicsNoTopicsFound = 'study_topics.no_topics_found';
  static const studyTopicsAdjustFilters = 'study_topics.adjust_filters';
  static const studyTopicsNoTopicsAvailable =
      'study_topics.no_topics_available';
  static const studyTopicsClearFilters = 'study_topics.clear_filters';
  static const studyTopicsTopicsFound = 'study_topics.topics_found';
  static const studyTopicsContentLanguage = 'study_topics.content_language';
  static const studyTopicsContentLanguageDescription =
      'study_topics.content_language_description';
  static const studyTopicsContentLanguageDefault =
      'study_topics.content_language_default';
  static const studyTopicsContentLanguageDefaultDescription =
      'study_topics.content_language_default_description';
  static const moreOptionsTooltip = 'study_topics.more_options_tooltip';
  static const studyTopicsResetProgress = 'study_topics.reset_progress';
  static const studyTopicsResetProgressTitle =
      'study_topics.reset_progress_title';
  static const studyTopicsResetItemPaths = 'study_topics.reset_item_paths';
  static const studyTopicsResetItemTopics = 'study_topics.reset_item_topics';
  static const studyTopicsResetItemXp = 'study_topics.reset_item_xp';
  static const studyTopicsResetItemBadges = 'study_topics.reset_item_badges';
  static const studyTopicsResetSuccess = 'study_topics.reset_success';

  // Token Management - Main
  static const tokenManagementTitle = 'tokens.management.title';
  static const tokenManagementViewHistory = 'tokens.management.view_history';
  static const tokenManagementRefresh = 'tokens.management.refresh';
  static const tokenManagementRefreshStatus =
      'tokens.management.refresh_status';
  static const tokenManagementFailedToLoad = 'tokens.management.failed_to_load';
  static const tokenManagementLoadError = 'tokens.management.load_error';
  static const tokenManagementLoading = 'tokens.management.loading';
  static const tokenManagementActions = 'tokens.management.actions';
  static const tokenManagementPurchaseSuccess =
      'tokens.management.purchase_success';
  static const tokenManagementPurchaseFailed =
      'tokens.management.payment_failed';
  static const tokenManagementConfirmationFailed =
      'tokens.management.confirmation_failed';
  static const tokenManagementPaymentError = 'tokens.management.payment_error';
  static const tokenManagementOpenPaymentError =
      'tokens.management.open_payment_error';
  static const tokenManagementUpgradeComingSoon =
      'tokens.management.upgrade_coming_soon';

  // Token Management - Time Formatting
  static const tokenManagementJustNow = 'tokens.management.just_now';
  static const tokenManagementDayAgo = 'tokens.management.day_ago';
  static const tokenManagementDaysAgo = 'tokens.management.days_ago';
  static const tokenManagementHourAgo = 'tokens.management.hour_ago';
  static const tokenManagementHoursAgo = 'tokens.management.hours_ago';

  // Token Balance
  static const tokenBalanceCurrentBalance = 'tokens.balance.current_balance';
  static const tokenBalanceDailyLimit = 'tokens.balance.daily_limit';
  static const tokenBalanceAvailable = 'tokens.balance.available';
  static const tokenBalanceUsedToday = 'tokens.balance.used_today';
  static const tokenBalanceTimeUntilReset = 'tokens.balance.time_until_reset';
  static const tokenBalancePurchased = 'tokens.balance.purchased';
  static const tokenBalanceUnlimited = 'tokens.balance.unlimited';
  static const tokenBalanceRefresh = 'tokens.balance.refresh';

  // Token Purchase
  static const tokenPurchaseTitle = 'tokens.purchase.title';
  static const tokenPurchaseIapSuccess = 'tokens.purchase.iap_success';
  static const tokenPurchaseChoosePackage = 'tokens.purchase.choose_package';
  static const tokenPurchaseChooseAmount = 'tokens.purchase.choose_amount';
  static const tokenPurchaseCustom = 'tokens.purchase.custom';
  static const tokenPurchaseEnterAmount = 'tokens.purchase.enter_amount';
  static const tokenPurchaseTotalCost = 'tokens.purchase.total_cost';
  static const tokenPurchaseProcessing = 'tokens.purchase.processing';
  static const tokenPurchaseCreatingOrder = 'tokens.purchase.creating_order';
  static const tokenPurchaseRestricted = 'tokens.purchase.restricted';
  static const tokenPurchaseRestrictedFree = 'tokens.purchase.restricted_free';
  static const tokenPurchaseRestrictedPremium =
      'tokens.purchase.restricted_premium';
  static const tokenPurchaseRestrictedStandard =
      'tokens.purchase.restricted_standard';
  static const tokenPurchaseInsufficientTokens =
      'tokens.purchase.insufficient_tokens';

  // Plans
  static const plansCurrentPlan = 'tokens.plans.current_plan';
  static const plansFree = 'tokens.plans.free';
  static const plansStandard = 'tokens.plans.standard';
  static const plansPremium = 'tokens.plans.premium';
  static const plansFreeDesc = 'tokens.plans.free_description';
  static const plansStandardDesc = 'tokens.plans.standard_description';
  static const plansPremiumDesc = 'tokens.plans.premium_description';
  static const plansUpgrade = 'tokens.plans.upgrade';
  static const plansUpgradePlan = 'tokens.plans.upgrade_plan';
  static const plansUpgradeToStandard = 'tokens.plans.upgrade_to_standard';
  static const plansUpgradeToPremium = 'tokens.plans.upgrade_to_premium';
  static const plansGoPremium = 'tokens.plans.go_premium';
  static const plansManage = 'tokens.plans.manage';
  static const plansContinueSubscription = 'tokens.plans.continue_subscription';
  static const plansCancelledNotice = 'tokens.plans.cancelled_notice';
  static const plansComparison = 'tokens.plans.comparison';

  // Purchase History
  static const purchaseHistoryTitle = 'tokens.history.title';
  static const purchaseHistoryEmpty = 'tokens.history.empty';
  static const purchaseHistoryEmptyMessage = 'tokens.history.empty_message';
  static const purchaseHistoryFailed = 'tokens.history.failed';
  static const purchaseHistoryRetry = 'tokens.history.retry';
  static const purchaseHistoryTransactionDetails =
      'tokens.history.transaction_details';
  static const purchaseHistoryReceiptNumber = 'tokens.history.receipt_number';
  static const purchaseHistoryPurchaseDate = 'tokens.history.purchase_date';
  static const purchaseHistoryAmount = 'tokens.history.amount';
  static const purchaseHistoryTokens = 'tokens.history.tokens';

  // Payment Methods
  static const paymentMethodsSaved = 'tokens.payment.saved_methods';
  static const paymentMethodsAdd = 'tokens.payment.add_method';
  static const paymentMethodsSetDefault = 'tokens.payment.set_default';
  static const paymentMethodsDelete = 'tokens.payment.delete';
  static const paymentMethodsDeleteConfirm = 'tokens.payment.delete_confirm';
  static const paymentMethodsLastUsed = 'tokens.payment.last_used';
  static const paymentMethodsDefault = 'tokens.payment.default';
  static const paymentMethodsSaveSuccess = 'tokens.payment.save_success';
  static const paymentMethodsDeleteSuccess = 'tokens.payment.delete_success';
  static const paymentMethodsDefaultUpdated = 'tokens.payment.default_updated';

  // Payment Types
  static const paymentTypeCard = 'tokens.payment.types.card';
  static const paymentTypeUPI = 'tokens.payment.types.upi';
  static const paymentTypeNetBanking = 'tokens.payment.types.netbanking';
  static const paymentTypeWallet = 'tokens.payment.types.wallet';

  // Statistics
  static const statisticsTotalPurchases = 'tokens.stats.total_purchases';
  static const statisticsTotalSpent = 'tokens.stats.total_spent';
  static const statisticsTotalTokens = 'tokens.stats.total_tokens';
  static const statisticsAvgPerToken = 'tokens.stats.avg_per_token';
  static const statisticsLastPurchase = 'tokens.stats.last_purchase';
  static const statisticsSince = 'tokens.stats.since';
  static const statisticsFailedToLoad = 'tokens.stats.failed_to_load';

  // Premium Upgrade Page
  static const premiumUpgradeTitle = 'premium.upgrade_title';
  static const premiumDisciplefyPremium = 'premium.disciplefy_premium';
  static const premiumUnlockAccess = 'premium.unlock_access';
  static const premiumPriceMonth = 'premium.price_month';
  static const premiumCancelAnytime = 'premium.cancel_anytime';
  static const premiumPromoDiscount = 'premium.promo_discount';
  static const premiumWhatYouGet = 'premium.what_you_get';
  static const premiumUnlimitedTokens = 'premium.unlimited_tokens';
  static const premiumUnlimitedTokensDesc = 'premium.unlimited_tokens_desc';
  static const premiumUnlimitedFollowups = 'premium.unlimited_followups';
  static const premiumUnlimitedFollowupsDesc =
      'premium.unlimited_followups_desc';
  static const premiumAiModels = 'premium.ai_models';
  static const premiumAiModelsDesc = 'premium.ai_models_desc';
  static const premiumCompleteHistory = 'premium.complete_history';
  static const premiumCompleteHistoryDesc = 'premium.complete_history_desc';
  static const premiumPrioritySupport = 'premium.priority_support';
  static const premiumPrioritySupportDesc = 'premium.priority_support_desc';
  static const premiumAiDiscipler = 'premium.ai_discipler';
  static const premiumAiDisciplerDesc = 'premium.ai_discipler_desc';
  static const premiumPlanComparison = 'premium.plan_comparison';
  static const premiumDailyTokens = 'premium.daily_tokens';
  static const premiumFollowupQuestions = 'premium.followup_questions';
  static const premiumAiModel = 'premium.ai_model';
  static const premiumSupport = 'premium.support';
  static const premiumLimited = 'premium.limited';
  static const premiumUnlimited = 'premium.unlimited';
  static const premiumBasic = 'premium.basic';
  static const premiumPremiumModel = 'premium.premium_model';
  static const premiumStandard = 'premium.standard';
  static const premiumPriority = 'premium.priority';
  static const premiumUpgradeButton = 'premium.upgrade_button';
  static const premiumTermsAgree = 'premium.terms_agree';
  static const subscriptionTermsOfUse = 'premium.terms_of_use';
  static const subscriptionPrivacyPolicy = 'premium.privacy_policy';
  static const premiumSecurePayment = 'premium.secure_payment';
  static const premiumSubscriptionCreated = 'premium.subscription_created';
  static const premiumSubscriptionActivated = 'premium.subscription_activated';
  static const premiumPaymentCompletedHint = 'premium.payment_completed_hint';
  static const premiumCheckStatus = 'premium.check_status';

  // Payments feedback: checkout / invoice snackbars and the report-issue sheet
  static const payFeedbackSubscriptionCreated =
      'payments_feedback.subscription_created';
  static const payFeedbackPurchaseReceived =
      'payments_feedback.purchase_received';
  static const payFeedbackAwaitingApproval =
      'payments_feedback.payment_awaiting_approval';
  static const payFeedbackPlanActivated = 'payments_feedback.plan_activated';
  static const payFeedbackOpenPaymentUrlFailed =
      'payments_feedback.open_payment_url_failed';
  static const payFeedbackOpenPaymentPageFailed =
      'payments_feedback.open_payment_page_failed';
  static const payFeedbackStoreOpenFailedAndroid =
      'payments_feedback.store_open_failed_android';
  static const payFeedbackStoreOpenFailedIos =
      'payments_feedback.store_open_failed_ios';
  static const payFeedbackGeneratingPdf = 'payments_feedback.generating_pdf';
  static const payFeedbackInvoiceDownloaded =
      'payments_feedback.invoice_downloaded';
  static const payFeedbackInvoiceSavedTo = 'payments_feedback.invoice_saved_to';
  static const payFeedbackOk = 'payments_feedback.ok';
  static const payFeedbackSavePreferenceFailed =
      'payments_feedback.save_preference_failed';
  static const reportIssueEyebrow = 'payments_feedback.report_eyebrow';
  static const reportIssueTitle = 'payments_feedback.report_title';
  static const reportIssueBody = 'payments_feedback.report_body';
  static const reportIssueTransactionDetails =
      'payments_feedback.transaction_details';
  static const reportIssueTokens = 'payments_feedback.tokens';
  static const reportIssueAmount = 'payments_feedback.amount';
  static const reportIssueDate = 'payments_feedback.date';
  static const reportIssuePaymentId = 'payments_feedback.payment_id';
  static const reportIssueType = 'payments_feedback.issue_type';

  /// Label for a purchase issue type, keyed by its API value
  /// (e.g. `wrong_amount`).
  static String reportIssueTypeLabel(String value) =>
      'payments_feedback.issue_$value';
  static const reportIssueDescription = 'payments_feedback.description';
  static const reportIssueDescriptionHint =
      'payments_feedback.description_hint';
  static const reportIssueDescriptionTooShort =
      'payments_feedback.description_too_short';
  static const reportIssueScreenshots = 'payments_feedback.screenshots';
  static const reportIssueAddScreenshot = 'payments_feedback.add_screenshot';
  static const reportIssueUploadWebOnly = 'payments_feedback.upload_web_only';
  static const reportIssueSubmit = 'payments_feedback.submit';

  // Token Purchase Dialog
  static const tokenPurchaseDialogTitle = 'tokens.purchase_dialog.title';
  static const tokenPurchaseDialogSubtitle = 'tokens.purchase_dialog.subtitle';
  static const tokenPurchaseDialogCurrentBalance =
      'tokens.purchase_dialog.current_balance';
  static const tokenPurchaseDialogTokens = 'tokens.purchase_dialog.tokens';
  static const tokenPurchaseDialogSavedMethods =
      'tokens.purchase_dialog.saved_methods';
  static const tokenPurchaseDialogPackages = 'tokens.purchase_dialog.packages';
  static const tokenPurchaseDialogCustom = 'tokens.purchase_dialog.custom';
  static const tokenPurchaseDialogCustomTab =
      'tokens.purchase_dialog.custom_tab';
  static const tokenPurchaseDialogChooseSaved =
      'tokens.purchase_dialog.choose_saved';
  static const tokenPurchaseDialogChooseSavedMethod =
      'tokens.purchase_dialog.choose_saved_method';
  static const tokenPurchaseDialogChoosePackage =
      'tokens.purchase_dialog.choose_package';
  static const tokenPurchaseDialogChooseAmount =
      'tokens.purchase_dialog.choose_amount';
  static const tokenPurchaseDialogEnterCustom =
      'tokens.purchase_dialog.enter_custom';
  static const tokenPurchaseDialogTokenAmount =
      'tokens.purchase_dialog.token_amount';
  static const tokenPurchaseDialogAmountHint =
      'tokens.purchase_dialog.amount_hint';
  static const tokenPurchaseDialogPricingInfo =
      'tokens.purchase_dialog.pricing_info';
  static const tokenPurchaseDialogRate = 'tokens.purchase_dialog.rate';
  static const tokenPurchaseDialogMinimum = 'tokens.purchase_dialog.minimum';
  static const tokenPurchaseDialogMaximum = 'tokens.purchase_dialog.maximum';
  static const tokenPurchaseDialogCost = 'tokens.purchase_dialog.cost';
  static const tokenPurchaseDialogTotalCost =
      'tokens.purchase_dialog.total_cost';
  static const tokenPurchaseDialogForTokens =
      'tokens.purchase_dialog.for_tokens';
  static const tokenPurchaseDialogCancel = 'tokens.purchase_dialog.cancel';
  static const tokenPurchaseDialogSelectAmount =
      'tokens.purchase_dialog.select_amount';
  static const tokenPurchaseDialogPurchase = 'tokens.purchase_dialog.purchase';
  static const tokenPurchaseDialogCreatingOrder =
      'tokens.purchase_dialog.creating_order';
  static const tokenPurchaseDialogPaymentOpened =
      'tokens.purchase_dialog.payment_opened';
  static const tokenPurchaseDialogProcessing =
      'tokens.purchase_dialog.processing';
  static const tokenPurchaseDialogPopular = 'tokens.purchase_dialog.popular';
  static const tokenPurchaseDialogOff = 'tokens.purchase_dialog.off';
  static const tokenPurchaseDialogTokensPerRupee =
      'tokens.purchase_dialog.tokens_per_rupee';
  static const tokenPurchaseDialogDefault = 'tokens.purchase_dialog.default';
  static const tokenPurchaseDialogLastUsed = 'tokens.purchase_dialog.last_used';
  static const tokenPurchaseDialogPremiumMember =
      'tokens.purchase_dialog.premium_member';
  static const tokenPurchaseDialogPurchaseRestricted =
      'tokens.purchase_dialog.purchase_restricted';
  static const tokenPurchaseDialogUpgradePlan =
      'tokens.purchase_dialog.upgrade_plan';
  static const tokenPurchaseDialogGotIt = 'tokens.purchase_dialog.got_it';
  static const tokenPurchaseDialogContinue = 'tokens.purchase_dialog.continue';
  static const tokenPurchaseDialogMinutesAgo =
      'tokens.purchase_dialog.minutes_ago';
  static const tokenPurchaseDialogHoursAgo = 'tokens.purchase_dialog.hours_ago';
  static const tokenPurchaseDialogDaysAgo = 'tokens.purchase_dialog.days_ago';
  static const tokenPurchaseDialogPaymentMethodCard =
      'tokens.purchase_dialog.payment_method_card';
  static const tokenPurchaseDialogPaymentMethodUpi =
      'tokens.purchase_dialog.payment_method_upi';
  static const tokenPurchaseDialogPaymentMethodNetbanking =
      'tokens.purchase_dialog.payment_method_netbanking';
  static const tokenPurchaseDialogPaymentMethodWallet =
      'tokens.purchase_dialog.payment_method_wallet';
  static const tokenPurchaseDialogPaymentMethod =
      'tokens.purchase_dialog.payment_method';

  // Subscription Management Page
  static const subscriptionTitle = 'subscription.title';
  static const subscriptionRefresh = 'subscription.refresh';
  static const subscriptionNoActive = 'subscription.no_active';
  static const subscriptionUpgradePrompt = 'subscription.upgrade_prompt';
  static const subscriptionUpgradeButton = 'subscription.upgrade_button';
  static const subscriptionBillingInfo = 'subscription.billing_info';
  static const subscriptionAmount = 'subscription.amount';
  static const subscriptionPerMonth = 'subscription.per_month';
  static const subscriptionNextBilling = 'subscription.next_billing';
  static const subscriptionDaysUntilBilling = 'subscription.days_until_billing';
  static const subscriptionDays = 'subscription.days';
  static const subscriptionCurrentPeriodEnds =
      'subscription.current_period_ends';
  static const subscriptionPlanDetails = 'subscription.plan_details';
  static const subscriptionIncludedFeatures = 'subscription.included_features';
  static const subscriptionPlanType = 'subscription.plan_type';
  static const subscriptionSubscriptionType = 'subscription.subscription_type';
  static const subscriptionUnlimited = 'subscription.unlimited';
  static const subscriptionMonths = 'subscription.months';
  static const subscriptionCompletedCycles = 'subscription.completed_cycles';
  static const subscriptionRemainingCycles = 'subscription.remaining_cycles';
  static const subscriptionBillingCyclesCompleted =
      'subscription.billing_cycles_completed';
  static const subscriptionEndsIn = 'subscription.ends_in';
  static const subscriptionContinueButton = 'subscription.continue_button';
  static const subscriptionCancelAtEnd = 'subscription.cancel_at_end';
  static const subscriptionCancelImmediately =
      'subscription.cancel_immediately';
  static const subscriptionCancelEndTitle = 'subscription.cancel_end_title';
  static const subscriptionCancelImmediateTitle =
      'subscription.cancel_immediate_title';
  static const subscriptionCancelEndMessage = 'subscription.cancel_end_message';
  static const subscriptionCancelImmediateMessage =
      'subscription.cancel_immediate_message';
  static const subscriptionKeep = 'subscription.keep';
  static const subscriptionConfirmCancel = 'subscription.confirm_cancel';

  // Category Filter
  static const categoryFilterTitle = 'category_filter.title';
  static const categoryFilterClearAll = 'category_filter.clear_all';
  static const categoryFilterAll = 'category_filter.all';

  // Notifications Settings
  static const notificationsSettingsTitle = 'notifications.settings.title';
  static const notificationsSettingsSubtitle =
      'notifications.settings.subtitle';
  static const notificationsSettingsDailySectionTitle =
      'notifications.settings.daily_section_title';
  static const notificationsSettingsStreakSectionTitle =
      'notifications.settings.streak_section_title';
  static const notificationsSettingsLoading = 'notifications.settings.loading';
  static const notificationsSettingsPreferencesUpdated =
      'notifications.settings.preferences_updated';
  static const notificationsSettingsPermissionsGranted =
      'notifications.settings.permissions_granted';
  static const notificationsSettingsPermissionsDenied =
      'notifications.settings.permissions_denied';
  static const notificationsSettingsPreferencesTitle =
      'notifications.settings.preferences_title';
  static const notificationsSettingsDailyVerseTitle =
      'notifications.settings.daily_verse_title';
  static const notificationsSettingsDailyVerseDescription =
      'notifications.settings.daily_verse_description';
  static const notificationsSettingsRecommendedTopicsTitle =
      'notifications.settings.recommended_topics_title';
  static const notificationsSettingsRecommendedTopicsDescription =
      'notifications.settings.recommended_topics_description';
  static const notificationsSettingsPermissionTitle =
      'notifications.settings.permission_title';
  static const notificationsSettingsPermissionEnabled =
      'notifications.settings.permission_enabled';
  static const notificationsSettingsPermissionDisabled =
      'notifications.settings.permission_disabled';
  static const notificationsSettingsEnableButton =
      'notifications.settings.enable_button';
  static const notificationsSettingsAboutTitle =
      'notifications.settings.about_title';
  static const notificationsSettingsAboutInfo =
      'notifications.settings.about_info';
  static const notificationsSettingsErrorTitle =
      'notifications.settings.error_title';
  static const notificationsSettingsRetry = 'notifications.settings.retry';

  // Streak notification settings
  static const notificationsSettingsStreakReminderTitle =
      'notifications.settings.streak_reminder_title';
  static const notificationsSettingsStreakReminderDescription =
      'notifications.settings.streak_reminder_description';
  static const notificationsSettingsStreakMilestoneTitle =
      'notifications.settings.streak_milestone_title';
  static const notificationsSettingsStreakMilestoneDescription =
      'notifications.settings.streak_milestone_description';
  static const notificationsSettingsStreakLostTitle =
      'notifications.settings.streak_lost_title';
  static const notificationsSettingsStreakLostDescription =
      'notifications.settings.streak_lost_description';
  static const notificationsSettingsSetReminderTime =
      'notifications.settings.set_reminder_time';
  static const notificationsSettingsReminderTimeLabel =
      'notifications.settings.reminder_time_label';

  // Memory verse notification settings
  static const notificationsSettingsMemoryVerseSectionTitle =
      'notifications.settings.memory_verse_section_title';
  static const notificationsSettingsMemoryVerseReminderTitle =
      'notifications.settings.memory_verse_reminder_title';
  static const notificationsSettingsMemoryVerseReminderDescription =
      'notifications.settings.memory_verse_reminder_description';
  static const notificationsSettingsMemoryVerseOverdueTitle =
      'notifications.settings.memory_verse_overdue_title';
  static const notificationsSettingsMemoryVerseOverdueDescription =
      'notifications.settings.memory_verse_overdue_description';
  static const notificationsSettingsMemoryVerseReminderTimeLabel =
      'notifications.settings.memory_verse_reminder_time_label';

  // Push types added to notification settings
  static const notificationsSettingsStudySectionTitle =
      'notifications.settings.study_section_title';
  static const notificationsSettingsCommunitySectionTitle =
      'notifications.settings.community_section_title';
  static const notificationsSettingsDisciplerSectionTitle =
      'notifications.settings.discipler_section_title';
  static const notificationsSettingsMeetingsSectionTitle =
      'notifications.settings.meetings_section_title';
  static const notificationsSettingsContinueLearningTitle =
      'notifications.settings.continue_learning_title';
  static const notificationsSettingsContinueLearningDescription =
      'notifications.settings.continue_learning_description';
  static const notificationsSettingsAchievementTitle =
      'notifications.settings.achievement_title';
  static const notificationsSettingsAchievementDescription =
      'notifications.settings.achievement_description';
  static const notificationsSettingsFellowshipDailyPostTitle =
      'notifications.settings.fellowship_daily_post_title';
  static const notificationsSettingsFellowshipDailyPostDescription =
      'notifications.settings.fellowship_daily_post_description';
  static const notificationsSettingsFellowshipNewPostTitle =
      'notifications.settings.fellowship_new_post_title';
  static const notificationsSettingsFellowshipNewPostDescription =
      'notifications.settings.fellowship_new_post_description';
  static const notificationsSettingsMentionTitle =
      'notifications.settings.fellowship_mention_title';
  static const notificationsSettingsMentionDescription =
      'notifications.settings.fellowship_mention_description';
  static const notificationsSettingsMemberJoinedTitle =
      'notifications.settings.fellowship_member_joined_title';
  static const notificationsSettingsMemberJoinedDescription =
      'notifications.settings.fellowship_member_joined_description';
  static const notificationsSettingsFellowshipCommentTitle =
      'notifications.settings.fellowship_comment_title';
  static const notificationsSettingsFellowshipCommentDescription =
      'notifications.settings.fellowship_comment_description';
  static const notificationsSettingsFellowshipReactionTitle =
      'notifications.settings.fellowship_reaction_title';
  static const notificationsSettingsFellowshipReactionDescription =
      'notifications.settings.fellowship_reaction_description';
  static const notificationsSettingsDisciplerReplyTitle =
      'notifications.settings.discipler_reply_title';
  static const notificationsSettingsDisciplerReplyDescription =
      'notifications.settings.discipler_reply_description';
  static const notificationsSettingsDisciplerActivityTitle =
      'notifications.settings.discipler_activity_title';
  static const notificationsSettingsDisciplerActivityDescription =
      'notifications.settings.discipler_activity_description';
  static const notificationsSettingsMeetingNewTitle =
      'notifications.settings.meeting_new_title';
  static const notificationsSettingsMeetingNewDescription =
      'notifications.settings.meeting_new_description';
  static const notificationsSettingsMeetingInviteTitle =
      'notifications.settings.meeting_invite_title';
  static const notificationsSettingsMeetingInviteDescription =
      'notifications.settings.meeting_invite_description';
  static const notificationsSettingsMeetingReminderTitle =
      'notifications.settings.meeting_reminder_title';
  static const notificationsSettingsMeetingReminderDescription =
      'notifications.settings.meeting_reminder_description';
  static const notificationsSettingsMeetingCancelledTitle =
      'notifications.settings.meeting_cancelled_title';
  static const notificationsSettingsMeetingCancelledDescription =
      'notifications.settings.meeting_cancelled_description';

  static const notificationsSettingsMentorPromotedTitle =
      'notifications.settings.mentor_promoted_title';
  static const notificationsSettingsMentorPromotedDescription =
      'notifications.settings.mentor_promoted_description';

  // Memory Verses
  static const memorySaveTodaysVerse = 'memory.save_todays_verse';
  static const memoryAddVerse = 'memory.add_verse';
  static const memoryHeaderLine = 'memory.header_line';
  static const memoryHeaderLineOne = 'memory.header_line_one';
  static const memoryFootnote = 'memory.footnote';
  static const memoryMenuStatistics = 'memory.statistics';
  static const memoryMenuChampions = 'memory.champions';
  static const memoryDue = 'memory.due';
  static const memoryFilterByLanguage = 'memory.filterByLanguage';
  static const memoryAll = 'memory.all';
  static const memoryTitle = 'memory.title';
  static const memoryYourProgress = 'memory.yourProgress';
  static const memoryDueForReview = 'memory.dueForReview';
  static const memoryReview = 'memory.review';
  static const memoryHard = 'memory.hard';
  static const memoryGood = 'memory.good';
  static const memoryEasy = 'memory.easy';
  static const memoryDaysOverdue = 'memory.daysOverdue';
  static const memoryVersesToReviewSingular = 'memory.versesToReviewSingular';
  static const memoryVersesToReviewPlural = 'memory.versesToReviewPlural';
  static const memoryNoVersesInLanguage = 'memory.noVersesInLanguage';
  static const memoryTryDifferentFilter = 'memory.tryDifferentFilter';
  static const memoryDailyVerseNotLoaded = 'memory.dailyVerseNotLoaded';

  // Delete Verse
  static const memoryDeleteTitle = 'memory.delete.title';
  static const memoryDeleteConfirmation = 'memory.delete.confirmation';
  static const memoryDeleteCancel = 'memory.delete.cancel';
  static const memoryDeleteConfirm = 'memory.delete.confirm';
  static const memoryDeleteSuccess = 'memory.delete.success';

  // Review All
  static const memoryReviewAll = 'memory.reviewAll';
  static const memoryNoVersesToReview = 'memory.noVersesToReview';

  // Add Verse Dialog
  static const addVerseTitle = 'memory.addVerse.title';
  static const addVerseBook = 'memory.addVerse.book';
  static const addVerseChapter = 'memory.addVerse.chapter';
  static const addVerseVerse = 'memory.addVerse.verse';
  static const addVerseAll = 'memory.addVerse.all';
  static const addVerseTo = 'memory.addVerse.to';
  static const addVerseLanguage = 'memory.addVerse.language';
  static const addVerseFetch = 'memory.addVerse.fetch';
  static const addVerseFetching = 'memory.addVerse.fetching';
  static const addVerseText = 'memory.addVerse.verseText';
  static const addVerseTextHint = 'memory.addVerse.verseTextHint';
  static const addVerseCancel = 'memory.addVerse.cancel';
  static const addVerseAdd = 'memory.addVerse.add';
  static const addVerseSelectRequired = 'memory.addVerse.selectRequired';
  static const addVerseTextRequired = 'memory.addVerse.textRequired';

  // Verse Review Page
  static const reviewVerseTitle = 'memory.reviewPage.title';
  static const reviewVerseNotFound = 'memory.reviewPage.verseNotFound';
  static const reviewTapToReveal = 'memory.reviewPage.tapToReveal';
  static const reviewSkipForNow = 'memory.reviewPage.skipForNow';
  static const reviewRateReview = 'memory.reviewPage.rateReview';
  static const reviewSkipTitle = 'memory.reviewPage.skipTitle';
  static const reviewSkipContent = 'memory.reviewPage.skipContent';
  static const reviewCancel = 'memory.reviewPage.cancel';
  static const reviewSkip = 'memory.reviewPage.skip';

  // Flip Card
  static const flipCardTapToReveal = 'memory.flipCard.tapToReveal';
  static const flipCardReviewNumber = 'memory.flipCard.reviewNumber';
  static const flipCardDays = 'memory.flipCard.days';
  static const flipCardReviews = 'memory.flipCard.reviews';
  static const flipCardDayOne = 'memory.flipCard.day_one';
  static const flipCardReviewOne = 'memory.flipCard.review_one';

  // Options Menu
  static const optionsMenuSyncTitle = 'memory.optionsMenu.syncTitle';
  static const optionsMenuSyncSubtitle = 'memory.optionsMenu.syncSubtitle';
  static const optionsMenuStatsTitle = 'memory.optionsMenu.statsTitle';
  static const optionsMenuStatsSubtitle = 'memory.optionsMenu.statsSubtitle';
  static const optionsMenuChampionsTitle = 'memory.optionsMenu.championsTitle';
  static const optionsMenuChampionsSubtitle =
      'memory.optionsMenu.championsSubtitle';
  static const optionsMenuResetTitle = 'memory.optionsMenu.resetTitle';
  static const optionsMenuResetSubtitle = 'memory.optionsMenu.resetSubtitle';
  static const memoryResetTitle = 'memory.reset.title';
  static const memoryResetItemVerses = 'memory.reset.itemVerses';
  static const memoryResetItemProgress = 'memory.reset.itemProgress';
  static const memoryResetItemStreak = 'memory.reset.itemStreak';
  static const memoryResetItemBadges = 'memory.reset.itemBadges';
  static const memoryResetConfirm = 'memory.reset.confirm';
  static const memoryResetSuccess = 'memory.reset.success';

  // Statistics Dialog
  static const statsDialogTitle = 'memory.statsDialog.title';
  static const statsDialogTotalVerses = 'memory.statsDialog.totalVerses';
  static const statsDialogDueVerses = 'memory.statsDialog.dueVerses';
  static const statsDialogReviewedToday = 'memory.statsDialog.reviewedToday';
  static const statsDialogUpcoming = 'memory.statsDialog.upcoming';
  static const statsDialogMastered = 'memory.statsDialog.mastered';
  static const statsDialogMasteryRate = 'memory.statsDialog.masteryRate';
  static const statsDialogClose = 'memory.statsDialog.close';

  // Verse Rating Sheet
  static const ratingSheetTitle = 'memory.ratingSheet.title';
  static const ratingPerfectLabel = 'memory.ratingSheet.perfect.label';
  static const ratingPerfectDescription =
      'memory.ratingSheet.perfect.description';
  static const ratingGoodLabel = 'memory.ratingSheet.good.label';
  static const ratingGoodDescription = 'memory.ratingSheet.good.description';
  static const ratingHardLabel = 'memory.ratingSheet.hard.label';
  static const ratingHardDescription = 'memory.ratingSheet.hard.description';
  static const ratingWrongLabel = 'memory.ratingSheet.wrong.label';
  static const ratingWrongDescription = 'memory.ratingSheet.wrong.description';
  static const ratingBarelyLabel = 'memory.ratingSheet.barely.label';
  static const ratingBarelyDescription =
      'memory.ratingSheet.barely.description';
  static const ratingForgotLabel = 'memory.ratingSheet.forgot.label';
  static const ratingForgotDescription =
      'memory.ratingSheet.forgot.description';

  // Add Verse Options Sheet
  static const addMemoryVerseTitle = 'memory.addOptions.title';
  static const addFromDailyVerse = 'memory.addOptions.fromDaily';
  static const addFromDailyVerseDesc = 'memory.addOptions.fromDailyDesc';
  static const addSuggestedVerse = 'memory.addOptions.suggested';
  static const addSuggestedVerseDesc = 'memory.addOptions.suggestedDesc';
  static const addCustomVerse = 'memory.addOptions.custom';
  static const addCustomVerseDesc = 'memory.addOptions.customDesc';

  // Suggested Verses Sheet
  static const suggestedVersesTitle = 'memory.suggested.title';
  static const alreadyAdded = 'memory.suggested.alreadyAdded';
  static const addToMemoryDeck = 'memory.suggested.addToMemoryDeck';
  static const suggestedNoVersesFound = 'memory.suggested.noVersesFound';
  static const retry = 'memory.suggested.retry';

  // Suggested Verse Categories
  static const categoryAll = 'memory.category.all';
  static const categorySalvation = 'memory.category.salvation';
  static const categoryComfort = 'memory.category.comfort';
  static const categoryStrength = 'memory.category.strength';
  static const categoryWisdom = 'memory.category.wisdom';
  static const categoryPromise = 'memory.category.promise';
  static const categoryGuidance = 'memory.category.guidance';
  static const categoryFaith = 'memory.category.faith';
  static const categoryLove = 'memory.category.love';

  // Learning Paths
  static const learningPathsTitle = 'learning_paths.title';
  static const learningPathsSubtitle = 'learning_paths.subtitle';
  static const learningPathsViewMore = 'learning_paths.view_more';
  static const learningPathsViewLess = 'learning_paths.view_less';
  static const learningPathsEmpty = 'learning_paths.empty';
  static const learningPathsEmptyMessage = 'learning_paths.empty_message';
  static const learningPathsError = 'learning_paths.error';
  static const learningPathsErrorMessage = 'learning_paths.error_message';
  static const learningPathsCompleted = 'learning_paths.completed';

  // Memory verse status badges
  static const memoryFullyMastered = 'memory.fullyMastered';
  static const memoryReviewMilestone = 'memory.reviewMilestone';
  static const memoryPerfectRecalls = 'memory.perfectRecalls';

  // Study generation
  static const generateStudySermonOutlineNotice =
      'generate_study.sermon_outline_notice';
  static const learningPathsInProgress = 'learning_paths.in_progress';
  static const learningPathsFeatured = 'learning_paths.featured';
  static const learningPathsEnroll = 'learning_paths.enroll';
  static const learningPathsContinue = 'learning_paths.continue';
  static const learningPathsReview = 'learning_paths.review';
  static const learningPathsExplore = 'learning_paths.explore';
  static const learningPathsTopics = 'learning_paths.topics';
  static const learningPathsDays = 'learning_paths.days';
  static const learningPathsXp = 'learning_paths.xp';
  static const learningPathsProgress = 'learning_paths.progress';
  static const learningPathsTopicsCompleted = 'learning_paths.topics_completed';
  static const learningPathsStartPath = 'learning_paths.start_path';
  static const learningPathsStartLesson = 'learning_paths.start_lesson';
  static const learningPathsContinueLesson = 'learning_paths.continue_lesson';
  static const learningPathsReviewLesson = 'learning_paths.review_lesson';
  static const learningPathsResumePath = 'learning_paths.resume_path';
  static const learningPathsPathCompleted = 'learning_paths.path_completed';
  static const learningPathsEnrolledSuccess = 'learning_paths.enrolled_success';
  static const learningPathsEnrolledError = 'learning_paths.enrolled_error';
  static const learningPathsNextTopic = 'learning_paths.next_topic';
  static const learningPathsLocked = 'learning_paths.locked';
  static const learningPathsUnlocked = 'learning_paths.unlocked';
  static const learningPathsMilestone = 'learning_paths.milestone';
  static const learningPathsLoadingDetails = 'learning_paths.loading_details';
  static const learningPathsEnrolling = 'learning_paths.enrolling';
  static const learningPathsFailedToLoad = 'learning_paths.failed_to_load';
  static const learningPathsOfflineTitle = 'learning_paths.offline_title';
  static const learningPathsLoadingTopics = 'learning_paths.loading_topics';
  static const learningPathsPercentComplete = 'learning_paths.percent_complete';
  static const learningPathsLessonsDays = 'learning_paths.lessons_days';

  // Disciple Levels
  static const discipleLevelSeeker = 'disciple_level.seeker';
  static const discipleLevelBeliever = 'disciple_level.believer';
  static const discipleLevelDisciple = 'disciple_level.disciple';
  static const discipleLevelLeader = 'disciple_level.leader';
  // Offline download sheet / learning path downloads
  static const downloadsOfflineGuides = 'downloads.offline_guides';
  static const downloadsDownloadingOfflineGuides =
      'downloads.downloading_offline_guides';
  static const downloadsDownloadingProgress = 'downloads.downloading_progress';
  static const downloadsPartlyDownloaded = 'downloads.partly_downloaded';
  static const downloadsAllAvailableOffline = 'downloads.all_available_offline';
  static const downloadsPause = 'downloads.pause';
  static const downloadsDownloadMore = 'downloads.download_more';
  static const downloadsDownloadOneMore = 'downloads.download_one_more';
  static const downloadsRemoveAll = 'downloads.remove_all';
  static const downloadsSelectGuides = 'downloads.select_guides';
  static const downloadsSelectAll = 'downloads.select_all';
  static const downloadsDeselectAll = 'downloads.deselect_all';
  static const downloadsDownloadCount = 'downloads.download_count';
  static const downloadsDownloadCountWithCost =
      'downloads.download_count_with_cost';
  static const downloadsSelectAtLeastOne = 'downloads.select_at_least_one';
  static const downloadsGuidesWithCost = 'downloads.guides_with_cost';
  static const downloadsGuidesSelected = 'downloads.guides_selected';
  static const downloadsStatusDownloaded = 'downloads.status_downloaded';
  static const downloadsStatusDownloading = 'downloads.status_downloading';
  static const downloadsStatusFailed = 'downloads.status_failed';
  static const downloadsStatusWaiting = 'downloads.status_waiting';
  static const downloadsStatusNotDownloaded = 'downloads.status_not_downloaded';
  static const downloadsStatusNotQueued = 'downloads.status_not_queued';
  static const downloadsSharePath = 'downloads.share_path';
  static const downloadsShareFailed = 'downloads.share_failed';
  static const downloadsDownloadForOffline = 'downloads.download_for_offline';
  static const downloadsAvailableOffline = 'downloads.available_offline';
  static const downloadsNotDownloadedOffline =
      'downloads.not_downloaded_offline';
  static const downloadsGoBack = 'downloads.go_back';

  static const discipleLevelFollower = 'disciple_level.follower';

  // Topics tab: current path card, category "See all", "Browse all paths"
  static const topicsTitle = 'topics.title';
  static const topicsBrowseAll = 'topics.browse_all';
  static const topicsContinue = 'topics.continue';
  static const topicsStartAPath = 'topics.start_a_path';
  static const topicsSeeAll = 'topics.see_all';

  // All paths screen (category chips, current path pinned)
  static const allPathsTitle = 'all_paths.title';
  static const allPathsCount = 'all_paths.count';
  static const allPathsAll = 'all_paths.all';
  static const allPathsCurrent = 'all_paths.current';
  static const allPathsLessonOf = 'all_paths.lesson_of';

  // Study Topics tab (header cards, For you, Learning paths, category page)
  static const topicsHubContinueEyebrow = 'topics_hub.continue_eyebrow';
  static const topicsHubNextTopic = 'topics_hub.next_topic';
  static const topicsHubStreakValue = 'topics_hub.streak_value';
  static const topicsHubStreakValueOne = 'topics_hub.streak_value_one';
  static const topicsHubStreakLabel = 'topics_hub.streak_label';
  static const topicsHubLeaderboardLabel = 'topics_hub.leaderboard_label';
  static const topicsHubForYou = 'topics_hub.for_you';
  static const topicsHubBasedOnGoals = 'topics_hub.based_on_goals';
  static const topicsHubSearchPaths = 'topics_hub.search_paths';
  static const topicsHubSeeAll = 'topics_hub.see_all';
  static const topicsHubPathsCount = 'topics_hub.paths_count';
  static const topicsHubPathsCountOne = 'topics_hub.paths_count_one';
  static const topicsHubLevelRange = 'topics_hub.level_range';
  static const topicsHubOfflineMessage = 'topics_hub.offline_message';
  static const topicsHubRetry = 'topics_hub.retry';
  static const topicsHubNoSearchResults = 'topics_hub.no_search_results';
  static const topicsHubNoFilterResults = 'topics_hub.no_filter_results';
  static const topicsHubAllLevels = 'topics_hub.all_levels';

  // Continue Learning
  static const continueLearningTitle = 'continue_learning.title';
  static const continueLearningEmpty = 'continue_learning.empty';
  static const continueLearningEmptyMessage = 'continue_learning.empty_message';
  static const continueLearningDone = 'continue_learning.done';
  static const continueLearningInProgress = 'continue_learning.in_progress';
  static const continueLearningStart = 'continue_learning.start';
  static const continueLearningContinueAction =
      'continue_learning.continue_action';
  static const continueLearningOfDone = 'continue_learning.of_done';

  // Leaderboard
  static const leaderboardTitle = 'leaderboard.title';
  static const leaderboardTooltip = 'leaderboard.tooltip';
  static const leaderboardYourRank = 'leaderboard.your_rank';
  static const leaderboardXpPoints = 'leaderboard.xp_points';
  static const leaderboardClose = 'leaderboard.close';
  static const leaderboardError = 'leaderboard.error';

  // Leaderboard page redesign
  static const leaderboardXpToPass = 'leaderboard.xp_to_pass';

  // Pricing Page (Public)
  static const pricingTitle = 'pricing.title';
  static const pricingSubtitle = 'pricing.subtitle';
  static const pricingPerMonth = 'pricing.per_month';
  static const pricingFreeForYear = 'pricing.free_for_year';
  static const pricingLimitedTimeOffer = 'pricing.limited_time_offer';
  static const pricingGetStarted = 'pricing.get_started';
  static const pricingMostPopular = 'pricing.most_popular';
  static const pricingBestValue = 'pricing.best_value';
  static const pricingTokensDaily = 'pricing.tokens_daily';
  static const pricingUnlimitedTokens = 'pricing.unlimited_tokens';
  static const pricingFreePlan = 'pricing.free_plan';
  static const pricingStandardPlan = 'pricing.standard_plan';
  static const pricingPremiumPlan = 'pricing.premium_plan';
  // Free Plan Features
  static const pricingFreeFeature1 = 'pricing.free.feature1';
  static const pricingFreeFeature2 = 'pricing.free.feature2';
  static const pricingFreeFeature3 = 'pricing.free.feature3';
  static const pricingFreeFeature4 = 'pricing.free.feature4';
  // Standard Plan Features
  static const pricingStandardFeature1 = 'pricing.standard.feature1';
  static const pricingStandardFeature2 = 'pricing.standard.feature2';
  static const pricingStandardFeature3 = 'pricing.standard.feature3';
  static const pricingStandardFeature4 = 'pricing.standard.feature4';
  static const pricingStandardFeature5 = 'pricing.standard.feature5';
  // Premium Plan Features
  static const pricingPlusFeature1 = 'pricing.plus.feature1';
  static const pricingPlusFeature2 = 'pricing.plus.feature2';
  static const pricingPlusFeature3 = 'pricing.plus.feature3';
  static const pricingPlusFeature4 = 'pricing.plus.feature4';
  static const pricingPlusFeature5 = 'pricing.plus.feature5';
  static const pricingPlusFeature6 = 'pricing.plus.feature6';
  static const pricingPremiumFeature1 = 'pricing.premium.feature1';
  static const pricingPremiumFeature2 = 'pricing.premium.feature2';
  static const pricingPremiumFeature3 = 'pricing.premium.feature3';
  static const pricingPremiumFeature4 = 'pricing.premium.feature4';
  static const pricingPremiumFeature5 = 'pricing.premium.feature5';
  static const pricingPremiumFeature6 = 'pricing.premium.feature6';
  static const pricingSecurePayments = 'pricing.secure_payments';
  static const pricingPricesInInr = 'pricing.prices_in_inr';

  // My Plan Page
  static const myPlanTitle = 'my_plan.title';
  static const myPlanRefresh = 'my_plan.refresh';
  static const myPlanPlanFeatures = 'my_plan.plan_features';
  static const myPlanBillingDetails = 'my_plan.billing_details';
  static const myPlanRecentPayments = 'my_plan.recent_payments';
  static const myPlanViewAll = 'my_plan.view_all';
  static const myPlanViewPaymentHistory = 'my_plan.view_payment_history';
  static const myPlanAmount = 'my_plan.amount';
  static const myPlanNextBilling = 'my_plan.next_billing';
  static const myPlanAccessUntil = 'my_plan.access_until';
  static const myPlanStatus = 'my_plan.status';
  static const myPlanFreeUntil = 'my_plan.free_until';
  static const myPlanDaysRemaining = 'my_plan.days_remaining';
  static const myPlanTrialActive = 'my_plan.trial_active';
  static const myPlanTrialEndingSoon = 'my_plan.trial_ending_soon';
  static const myPlanPremiumTrialActive = 'my_plan.premium_trial_active';
  static const myPlanActiveSubscription = 'my_plan.active_subscription';
  static const myPlanCancellationPending = 'my_plan.cancellation_pending';
  static const myPlanGracePeriod = 'my_plan.grace_period';
  static const myPlanTrialExpired = 'my_plan.trial_expired';
  static const myPlanFreePlan = 'my_plan.free_plan';
  static const myPlanSubscriptionNeeded = 'my_plan.subscription_needed';
  static const myPlanGracePeriodActive = 'my_plan.grace_period_active';
  static const myPlanGracePeriodEndsSoon = 'my_plan.grace_period_ends_soon';
  static const myPlanSubscribeWithinDays = 'my_plan.subscribe_within_days';
  static const myPlanTrialEnded = 'my_plan.trial_ended';
  static const myPlanSubscribeToContinue = 'my_plan.subscribe_to_continue';
  static const myPlanUnlockStandardFeatures =
      'my_plan.unlock_standard_features';
  static const myPlanGetTokensDaily = 'my_plan.get_tokens_daily';
  static const myPlanEnjoyingPremium = 'my_plan.enjoying_premium';
  static const myPlanPremiumTrialEndsSoon = 'my_plan.premium_trial_ends_soon';
  static const myPlanDaysRemainingInTrial = 'my_plan.days_remaining_in_trial';
  static const myPlanTryPremiumFree = 'my_plan.try_premium_free';
  static const myPlanGet7DaysTrial = 'my_plan.get_7_days_trial';
  static const myPlanStart7DayTrial = 'my_plan.start_7_day_trial';
  static const myPlanTryAllFeaturesFree = 'my_plan.try_all_features_free';
  static const myPlanUpgradeToStandard = 'my_plan.upgrade_to_standard';
  static const myPlanUpgradeToPremium = 'my_plan.upgrade_to_premium';
  static const myPlanKeepPremiumAccess = 'my_plan.keep_premium_access';
  static const myPlanSubscribeToStandard = 'my_plan.subscribe_to_standard';
  static const myPlanAfterTrial = 'my_plan.after_trial';
  static const myPlanSubscribeNow = 'my_plan.subscribe_now';
  static const myPlanKeepStandardAccess = 'my_plan.keep_standard_access';
  static const myPlanGetAllFeatures = 'my_plan.get_all_features';
  static const myPlanRegainAccess = 'my_plan.regain_access';
  static const myPlanGetTokensDailyFor = 'my_plan.get_tokens_daily_for';
  static const myPlanUnlimitedTokensFor = 'my_plan.unlimited_tokens_for';
  static const myPlanContinueAfterTrial = 'my_plan.continue_after_trial';
  static const myPlanContinueSubscription = 'my_plan.continue_subscription';
  static const myPlanResumeSubscription = 'my_plan.resume_subscription';
  static const myPlanCancelSubscription = 'my_plan.cancel_subscription';
  static const myPlanCancelAtPeriodEnd = 'my_plan.cancel_at_period_end';
  static const myPlanResubscribe = 'my_plan.resubscribe';
  static const myPlanRenewSubscription = 'my_plan.renew_subscription';
  static const myPlanViewPlans = 'my_plan.view_plans';
  static const myPlanTrialPill = 'my_plan.trial_pill';
  static const myPlanFreeTrialUntil = 'my_plan.free_trial_until';
  static const myPlanTrialNoPayment = 'my_plan.trial_no_payment';
  static const myPlanNoFeatures = 'my_plan.no_features';

  // Study Guide Error Screen
  static const studyGuideErrorTitle = 'study_guide.error.title';
  static const studyGuideErrorTitleAlt = 'study_guide.error.title_alt';
  static const studyGuideErrorTitleNoTokens =
      'study_guide.error.title_no_tokens';
  static const studyGuideErrorDefaultMessage =
      'study_guide.error.default_message';
  static const studyGuideErrorDefaultMessageAlt =
      'study_guide.error.default_message_alt';
  static const studyGuideErrorNetwork = 'study_guide.error.network';
  static const studyGuideErrorServer = 'study_guide.error.server';
  static const studyGuideErrorAuth = 'study_guide.error.auth';
  static const studyGuideErrorInsufficientTokens =
      'study_guide.error.insufficient_tokens';
  static const studyGuideErrorGoBack = 'study_guide.error.go_back';
  static const studyGuideErrorTryAgain = 'study_guide.error.try_again';
  static const studyGuideErrorViewSaved = 'study_guide.error.view_saved';
  static const studyGuideErrorMyPlan = 'study_guide.error.my_plan';

  // Upgrade Required Dialog
  static const upgradeDialogTitle = 'upgrade_dialog.title';
  static const upgradeDialogStandardPlan = 'upgrade_dialog.standard_plan';
  static const upgradeDialogPrice = 'upgrade_dialog.price';
  static const upgradeDialogBenefitVoice = 'upgrade_dialog.benefit_voice';
  static const upgradeDialogBenefitMemory = 'upgrade_dialog.benefit_memory';
  static const upgradeDialogBenefitTokens = 'upgrade_dialog.benefit_tokens';
  static const upgradeDialogUpgradeButton = 'upgrade_dialog.upgrade_button';
  static const upgradeDialogMaybeLater = 'upgrade_dialog.maybe_later';

  // Gamification (My Progress)
  static const gamificationTitle = 'gamification.title';
  static const gamificationSubtitle = 'gamification.subtitle';
  static const gamificationStreaks = 'gamification.streaks';
  static const gamificationStudyStreak = 'gamification.study_streak';
  static const gamificationVerseStreak = 'gamification.verse_streak';
  static const gamificationPersonalBest = 'gamification.personal_best';
  static const gamificationDays = 'gamification.days';
  static const gamificationStatistics = 'gamification.statistics';
  static const gamificationStudies = 'gamification.studies';
  static const gamificationTimeSpent = 'gamification.time_spent';
  static const gamificationMemoryVerses = 'gamification.memory_verses';
  static const gamificationVoiceSessions = 'gamification.voice_sessions';
  static const gamificationSavedGuides = 'gamification.saved_guides';
  static const gamificationStudyDays = 'gamification.study_days';
  static const gamificationAchievements = 'gamification.achievements';
  static const gamificationXpTotal = 'gamification.xp_total';
  static const gamificationXpToNextLevel = 'gamification.xp_to_next_level';
  static const gamificationMaxLevel = 'gamification.max_level';
  static const gamificationUnlocked = 'gamification.unlocked';
  static const gamificationLocked = 'gamification.locked';
  static const gamificationUnlockedOn = 'gamification.unlocked_on';
  static const gamificationNewAchievement = 'gamification.new_achievement';
  static const gamificationCongratulations = 'gamification.congratulations';
  static const gamificationEarnedXp = 'gamification.earned_xp';
  static const gamificationContinue = 'gamification.continue';
  static const gamificationFailedToLoad = 'gamification.failed_to_load';
  static const gamificationRetry = 'gamification.retry';
  static const gamificationCurrentLevel = 'gamification.current_level';
  static const gamificationXpToLevel = 'gamification.xp_to_level';
  static const gamificationAchievementsCount =
      'gamification.achievements_count';
  static const gamificationDayStreakLabel = 'gamification.day_streak_label';
  static const gamificationStudiesLabel = 'gamification.studies_label';
  static const gamificationVersesLabel = 'gamification.verses_label';
  static const gamificationProgressCount = 'gamification.progress_count';

  // Achievement Categories
  static const gamificationCategoryStudy = 'gamification.category.study';
  static const gamificationCategoryStreak = 'gamification.category.streak';
  static const gamificationCategoryMemory = 'gamification.category.memory';
  static const gamificationCategoryVoice = 'gamification.category.voice';
  static const gamificationCategorySaved = 'gamification.category.saved';

  // Scripture Verse Sheet
  static const verseSheetLoading = 'verse_sheet.loading';
  static const verseSheetStudy = 'verse_sheet.study';
  static const verseSheetMemory = 'verse_sheet.memory';
  static const verseSheetCopy = 'verse_sheet.copy';
  static const verseSheetCopied = 'verse_sheet.copied';
  static const verseSheetCouldNotLoad = 'verse_sheet.could_not_load';
  static const verseSheetCouldNotParse = 'verse_sheet.could_not_parse';
  static const verseSheetContentUnavailable = 'verse_sheet.content_unavailable';
  static const verseSheetAddedToMemory = 'verse_sheet.added_to_memory';
  static const verseSheetFailedToAdd = 'verse_sheet.failed_to_add';

  // Collections (Sprint 5 - Verse Collections)
  static const collectionsTitle = 'collections.title';
  static const createCollection = 'collections.create';
  static const createFirstCollection = 'collections.create_first';
  static const editCollection = 'collections.edit';
  static const deleteCollection = 'collections.delete';
  static const deleteCollectionConfirmation = 'collections.delete_confirmation';
  static const collectionName = 'collections.name';
  static const nameRequired = 'collections.name_required';
  static const nameMinLength = 'collections.name_min_length';
  static const category = 'collections.category_label';
  static const icon = 'collections.icon_label';
  static const color = 'collections.color_label';
  static const descriptionOptional = 'collections.description_optional';
  static const cancel = 'common.cancel';
  static const save = 'common.save';
  static const delete = 'common.delete';
  static const remove = 'common.remove';
  static const removeVerse = 'collections.remove_verse';
  static const removeVerseConfirmation =
      'collections.remove_verse_confirmation';
  static const collectionNotFound = 'collections.not_found';
  static const verseCount = 'collections.verse_count';
  static const versesInCollection = 'collections.verses_in_collection';
  static const noVersesInCollection = 'collections.no_verses.title';
  static const addVersesPrompt = 'collections.no_verses.subtitle';
  static const addVerses = 'collections.add_verses';
  static const searchVerses = 'collections.search_verses';
  static const versesSelected = 'collections.verses_selected';
  static const noVersesFound = 'collections.no_verses_found';
  static const addToCollection = 'collections.add_to_collection';
  static const noCollectionsYet = 'collections.empty.title';
  static const createCollectionPrompt = 'collections.empty.subtitle';
  static const noCollectionsInCategory = 'collections.no_results';
  static const all = 'collections.filter.all';
  static const comfort = 'collections.category.comfort';
  static const wisdom = 'collections.category.wisdom';
  static const promises = 'collections.category.promises';
  static const commands = 'collections.category.commands';
  static const prophecy = 'collections.category.prophecy';
  static const gospel = 'collections.category.gospel';
  static const prayer = 'collections.category.prayer';
  static const custom = 'collections.category.custom';

  // Memory Champions Leaderboard (Sprint 5)
  static const memoryChampions = 'leaderboard.title';
  static const weekly = 'leaderboard.weekly';
  static const monthly = 'leaderboard.monthly';
  static const allTime = 'leaderboard.all_time';

  // Memory Stats Page (Sprint 5)
  static const memoryStats = 'memory_stats.title';
  static const practiceActivity = 'memory_stats.practice_activity';
  static const masteryDistribution = 'memory_stats.mastery_distribution';
  static const practiceModeStats = 'memory_stats.practice_mode_stats';
  static const overallStats = 'memory_stats.overall_stats';

  // Memory Verse Navigation
  static const myCollections = 'memory_nav.my_collections';
  static const champions = 'memory_nav.champions';
  static const statistics = 'memory_nav.statistics';

  // Practice Results Page (Sprint 5)
  static const practiceResultsTitle = 'practice_results.title';
  static const practiceResultsAccuracy = 'practice_results.accuracy';
  static const practiceResultsTime = 'practice_results.time';
  static const practiceResultsHintsUsed = 'practice_results.hints_used';
  static const practiceResultsMode = 'practice_results.mode';
  static const practiceResultsAnswerShown = 'practice_results.answer_shown';
  static const practiceResultsPenaltyApplied =
      'practice_results.penalty_applied';
  static const practiceResultsDone = 'practice_results.done';
  static const practiceResultsPracticeAgain = 'practice_results.practice_again';
  static const practiceResultsAnswerComparison =
      'practice_results.answer_comparison';
  static const practiceResultsBlank = 'practice_results.blank';
  static const practiceResultsWord = 'practice_results.word';
  static const practiceResultsPhrase = 'practice_results.phrase';
  static const practiceResultsYourAnswer = 'practice_results.your_answer';
  static const practiceResultsCorrectAnswer = 'practice_results.correct_answer';
  static const practiceResultsExtraWord = 'practice_results.extra_word';
  static const practiceResultsNote = 'practice_results.note';
  static const practiceResultsNotInVerse = 'practice_results.not_in_verse';

  // Quality Rating Labels
  static const qualityPerfect = 'quality.perfect';
  static const qualityGood = 'quality.good';
  static const qualityOk = 'quality.ok';
  static const qualityNeedsWork = 'quality.needs_work';
  static const qualityTryAgain = 'quality.try_again';

  // Practice Badge Labels
  static const practiceBadgeMastered = 'practice_badge.mastered';
  static const practiceBadgeProficient = 'practice_badge.proficient';

  // Practice Mode Names
  static const practiceModeFlipCard = 'practice_mode.flip_card';
  static const practiceModeFirstLetter = 'practice_mode.first_letter';
  static const practiceModeProgressive = 'practice_mode.progressive';
  static const practiceModeCloze = 'practice_mode.cloze';
  static const practiceModeWordScramble = 'practice_mode.word_scramble';
  static const practiceModeWordBank = 'practice_mode.word_bank';
  static const practiceModeAudio = 'practice_mode.audio';
  static const practiceModeTypeItOut = 'practice_mode.type_it_out';

  // Self-Assessment (for passive practice modes)
  static const selfAssessmentTitle = 'self_assessment.title';
  static const selfAssessmentSubtitle = 'self_assessment.subtitle';
  static const selfAssessmentDidNotKnow = 'self_assessment.did_not_know';
  static const selfAssessmentDidNotKnowDesc =
      'self_assessment.did_not_know_desc';
  static const selfAssessmentKnewALittle = 'self_assessment.knew_a_little';
  static const selfAssessmentKnewALittleDesc =
      'self_assessment.knew_a_little_desc';
  static const selfAssessmentKnewHalf = 'self_assessment.knew_half';
  static const selfAssessmentKnewHalfDesc = 'self_assessment.knew_half_desc';
  static const selfAssessmentKnewMost = 'self_assessment.knew_most';
  static const selfAssessmentKnewMostDesc = 'self_assessment.knew_most_desc';
  static const selfAssessmentKnewPerfectly = 'self_assessment.knew_perfectly';
  static const selfAssessmentKnewPerfectlyDesc =
      'self_assessment.knew_perfectly_desc';

  // Practice Mode Selection Page
  static const practiceSelectionTitle = 'practice_selection.title';
  static const practiceSelectionLoading = 'practice_selection.loading';
  static const practiceSelectionSubtitle = 'practice_selection.subtitle';
  static const practiceSelectionFilter = 'practice_selection.filter';
  static const practiceSelectionNoModes = 'practice_selection.no_modes';
  static const practiceSelectionLoadError = 'practice_selection.load_error';
  static const practiceSelectionMasterThisFirst =
      'practice_selection.master_this_first';
  static const practiceSelectionMasterThisNext =
      'practice_selection.master_this_next';

  // Practice Mode Descriptions
  static const practiceModeFlipCardDesc = 'practice_mode.flip_card_desc';
  static const practiceModeFirstLetterDesc = 'practice_mode.first_letter_desc';
  static const practiceModeProgressiveDesc = 'practice_mode.progressive_desc';
  static const practiceModeClozeDesc = 'practice_mode.cloze_desc';
  static const practiceModeWordScrambleDesc =
      'practice_mode.word_scramble_desc';
  static const practiceModeWordBankDesc = 'practice_mode.word_bank_desc';
  static const practiceModeAudioDesc = 'practice_mode.audio_desc';
  static const practiceModeTypeItOutDesc = 'practice_mode.type_it_out_desc';

  // Difficulty Labels
  static const difficultyEasy = 'difficulty.easy';
  static const difficultyMedium = 'difficulty.medium';
  static const difficultyHard = 'difficulty.hard';
  static const difficultyAll = 'difficulty.all';

  // Common Practice Actions
  static const practiceSubmit = 'practice.submit';
  static const practiceShowAnswer = 'practice.show_answer';
  static const practiceReset = 'practice.reset';
  static const practiceUseHint = 'practice.use_hint';
  static const practiceHints = 'practice.hints';
  static const practiceHintsUsedCount = 'practice.hints_used_count';
  static const practiceClear = 'practice.clear';
  static const practiceRetry = 'practice.retry';
  static const practiceComplete = 'practice.complete';

  // Memory practice action bar (phrase scramble, word bank, fill in the
  // blanks, audio)
  static const memoryPracticeHint = 'memory_practice.hint';
  static const memoryPracticeHintCount = 'memory_practice.hint_count';
  static const memoryPracticeCheck = 'memory_practice.check';
  static const memoryPracticeCloseExpected = 'memory_practice.close_expected';
  static const memoryPracticeExpectedSaid = 'memory_practice.expected_said';

  // Word Bank Practice Page
  static const wordBankTapWordsInstruction = 'word_bank.tap_words_instruction';
  static const wordBankLongPressHint = 'word_bank.long_press_hint';
  static const wordBankYourAnswer = 'word_bank.your_answer';
  static const wordBankTryAgain = 'word_bank.try_again';
  static const wordBankAllPlaced = 'word_bank.all_placed';
  static const wordBankAllPlacedDone = 'word_bank.all_placed_done';

  // Cloze Practice Page
  static const clozePracticeTitle = 'cloze_practice.title';

  // Word Scramble Practice Page
  static const wordScrambleTitle = 'word_scramble.title';
  static const wordScrambleInstruction = 'word_scramble.instruction';
  static const wordScrambleAvailablePhrases = 'word_scramble.available_phrases';
  static const wordScrambleDropHere = 'word_scramble.drop_here';

  // Progressive Reveal Practice Page
  static const progressiveRevealTitle = 'progressive_reveal.title';
  static const progressiveRevealInstruction = 'progressive_reveal.instruction';
  static const progressiveRevealWordByWord = 'progressive_reveal.word_by_word';
  static const progressiveRevealPhraseByPhrase =
      'progressive_reveal.phrase_by_phrase';
  static const progressiveRevealNext = 'progressive_reveal.reveal_next';
  static const progressiveRevealAuto = 'progressive_reveal.auto_reveal';
  static const progressiveRevealPause = 'progressive_reveal.pause';
  static const progressiveRevealAll = 'progressive_reveal.reveal_all';
  static const progressiveWordByWord = 'progressive_reveal.word_by_word_label';
  static const progressivePhraseByPhrase =
      'progressive_reveal.phrase_by_phrase_label';
  static const progressiveWords = 'progressive_reveal.words';
  static const progressivePhrases = 'progressive_reveal.phrases';
  static const progressivePause = 'progressive_reveal.pause_label';
  static const progressiveAutoReveal = 'progressive_reveal.auto_reveal_label';

  // First Letter Hints Practice Page
  static const firstLetterTitle = 'first_letter.title';
  static const firstLetterInstruction = 'first_letter.instruction';
  static const firstLetterHintsUsed = 'first_letter.hints_used';

  // Audio Practice Page
  static const audioPracticeTitle = 'audio_practice.title';
  static const audioPracticeListen = 'audio_practice.listen';
  static const audioPracticeSpeak = 'audio_practice.speak';
  static const audioPracticeResults = 'audio_practice.results';
  static const audioPracticeListenInstruction =
      'audio_practice.listen_instruction';
  static const audioPracticePlayedTimes = 'audio_practice.played_times';
  static const audioPracticeTapToPlay = 'audio_practice.tap_to_play';
  static const audioPracticeReadyToSpeak = 'audio_practice.ready_to_speak';
  static const audioPracticeSpeakNow = 'audio_practice.speak_now';
  static const audioPracticeTapMicrophone = 'audio_practice.tap_microphone';
  static const audioPracticeRecognized = 'audio_practice.recognized';
  static const audioPracticeCheckResult = 'audio_practice.check_result';
  static const audioPracticeAccuracy = 'audio_practice.accuracy';
  static const audioPracticeExpected = 'audio_practice.expected';
  static const audioPracticeYouSaid = 'audio_practice.you_said';
  static const audioPracticeWordComparison = 'audio_practice.word_comparison';
  static const audioPracticeExtraWord = 'audio_practice.extra_word';
  static const audioPracticeWordMissed = 'audio_practice.word_missed';
  static const audioPracticeCorrect = 'audio_practice.correct';
  static const audioPracticeSpeechError = 'audio_practice.speech_error';
  // Additional audio keys used in audio_practice_page.dart
  static const audioListenCarefully = 'audio.listen_carefully';
  static const audioReadCarefully = 'audio.read_carefully';
  static const audioPlayed = 'audio.played';
  static const audioTimes = 'audio.times';
  static const audioTime = 'audio.time';
  static const audioTapToPlay = 'audio.tap_to_play';
  static const audioReadyToSpeak = 'audio.ready_to_speak';
  static const audioSpeakNow = 'audio.speak_now';
  static const audioTapMicrophone = 'audio.tap_microphone';
  static const audioRecognized = 'audio.recognized';
  static const audioCheckResult = 'audio.check_result';
  static const audioExpected = 'audio.expected';
  static const audioYouSaid = 'audio.you_said';
  static const audioNothingRecognized = 'audio.nothing_recognized';
  static const audioWordComparison = 'audio.word_comparison';

  // Type It Out Practice Page
  static const typeItOutTitle = 'type_it_out.title';
  static const typeItOutPlaceholder = 'type_it_out.placeholder';
  static const typeItOutInstruction = 'type_it_out.instruction';
  static const typeItOutHindiHinglish = 'type_it_out.hindi_hinglish';
  static const typeItOutMalayalamManglish = 'type_it_out.malayalam_manglish';
  static const typeItOutRomanizedHint = 'type_it_out.romanized_hint';
  static const typeItOutWordCount = 'type_it_out.word_count';

  // Memory verses screens (home, add verse, mode picker, results, stats,
  // champions)
  static const memoryScreensDueTodayCount = 'memory_screens.due_today_count';
  static const memoryScreensTapToSeePlans = 'memory_screens.tap_to_see_plans';
  static const memoryScreensChooseUnlockedModes =
      'memory_screens.choose_unlocked_modes';
  static const memoryScreensTopTen = 'memory_screens.top_ten';
  static const memoryScreensEaseFactor = 'memory_screens.ease_factor';
  static const memoryScreensAddVerseSubtitle =
      'memory_screens.add_verse_subtitle';
  static const memoryScreensChooseBook = 'memory_screens.choose_book';
  static const memoryScreensAllCaughtUp = 'memory_screens.all_caught_up';
  static const memoryScreensVersesCount = 'memory_screens.verses_count';
  static const memoryScreensHowItWorks = 'memory_screens.how_it_works';
  static const memoryScreensVerseCountOne = 'memory_screens.verse_count_one';
  static const memoryScreensMasteredCount = 'memory_screens.mastered_count';
  static const memoryScreensCountOfTotal = 'memory_screens.count_of_total';
  static const memoryScreensComingUp = 'memory_screens.coming_up';
  static const memoryScreensDueToday = 'memory_screens.due_today';
  static const memoryScreensDueTomorrow = 'memory_screens.due_tomorrow';
  static const memoryScreensDueInDays = 'memory_screens.due_in_days';
  static const memoryScreensOverdueDays = 'memory_screens.overdue_days';
  static const memoryScreensOverdueOneDay = 'memory_screens.overdue_one_day';
  static const memoryScreensNewVerse = 'memory_screens.new_verse';
  static const memoryScreensNothingDue = 'memory_screens.nothing_due';
  static const memoryScreensOfflineTitle = 'memory_screens.offline_title';
  static const memoryScreensOfflineBody = 'memory_screens.offline_body';
  static const memoryScreensTileDaily = 'memory_screens.tile_daily';
  static const memoryScreensTileDailyHint = 'memory_screens.tile_daily_hint';
  static const memoryScreensTileSuggested = 'memory_screens.tile_suggested';
  static const memoryScreensTileSuggestedHint =
      'memory_screens.tile_suggested_hint';
  static const memoryScreensTileCustom = 'memory_screens.tile_custom';
  static const memoryScreensTileCustomHint = 'memory_screens.tile_custom_hint';
  static const memoryScreensModesUnlockedToday =
      'memory_screens.modes_unlocked_today';
  static const memoryScreensAllModesUnlocked =
      'memory_screens.all_modes_unlocked';
  static const memoryScreensDailyLimitReached =
      'memory_screens.daily_limit_reached';
  static const memoryScreensUpgrade = 'memory_screens.upgrade';
  static const memoryScreensModeLockedUpgrade =
      'memory_screens.mode_locked_upgrade';
  static const memoryScreensNextReviewToday =
      'memory_screens.next_review_today';
  static const memoryScreensNextReviewTomorrow =
      'memory_screens.next_review_tomorrow';
  static const memoryScreensNextReviewInDays =
      'memory_screens.next_review_in_days';
  static const memoryScreensMissed = 'memory_screens.missed';
  static const memoryScreensStatTime = 'memory_screens.stat_time';
  static const memoryScreensStatHint = 'memory_screens.stat_hint';
  static const memoryScreensStatHints = 'memory_screens.stat_hints';
  static const memoryScreensStatAnswerShown =
      'memory_screens.stat_answer_shown';
  static const memoryScreensYes = 'memory_screens.yes';
  static const memoryScreensNo = 'memory_screens.no';
  static const memoryScreensQualityPerfect = 'memory_screens.quality_perfect';
  static const memoryScreensQualityGood = 'memory_screens.quality_good';
  static const memoryScreensQualityOk = 'memory_screens.quality_ok';
  static const memoryScreensQualityNeedsWork =
      'memory_screens.quality_needs_work';
  static const memoryScreensQualityTryAgain =
      'memory_screens.quality_try_again';
  static const memoryScreensStatsSubtitle = 'memory_screens.stats_subtitle';
  static const memoryScreensStatVerses = 'memory_screens.stat_verses';
  static const memoryScreensStatVerse = 'memory_screens.stat_verse';
  static const memoryScreensStatReviews = 'memory_screens.stat_reviews';
  static const memoryScreensStatPerfect = 'memory_screens.stat_perfect';
  static const memoryScreensStatDays = 'memory_screens.stat_days';
  static const memoryScreensStreakLine = 'memory_screens.streak_line';
  static const memoryScreensPracticeModes = 'memory_screens.practice_modes';
  static const memoryScreensPracticesCount = 'memory_screens.practices_count';
  static const memoryScreensChampionsSubtitle =
      'memory_screens.champions_subtitle';
  static const memoryScreensYourRank = 'memory_screens.your_rank';
  static const memoryScreensStatMastered = 'memory_screens.stat_mastered';
  static const memoryScreensStatDayStreak = 'memory_screens.stat_day_streak';

  // Memory Verse Home Page
  static const memoryHomeTitle = 'memory_home.title';
  static const memoryHomeFeatureDescription = 'memory_home.feature_description';
  static const memoryHomeAddVerse = 'memory_home.add_verse';
  static const memoryHomeOptions = 'memory_home.options';
  static const memoryHomeLoading = 'memory_home.loading';
  static const memoryHomeTotal = 'memory_home.total';
  static const memoryHomeMastered = 'memory_home.mastered';
  static const memoryHomeDailyReviews = 'memory_home.daily_reviews';
  static const memoryHomeChampions = 'memory_home.champions';
  static const memoryHomeStatistics = 'memory_home.statistics';
  static const memoryHomeNoVersesTitle = 'memory_home.no_verses_title';
  static const memoryHomeNoVersesSubtitle = 'memory_home.no_verses_subtitle';
  static const memoryHomeAddFirstVerse = 'memory_home.add_first_verse';
  static const memoryHomeStreakDay = 'memory_home.streak_day';
  static const memoryHomeStreakDays = 'memory_home.streak_days';

  // Memory Champions Page
  static const memoryChampionsTitle = 'memory_champions.title';
  static const memoryChampionsWeekly = 'memory_champions.weekly';
  static const memoryChampionsMonthly = 'memory_champions.monthly';
  static const memoryChampionsAllTime = 'memory_champions.all_time';
  static const memoryChampionsLoadFailed = 'memory_champions.load_failed';
  static const memoryChampionsNoData = 'memory_champions.no_data';
  static const memoryChampionsRank = 'memory_champions.rank';
  static const memoryChampionsYourProgress = 'memory_champions.your_progress';
  static const memoryChampionsMaster = 'memory_champions.master';
  static const memoryChampionsStreak = 'memory_champions.streak';

  // Memory Heat Map
  static const heatMapTitle = 'memory.heatMap.title';
  static const heatMapSubtitle = 'memory.heatMap.subtitle';
  static const heatMapDayStreak = 'memory.heatMap.dayStreak';
  static const heatMapLongestStreak = 'memory.heatMap.longestStreak';
  static const heatMapLongestStreakOne = 'memory.heatMap.longestStreakOne';
  static const heatMapLess = 'memory.heatMap.less';
  static const heatMapMore = 'memory.heatMap.more';
  static const heatMapMon = 'memory.heatMap.mon';
  static const heatMapWed = 'memory.heatMap.wed';
  static const heatMapFri = 'memory.heatMap.fri';

  // Memory Stats Page
  static const noPracticeModeData = 'memory.stats.noPracticeModeData';
  static const memoryStatsTitle = 'memory_stats_page.title';
  static const memoryStatsLoadFailed = 'memory_stats_page.load_failed';
  static const memoryStatsNoData = 'memory_stats_page.no_data';
  static const memoryStatsBeginner = 'memory_stats_page.beginner';
  static const memoryStatsIntermediate = 'memory_stats_page.intermediate';
  static const memoryStatsAdvanced = 'memory_stats_page.advanced';
  static const memoryStatsExpert = 'memory_stats_page.expert';

  // Study Mode Selection Sheet
  /// Title for the study mode selection bottom sheet
  static const modeSelectionTitle = 'mode_selection.title';

  /// Subtitle explaining study mode options in the selection sheet
  static const modeSelectionSubtitle = 'mode_selection.subtitle';

  /// Checkbox label to remember user's study mode preference
  static const modeSelectionRememberChoice = 'mode_selection.remember_choice';

  /// Start button text in the mode selection sheet
  static const modeSelectionStartButton = 'mode_selection.start_button';

  /// Badge label indicating the default study mode
  static const modeSelectionDefaultBadge = 'mode_selection.default_badge';

  /// Badge label for recommended study mode based on input type
  static const modeSelectionRecommendedBadge =
      'mode_selection.recommended_badge';

  /// Checkbox label for always using recommended mode
  static const modeSelectionAlwaysUseRecommended =
      'mode_selection.always_use_recommended';

  // Study Mode Names & Descriptions
  /// Name of the Quick study mode (3-minute read)
  static const studyModeQuickName = 'study_mode.quick.name';

  /// Description of the Quick study mode
  static const studyModeQuickDescription = 'study_mode.quick.description';

  /// Name of the Standard study mode (10-minute read)
  static const studyModeStandardName = 'study_mode.standard.name';

  /// Description of the Standard study mode
  static const studyModeStandardDescription = 'study_mode.standard.description';

  /// Name of the Deep study mode (15-minute read)
  static const studyModeDeepName = 'study_mode.deep.name';

  /// Description of the Deep study mode
  static const studyModeDeepDescription = 'study_mode.deep.description';

  /// Name of the Lectio Divina study mode (10-minute meditative)
  static const studyModeLectioName = 'study_mode.lectio.name';

  /// Description of the Lectio Divina study mode
  static const studyModeLectioDescription = 'study_mode.lectio.description';

  /// Name of the Sermon Outline study mode (50-60 minute sermon)
  static const studyModeSermonName = 'study_mode.sermon.name';

  /// Description of the Sermon Outline study mode
  static const studyModeSermonDescription = 'study_mode.sermon.description';

  /// Short mode names for the compact depth cards on the Generate tab.
  static const studyModeQuickShortName = 'study_mode.quick.short_name';
  static const studyModeStandardShortName = 'study_mode.standard.short_name';
  static const studyModeDeepShortName = 'study_mode.deep.short_name';
  static const studyModeLectioShortName = 'study_mode.lectio.short_name';
  static const studyModeSermonShortName = 'study_mode.sermon.short_name';

  /// "{count} min" duration label.
  static const studyModeMinutes = 'study_mode.minutes';

  /// Headline of the full-height depth chooser.
  static const modeSelectionTimeQuestion = 'mode_selection.time_question';

  // Settings - Study Mode Preference
  /// Settings label for study mode preference option
  static const settingsStudyModePreference = 'settings.study_mode_preference';

  /// Label showing current study mode preference in settings
  static const settingsStudyModePreferenceCurrent =
      'settings.study_mode_preference_current';

  /// Settings option to ask for study mode every time
  static const settingsAskEveryTime = 'settings.ask_every_time';

  /// Subtitle for the "ask every time" settings option
  static const settingsAskEveryTimeSubtitle =
      'settings.ask_every_time_subtitle';

  /// Settings option for learning path study mode preference
  static const settingsLearningPathStudyModePreference =
      'settings.learning_path_study_mode_preference';

  /// Description for learning path study mode preference
  static const settingsLearningPathStudyModeDescription =
      'settings.learning_path_study_mode_description';

  /// Settings option to use recommended mode
  static const settingsUseRecommended = 'settings.use_recommended';

  /// Subtitle for use recommended mode option
  static const settingsUseRecommendedSubtitle =
      'settings.use_recommended_subtitle';

  /// Error message when updating preference fails
  static const errorUpdatingPreference = 'settings.error_updating_preference';

  /// Success message when preference is updated
  static const preferenceUpdatedSuccessfully =
      'settings.preference_updated_successfully';

  // Settings - Reflection Journal
  /// Settings label for reflection journal navigation option
  static const settingsReflectionJournal = 'settings.reflection_journal';

  /// Subtitle describing the reflection journal feature
  static const settingsReflectionJournalSubtitle =
      'settings.reflection_journal_subtitle';

  // Study Mode Preference Dialog
  /// Title for the study mode preference selection dialog
  static const studyModePreferenceTitle = 'study_mode_preference.title';

  /// Subtitle explaining study mode preference options in the dialog
  static const studyModePreferenceSubtitle = 'study_mode_preference.subtitle';

  /// Dialog option to ask for study mode every time
  static const studyModePreferenceAskEveryTime =
      'study_mode_preference.ask_every_time';

  /// Subtitle for the "ask every time" dialog option
  static const studyModePreferenceAskEveryTimeSubtitle =
      'study_mode_preference.ask_every_time_subtitle';

  // Reflection Journal Screen
  /// Title for the Reflection Journal screen
  static const reflectionJournalTitle = 'reflection_journal.title';

  /// Filter button label to filter reflections by study mode
  static const reflectionJournalFilterByMode =
      'reflection_journal.filter_by_mode';

  /// Filter option to show all study modes
  static const reflectionJournalAllModes = 'reflection_journal.all_modes';

  /// Retry button text when loading reflections fails
  static const reflectionJournalRetry = 'reflection_journal.retry';

  /// Title shown when no reflections exist
  static const reflectionJournalNoReflections =
      'reflection_journal.no_reflections';

  /// Message explaining how to create first reflection
  static const reflectionJournalEmptyMessage =
      'reflection_journal.empty_message';

  /// Button text to start a new study from empty state
  static const reflectionJournalStartStudy = 'reflection_journal.start_study';

  /// Section header for user's reflection statistics
  static const reflectionJournalYourJourney = 'reflection_journal.your_journey';

  /// Label for total reflection count statistic
  static const reflectionJournalReflections = 'reflection_journal.reflections';

  /// Label for total time spent in reflection
  static const reflectionJournalTimeSpent = 'reflection_journal.time_spent';

  /// Label for average session duration statistic
  static const reflectionJournalAvgSession = 'reflection_journal.avg_session';

  /// Label for top focus areas section
  static const reflectionJournalTopFocusAreas =
      'reflection_journal.top_focus_areas';

  /// Title for reflection deletion confirmation dialog
  static const reflectionJournalDeleteTitle = 'reflection_journal.delete_title';

  /// Message in reflection deletion confirmation dialog
  static const reflectionJournalDeleteMessage =
      'reflection_journal.delete_message';

  /// Cancel button text in deletion dialog
  static const reflectionJournalCancel = 'reflection_journal.cancel';

  /// Delete button text in deletion dialog
  static const reflectionJournalDelete = 'reflection_journal.delete';

  /// Success message shown after reflection deletion
  static const reflectionJournalDeleted = 'reflection_journal.deleted';

  /// Error message shown when deletion fails
  static const reflectionJournalDeleteFailed =
      'reflection_journal.delete_failed';

  /// Error message shown when loading study guide fails
  static const reflectionJournalLoadStudyFailed =
      'reflection_journal.load_study_failed';

  /// Button text to view the associated study guide
  static const reflectionJournalViewStudy = 'reflection_journal.view_study';

  /// Label indicating number of verses saved in a reflection
  static const reflectionJournalVersesSaved = 'reflection_journal.verses_saved';

  /// "Yes" option for reflection responses
  static const reflectionJournalYes = 'reflection_journal.yes';

  /// "No" option for reflection responses
  static const reflectionJournalNo = 'reflection_journal.no';
  static const reflectionJournalCount = 'reflection_journal.count';
  static const reflectionJournalToday = 'reflection_journal.today';
  static const reflectionJournalYesterday = 'reflection_journal.yesterday';
  static const reflectionJournalMinutes = 'reflection_journal.minutes';

  // Study Guide Screen - Additional Keys
  /// Section title for key insight in Quick mode
  static const studyGuideKeyInsight = 'study_guide.key_insight';

  /// Section title for key verse in Quick mode
  static const studyGuideKeyVerse = 'study_guide.key_verse';

  /// Section title for quick reflection in Quick mode
  static const studyGuideQuickReflection = 'study_guide.quick_reflection';

  /// Section title for brief prayer in Quick mode
  static const studyGuideBriefPrayer = 'study_guide.brief_prayer';

  /// Button text to ask AI follow-up questions
  static const studyGuideAskAi = 'study_guide.ask_ai';

  // Deep Dive Mode Sections
  /// Section title for comprehensive overview in Deep mode
  static const studyGuideComprehensiveOverview =
      'study_guide.comprehensive_overview';

  /// Section title for in-depth interpretation in Deep mode
  static const studyGuideInDepthInterpretation =
      'study_guide.in_depth_interpretation';

  /// Section title for historical context in Deep mode
  static const studyGuideHistoricalContext = 'study_guide.historical_context';

  /// Section title for scripture connections in Deep mode
  static const studyGuideScriptureConnections =
      'study_guide.scripture_connections';

  /// Section title for deep reflection in Deep mode
  static const studyGuideDeepReflection = 'study_guide.deep_reflection';

  /// Section title for prayer for application in Deep mode
  static const studyGuidePrayerForApplication =
      'study_guide.prayer_for_application';

  // Study Mode Duration Labels
  /// Duration label for Quick mode (e.g., "3 min")
  static const studyModeQuickDuration = 'study_mode.quick.duration_label';

  /// Duration label for Standard mode (e.g., "10 min")
  static const studyModeStandardDuration = 'study_mode.standard.duration_label';

  /// Duration label for Deep mode (e.g., "15 min")
  static const studyModeDeepDuration = 'study_mode.deep.duration_label';

  /// Duration label for Lectio mode (e.g., "10 min")
  static const studyModeLectioDuration = 'study_mode.lectio.duration_label';

  /// Duration label for Sermon mode (e.g., "50-60 min")
  static const studyModeSermonDuration = 'study_mode.sermon.duration_label';

  // Lectio Divina Mode Sections
  /// Section title for scripture passage in Lectio mode
  static const lectioScriptureForMeditation = 'lectio.scripture_for_meditation';

  /// Section title for reflection prompt
  static const lectioReflectionPrompt = 'lectio.reflection_prompt';

  /// Section title for key themes
  static const lectioKeyThemes = 'lectio.key_themes';

  /// Section title for theological insights
  static const lectioTheologicalInsights = 'lectio.theological_insights';

  /// Section title for connect to today
  static const lectioConnectToToday = 'lectio.connect_to_today';

  /// Section title for verse reflection
  static const lectioVerseReflection = 'lectio.verse_reflection';

  /// Section title for personal application
  static const lectioPersonalApplication = 'lectio.personal_application';

  /// Section title for living it out
  static const lectioLivingItOut = 'lectio.living_it_out';

  /// Section title for prayer invitation
  static const lectioPrayerInvitation = 'lectio.prayer_invitation';

  /// Section title for Lectio Meditatio (read and meditate)
  static const lectioLectioMeditatio = 'lectio.lectio_meditatio';

  /// Subtitle for read and meditate section
  static const lectioReadMeditate = 'lectio.read_meditate';

  /// Section title for about the practice
  static const lectioAboutPractice = 'lectio.about_practice';

  /// Emoji for about the practice section
  static const lectioAboutPracticeEmoji = 'lectio.about_practice_emoji';

  /// Section title for focus words
  static const lectioFocusWords = 'lectio.focus_words';

  /// Emoji for focus words section
  static const lectioFocusWordsEmoji = 'lectio.focus_words_emoji';

  /// Section title for Oratio Contemplatio (pray and rest)
  static const lectioOratioContemplatio = 'lectio.oratio_contemplatio';

  /// Subtitle for pray and rest section
  static const lectioPrayRest = 'lectio.pray_rest';

  /// Section title for closing blessing
  static const lectioClosingBlessing = 'lectio.closing_blessing';

  /// Emoji for closing blessing section
  static const lectioClosingBlessingEmoji = 'lectio.closing_blessing_emoji';

  /// Duration label for Lectio mode (deprecated, use studyModeLectioDuration)
  static const lectioDurationLabel = 'lectio.duration_label';

  // Sermon Outline Mode Sections
  /// Section title for sermon thesis/introduction
  static const sermonThesis = 'sermon.thesis';

  /// Section title for main sermon body with timing breakdown
  static const sermonBody = 'sermon.body';

  /// Section title for sermon background and context
  static const sermonContext = 'sermon.context';

  /// Section title for supporting Bible verses
  static const sermonSupportingVerses = 'sermon.supporting_verses';

  /// Section title for small group discussion questions
  static const sermonDiscussionQuestions = 'sermon.discussion_questions';

  /// Section title for altar call/invitation template
  static const sermonAltarCall = 'sermon.altar_call';

  /// Badge label for sermon outline with duration
  static const sermonDuration = 'sermon.duration_badge';

  // Reading Completion Card
  /// Title for reading completion prompt card
  static const readingCompleteTitle = 'reading_complete.title';

  /// Description encouraging reflection after reading
  static const readingCompleteDescription = 'reading_complete.description';

  /// Button to dismiss and continue later
  static const readingCompleteMaybeLater = 'reading_complete.maybe_later';

  /// Button to start Reflect Mode immediately
  static const readingCompleteReflectNow = 'reading_complete.reflect_now';

  // Reflect Mode Card
  /// Card progress indicator (e.g., "3 of 6")
  static const reflectModeCardOf = 'reflect_mode.card_of';

  /// "Yes" option for yes/no questions in Reflect Mode
  static const reflectModeYes = 'reflect_mode.yes';

  /// "No" option for yes/no questions in Reflect Mode
  static const reflectModeNo = 'reflect_mode.no';

  /// Prompt to share brief thoughts for text input
  static const reflectModeShareBriefly = 'reflect_mode.share_briefly';

  /// Left label for slider ("Not at all")
  static const reflectModeSliderNotAtAll = 'reflect_mode.slider_not_at_all';

  /// Right label for slider ("Very much")
  static const reflectModeSliderVeryMuch = 'reflect_mode.slider_very_much';

  /// Encouragement text below reflection input
  static const reflectModeTakeYourTime = 'reflect_mode.take_your_time';

  /// Continue button text to move to next card
  static const reflectModeContinue = 'reflect_mode.continue';

  /// Complete button text on final card
  static const reflectModeComplete = 'reflect_mode.complete';

  // Reflect Mode View - Section Titles
  /// Summary section title in Reflect Mode view
  static const reflectModeSectionSummary = 'reflect_mode.section_summary';

  /// Interpretation section title in Reflect Mode view
  static const reflectModeSectionInterpretation =
      'reflect_mode.section_interpretation';

  /// Context section title in Reflect Mode view
  static const reflectModeSectionContext = 'reflect_mode.section_context';

  /// Related verses section title in Reflect Mode view
  static const reflectModeSectionRelatedVerses =
      'reflect_mode.section_related_verses';

  /// Reflection section title in Reflect Mode view
  static const reflectModeSectionReflection = 'reflect_mode.section_reflection';

  /// Prayer section title in Reflect Mode view
  static const reflectModeSectionPrayer = 'reflect_mode.section_prayer';

  // Reflect Mode View - UI Elements
  /// Button text to read section content before reflecting
  static const reflectModeRead = 'reflect_mode.read';

  /// Button text to go to previous reflection card
  static const reflectModePrevious = 'reflect_mode.previous';

  // Reflect Mode Questions
  /// Fallback question for interpretation section
  static const reflectModeQuestionInterpretation =
      'reflect_mode.question_interpretation';

  /// Fallback option: God's character revealed
  static const reflectModeFallbackGodsCharacter =
      'reflect_mode.fallback_gods_character';

  /// Fallback option: My response to God
  static const reflectModeFallbackMyResponse =
      'reflect_mode.fallback_my_response';

  /// Fallback option: Life application
  static const reflectModeFallbackLifeApplication =
      'reflect_mode.fallback_life_application';

  /// Summary card option: Finding strength
  static const reflectModeSummaryFindingStrength =
      'reflect_mode.summary_finding_strength';

  /// Summary card option: Experiencing comfort
  static const reflectModeSummaryExperiencingComfort =
      'reflect_mode.summary_experiencing_comfort';

  /// Summary card option: Accepting a challenge
  static const reflectModeSummaryAcceptingChallenge =
      'reflect_mode.summary_accepting_challenge';

  /// Fallback question for context section
  static const reflectModeQuestionContextFallback =
      'reflect_mode.question_context_fallback';

  /// Fallback question for summary section
  static const reflectModeQuestionSummaryFallback =
      'reflect_mode.question_summary_fallback';

  /// Fallback question for related verses section
  static const reflectModeQuestionRelatedVersesFallback =
      'reflect_mode.question_related_verses_fallback';

  /// Fallback question for reflection section
  static const reflectModeQuestionReflectionFallback =
      'reflect_mode.question_reflection_fallback';

  /// Fallback prompt for prayer section
  static const reflectModePrayerFallback = 'reflect_mode.prayer_fallback';

  // Prayer Modes
  /// Prayer mode option to listen to audio
  static const prayerModeListen = 'prayer_mode.listen';

  /// Prayer mode option to read silently
  static const prayerModeReadSilently = 'prayer_mode.read_silently';

  /// Prayer mode option to write your own prayer
  static const prayerModeWriteOwn = 'prayer_mode.write_own';

  /// Message shown when audio prayer is not yet available
  static const prayerModeAudioComingSoon = 'prayer_mode.audio_coming_soon';

  /// Prompt to write a personal prayer
  static const prayerModeWritePersonalPrayer =
      'prayer_mode.write_personal_prayer';

  /// Placeholder text for prayer text input
  static const prayerModeTypePlaceholder = 'prayer_mode.type_placeholder';

  /// Title for listen to prayer mode
  static const prayerModeListenToPrayer = 'prayer_mode.listen_to_prayer';

  /// Status text when prayer is playing
  static const prayerModePlayingPrayer = 'prayer_mode.playing_prayer';

  /// Play button text for audio prayer
  static const prayerModePlay = 'prayer_mode.play';

  /// Pause button text for audio prayer
  static const prayerModePause = 'prayer_mode.pause';

  /// Stop button text for audio prayer
  static const prayerModeStop = 'prayer_mode.stop';

  /// Loading text for prayer audio
  static const prayerModeLoading = 'prayer_mode.loading';

  // Learning Path - Study Mode Selection
  /// Badge shown on recommended study mode for a learning path
  static const learningPathRecommendedModeBadge =
      'learning_path.recommended_mode_badge';

  /// Checkbox to always use recommended mode for learning paths
  static const learningPathAlwaysUseRecommended =
      'learning_path.always_use_recommended';

  /// Subtitle for always use recommended checkbox
  static const learningPathAlwaysUseRecommendedSubtitle =
      'learning_path.always_use_recommended_subtitle';

  /// Text showing best study mode for path
  static const learningPathBestStudiedIn = 'learning_path.best_studied_in';

  /// Bonus XP awarded message
  static const learningPathBonusXpAwarded = 'learning_path.bonus_xp_awarded';

  /// Completed in recommended mode message
  static const learningPathCompletedInRecommended =
      'learning_path.completed_in_recommended';

  // Upgrade Pages (Plus / Standard)
  static const upgradeToPlus = 'upgrade.to_plus';
  static const downgradeToPlus = 'upgrade.downgrade_to_plus';
  static const upgradeToStandard = 'upgrade.to_standard';
  static const whatYouGetPlus = 'upgrade.what_you_get_plus';
  static const whatYouGetStandard = 'upgrade.what_you_get_standard';

  // Promo Code Widget
  static const promoCodeHave = 'promo_code.have';
  static const promoCodeEnter = 'promo_code.enter';
  static const promoCodeApply = 'promo_code.apply';
  static const promoCodeApplied = 'promo_code.applied';
  static const promoCodeRemove = 'promo_code.remove';
  static const promoCodeInvalid = 'promo_code.invalid';
  static const promoCodeError = 'promo_code.error';
  static const promoCodeEmpty = 'promo_code.empty';

  // Token Purchase Page
  static const tokenPurchasePackages = 'tokens.purchase.packages';
  static const tokenPurchaseCurrentBalance = 'tokens.purchase.current_balance';
  static const tokenPurchaseButton = 'tokens.purchase.button';

  // Memory Stats Page — mastery levels & stat labels
  static const memoryStatsMaster = 'memory_stats_page.master';
  static const memoryStatsTotalVerses = 'memory_stats_page.total_verses';
  static const memoryStatsTotalReviews = 'memory_stats_page.total_reviews';
  static const memoryStatsPerfectRecalls = 'memory_stats_page.perfect_recalls';
  static const memoryStatsPracticeDays = 'memory_stats_page.practice_days';
  static const memoryStatsVerseCount = 'memory_stats_page.verse_count';

  /// Shared-link outcomes for someone who is not in the fellowship.
  static const fellowshipLinkUnavailable = 'community.link_unavailable';
  static const fellowshipLinkNotAMember = 'community.link_not_a_member';
  static const fellowshipThisGroup = 'community.this_group';
  static const fellowshipJoinPromptTitle = 'community.join_prompt_title';
  static const fellowshipJoinPromptBody = 'community.join_prompt_body';
  static const fellowshipJoinPromptConfirm = 'community.join_prompt_confirm';
  static const fellowshipJoinFailed = 'community.join_failed';

  /// Shared-link outcome when the linked study guide can't be opened.
  static const studyGuideLinkUnavailable = 'study_guide.link_unavailable';

  /// Prompt appended to a shared study guide's preview text, pointing at the
  /// full guide link.
  static const studyGuideShareReadMore = 'study_guide.share_read_more';

  static const fellowshipJoinToViewTitle = 'community.join_to_view_title';
  static const fellowshipJoinToViewBody = 'community.join_to_view_body';
  static const fellowshipJoinAction = 'community.join_action';

  // Community — create post sheet
  static const fellowshipLetDisciplerAnswer = 'community.let_discipler_answer';
  static const fellowshipLetDisciplerAnswerHint =
      'community.let_discipler_answer_hint';

  // Community — Discover join confirmation and the Discipler guide label
  static const communityJoined = 'community.joined';
  static const communityGuidedByDiscipler = 'community.guided_by_discipler';

  // Fellowship share section (study guide screen)
  static const studyGuideFellowshipShareTitle =
      'study_guide.fellowship.share_title';
  static const studyGuideFellowshipCardTitle =
      'study_guide.fellowship.card_title';
  static const studyGuideFellowshipCardSubtitle =
      'study_guide.fellowship.card_subtitle';
  static const studyGuideFellowshipInputHint =
      'study_guide.fellowship.input_hint';
  static const studyGuideFellowshipWalkthroughDesc =
      'study_guide.fellowship.walkthrough_desc';

  // Walkthrough tooltip titles & descriptions (study guide screen)
  static const studyGuideWalkthroughMenuTitle =
      'study_guide.walkthrough.menu.title';
  static const studyGuideWalkthroughMenuDesc =
      'study_guide.walkthrough.menu.desc';
  static const studyGuideWalkthroughTtsTitle =
      'study_guide.walkthrough.tts.title';
  static const studyGuideWalkthroughTtsDesc =
      'study_guide.walkthrough.tts.desc';
  static const studyGuideWalkthroughChatTitle =
      'study_guide.walkthrough.chat.title';
  static const studyGuideWalkthroughChatDesc =
      'study_guide.walkthrough.chat.desc';
  static const studyGuideWalkthroughNotesTitle =
      'study_guide.walkthrough.notes.title';
  static const studyGuideWalkthroughNotesDesc =
      'study_guide.walkthrough.notes.desc';
  static const studyGuideWalkthroughDeeperTitle =
      'study_guide.walkthrough.deeper.title';
  static const studyGuideWalkthroughDeeperDesc =
      'study_guide.walkthrough.deeper.desc';

  // Soft paywall dialog
  static const tokenSoftPaywallUsedTitle = 'tokens.soft_paywall.used_title';
  static const tokenSoftPaywallUsedMessage = 'tokens.soft_paywall.used_message';
  static const tokenSoftPaywallLowTitle = 'tokens.soft_paywall.low_title';
  static const tokenSoftPaywallLowMessage = 'tokens.soft_paywall.low_message';
  static const tokenSoftPaywallSeePlans = 'tokens.soft_paywall.see_plans';
  static const tokenSoftPaywallPurchase = 'tokens.soft_paywall.purchase';
  static const tokenSoftPaywallMaybeLater = 'tokens.soft_paywall.maybe_later';
  static const tokenSoftPaywallResetHour = 'tokens.soft_paywall.reset_hour';
  static const tokenSoftPaywallResetHours = 'tokens.soft_paywall.reset_hours';
  static const tokenSoftPaywallResetSoon = 'tokens.soft_paywall.reset_soon';

  // Insufficient tokens dialog
  static const tokenDialogTitle = 'tokens.dialog.title';
  static const tokenDialogSubtitle = 'tokens.dialog.subtitle';
  static const tokenDialogYourCredits = 'tokens.dialog.your_credits';
  static const tokenDialogNeeded = 'tokens.dialog.needed';
  static const tokenDialogCreditsUnit = 'tokens.dialog.credits_unit';
  static const tokenDialogGetMore = 'tokens.dialog.get_more';
  static const tokenDialogPlanCreditsPerDay =
      'tokens.dialog.plan_credits_per_day';
  static const tokenDialogPlanUnlimited = 'tokens.dialog.plan_unlimited';
  static const tokenDialogInfoBox = 'tokens.dialog.info_box';
  static const tokenDialogPurchase = 'tokens.dialog.purchase';
  static const tokenDialogMaybeLater = 'tokens.dialog.maybe_later';
  static const tokenDialogViewPlans = 'tokens.dialog.view_plans';

  // Practice Mode Info Sheet (shared)
  static const practiceModeInfoGotIt = 'practice_mode_info.got_it';

  // Practice Mode Info Steps — Flip Card
  static const practiceModeInfoFlipCardStep1 =
      'practice_mode_info.flip_card.step1';
  static const practiceModeInfoFlipCardStep2 =
      'practice_mode_info.flip_card.step2';
  static const practiceModeInfoFlipCardStep3 =
      'practice_mode_info.flip_card.step3';

  // Practice Mode Info Steps — Word Bank
  static const practiceModeInfoWordBankStep1 =
      'practice_mode_info.word_bank.step1';
  static const practiceModeInfoWordBankStep2 =
      'practice_mode_info.word_bank.step2';
  static const practiceModeInfoWordBankStep3 =
      'practice_mode_info.word_bank.step3';

  // Practice Mode Info Steps — Cloze
  static const practiceModeInfoClozeStep1 = 'practice_mode_info.cloze.step1';
  static const practiceModeInfoClozeStep2 = 'practice_mode_info.cloze.step2';
  static const practiceModeInfoClozeStep3 = 'practice_mode_info.cloze.step3';

  // Practice Mode Info Steps — First Letter
  static const practiceModeInfoFirstLetterStep1 =
      'practice_mode_info.first_letter.step1';
  static const practiceModeInfoFirstLetterStep2 =
      'practice_mode_info.first_letter.step2';
  static const practiceModeInfoFirstLetterStep3 =
      'practice_mode_info.first_letter.step3';

  // Practice Mode Info Steps — Progressive Reveal
  static const practiceModeInfoProgressiveStep1 =
      'practice_mode_info.progressive.step1';
  static const practiceModeInfoProgressiveStep2 =
      'practice_mode_info.progressive.step2';
  static const practiceModeInfoProgressiveStep3 =
      'practice_mode_info.progressive.step3';

  // Practice Mode Info Steps — Word Scramble
  static const practiceModeInfoWordScrambleStep1 =
      'practice_mode_info.word_scramble.step1';
  static const practiceModeInfoWordScrambleStep2 =
      'practice_mode_info.word_scramble.step2';
  static const practiceModeInfoWordScrambleStep3 =
      'practice_mode_info.word_scramble.step3';

  // Practice Mode Info Steps — Audio
  static const practiceModeInfoAudioStep1 = 'practice_mode_info.audio.step1';
  static const practiceModeInfoAudioStep2 = 'practice_mode_info.audio.step2';
  static const practiceModeInfoAudioStep3 = 'practice_mode_info.audio.step3';

  // Practice Mode Info Steps — Type It Out
  static const practiceModeInfoTypeItOutStep1 =
      'practice_mode_info.type_it_out.step1';
  static const practiceModeInfoTypeItOutStep2 =
      'practice_mode_info.type_it_out.step2';
  static const practiceModeInfoTypeItOutStep3 =
      'practice_mode_info.type_it_out.step3';

  // Per-page walkthrough tooltips for each practice mode
  static const walkthroughPracticeFlipCardTitle =
      'walkthrough.practice_flip_card.title';
  static const walkthroughPracticeFlipCardDesc =
      'walkthrough.practice_flip_card.desc';
  static const walkthroughPracticeWordBankTitle =
      'walkthrough.practice_word_bank.title';
  static const walkthroughPracticeWordBankDesc =
      'walkthrough.practice_word_bank.desc';
  static const walkthroughPracticeClozeTitle =
      'walkthrough.practice_cloze.title';
  static const walkthroughPracticeClozeDesc = 'walkthrough.practice_cloze.desc';
  static const walkthroughPracticeFirstLetterTitle =
      'walkthrough.practice_first_letter.title';
  static const walkthroughPracticeFirstLetterDesc =
      'walkthrough.practice_first_letter.desc';
  static const walkthroughPracticeProgressiveTitle =
      'walkthrough.practice_progressive.title';
  static const walkthroughPracticeProgressiveDesc =
      'walkthrough.practice_progressive.desc';
  static const walkthroughPracticeWordScrambleTitle =
      'walkthrough.practice_word_scramble.title';
  static const walkthroughPracticeWordScrambleDesc =
      'walkthrough.practice_word_scramble.desc';
  static const walkthroughPracticeAudioTitle =
      'walkthrough.practice_audio.title';
  static const walkthroughPracticeAudioDesc = 'walkthrough.practice_audio.desc';
  static const walkthroughPracticeTypeItOutTitle =
      'walkthrough.practice_type_it_out.title';
  static const walkthroughPracticeTypeItOutDesc =
      'walkthrough.practice_type_it_out.desc';

  // Daily Review Limit
  static const dailyReviewLimitTitle = 'daily_review_limit.title';
  static const dailyReviewLimitMessage = 'daily_review_limit.message';
  static const dailyReviewLimitCurrentPlan = 'daily_review_limit.current_plan';
  static const dailyReviewLimitGetMore = 'daily_review_limit.get_more';
  static const dailyReviewLimitMaybeLater = 'daily_review_limit.maybe_later';
  static const dailyReviewLimitUpgradeNow = 'daily_review_limit.upgrade_now';
  static const dailyReviewLimitReachedMotivation =
      'daily_review_limit.reached_motivation';
  static const dailyReviewLimitUnlimited = 'daily_review_limit.unlimited';
  static const dailyReviewLimitCount = 'daily_review_limit.count';
  static const dailyReviewLimitLimited = 'daily_review_limit.limited';

  // Practice mode daily unlock limit dialog
  static const practiceUnlockLimitTitle = 'practice_unlock_limit.title';
  static const practiceUnlockLimitMessageOne =
      'practice_unlock_limit.message_one';
  static const practiceUnlockLimitMessageOther =
      'practice_unlock_limit.message_other';
  static const practiceUnlockLimitUnlockedToday =
      'practice_unlock_limit.unlocked_today';
  static const practiceUnlockLimitUpgradePrompt =
      'practice_unlock_limit.upgrade_prompt';
  static const practiceUnlockLimitStillPractice =
      'practice_unlock_limit.still_practice';
  static const practiceUnlockLimitModesPerDayOne =
      'practice_unlock_limit.modes_per_day_one';
  static const practiceUnlockLimitModesPerDayOther =
      'practice_unlock_limit.modes_per_day_other';
  static const practiceUnlockLimitAllModes = 'practice_unlock_limit.all_modes';
  static const practiceUnlockLimitMaybeLater =
      'practice_unlock_limit.maybe_later';
  static const practiceUnlockLimitViewPlans =
      'practice_unlock_limit.view_plans';

  // Practice mode tier-locked dialog
  static const practiceTierLockedTitle = 'practice_tier_locked.title';
  static const practiceTierLockedPlanIncludes =
      'practice_tier_locked.plan_includes';
  static const practiceTierLockedUnlockWith =
      'practice_tier_locked.unlock_with';
  static const practiceTierLockedAllModesPlus =
      'practice_tier_locked.all_modes_plus';
  static const practiceTierLockedAllModesUnlimited =
      'practice_tier_locked.all_modes_unlimited';
  static const practiceTierLockedMaybeLater =
      'practice_tier_locked.maybe_later';
  static const practiceTierLockedUpgradeNow =
      'practice_tier_locked.upgrade_now';

  // Plan Features — daily reviews
  static const planFeatureUnlimitedDailyReviews =
      'plan_features.unlimited_daily_reviews';
  static const planFeatureDailyReviews = 'plan_features.daily_reviews';
  static const planComparisonDailyReviews =
      'plan_features.comparison_daily_reviews';

  // ==========================================================================
  // Reset Progress (shared by learning paths and memory verses)
  // ==========================================================================

  /// Word the user must type to confirm a destructive reset.
  static const resetProgressConfirmWord = 'reset_progress.confirm_word';
  static const resetProgressTypeToConfirm = 'reset_progress.type_to_confirm';
  static const resetProgressCancel = 'reset_progress.cancel';
  static const resetProgressIrreversible = 'reset_progress.irreversible';

  /// Localized failure messages, keyed off the reset failure's `code` /
  /// `isNetworkError`. See `core/utils/reset_progress_error_localizer.dart`.
  static const resetProgressErrorRateLimited =
      'reset_progress.error_rate_limited';
  static const resetProgressErrorAuth = 'reset_progress.error_auth';
  static const resetProgressErrorNetwork = 'reset_progress.error_network';
  static const resetProgressErrorGeneric = 'reset_progress.error_generic';

  // ==========================================================================
  // Microphone permission (Discipler voice chat and follow-up chat input)
  // ==========================================================================

  static const micPermissionTitle = 'voice_buddy.mic_permission.title';
  static const micPermissionMessage = 'voice_buddy.mic_permission.message';

  /// Shown when the permission can only be restored from app settings.
  static const micPermissionBlockedMessage =
      'voice_buddy.mic_permission.blocked_message';
  static const micPermissionOpenSettings =
      'voice_buddy.mic_permission.open_settings';
  static const micPermissionTypeInstead =
      'voice_buddy.mic_permission.type_instead';
  static const micPermissionAllow = 'voice_buddy.mic_permission.allow';

  // ==========================================================================
  // Discipler tab: start screen, chat and voice session
  // ==========================================================================

  static const voiceSessionHeadline = 'voice_buddy.session.headline';

  /// Takes `{language}`.
  static const voiceSessionSpeakingLanguage =
      'voice_buddy.session.speaking_language';
  static const voiceSessionChangeLanguage =
      'voice_buddy.session.change_language';
  static const voiceSessionStartTalking = 'voice_buddy.session.start_talking';
  static const voiceSessionType = 'voice_buddy.session.type';
  static const voiceSessionTryAsking = 'voice_buddy.session.try_asking';
  static const voiceSessionSuggestion1 = 'voice_buddy.session.suggestion_1';
  static const voiceSessionSuggestion2 = 'voice_buddy.session.suggestion_2';
  static const voiceSessionSuggestion3 = 'voice_buddy.session.suggestion_3';

  /// Takes `{remaining}` and `{limit}`.
  static const voiceSessionQuotaLeft = 'voice_buddy.session.quota_left';
  static const voiceSessionStatusReady = 'voice_buddy.session.status_ready';
  static const voiceSessionStatusListening =
      'voice_buddy.session.status_listening';
  static const voiceSessionStatusThinking =
      'voice_buddy.session.status_thinking';
  static const voiceSessionStatusSpeaking =
      'voice_buddy.session.status_speaking';
  static const voiceSessionYou = 'voice_buddy.session.you';
  static const voiceSessionYouAsked = 'voice_buddy.session.you_asked';
  static const voiceSessionVoiceMode = 'voice_buddy.session.voice_mode';
  static const voiceSessionTypingMode = 'voice_buddy.session.typing_mode';
  static const voiceSessionSend = 'voice_buddy.session.send';
  static const voiceSessionKeepTalking = 'voice_buddy.session.keep_talking';

  /// Takes `{count}`.
  static const voiceSessionRateStars = 'voice_buddy.session.rate_stars';

  // Credits / plans (quiet ledger)
  static const ledgerCreditsTitle = 'ledger.credits_title';
  static const ledgerPlanName = 'ledger.plan_name';
  static const ledgerDailyCredits = 'ledger.daily_credits';
  static const ledgerLeftToday = 'ledger.left_today';
  static const ledgerOfTotal = 'ledger.of_total';
  static const ledgerResetsAt = 'ledger.resets_at';
  static const ledgerUnlimitedTitle = 'ledger.unlimited_title';
  static const ledgerUsedToday = 'ledger.used_today';
  static const ledgerPurchased = 'ledger.purchased';
  static const ledgerTotal = 'ledger.total';
  static const ledgerGetCredits = 'ledger.get_credits';
  static const ledgerUpgrade = 'ledger.upgrade';
  static const ledgerPriceRenews = 'ledger.price_renews';
  static const ledgerDailyByPlan = 'ledger.daily_by_plan';
  static const ledgerActivity = 'ledger.activity';
  static const ledgerBalanceSubtitle = 'ledger.balance_subtitle';
  static const ledgerPopular = 'ledger.popular';
  static const ledgerPercentOff = 'ledger.percent_off';
  static const ledgerNeverExpire = 'ledger.never_expire';
  static const ledgerBuyCta = 'ledger.buy_cta';
  static const ledgerChoosePack = 'ledger.choose_pack';
  static const ledgerCustomLabel = 'ledger.custom_label';
  static const ledgerCustomHint = 'ledger.custom_hint';
  static const ledgerCustomRate = 'ledger.custom_rate';
  static const ledgerCustomTip = 'ledger.custom_tip';
  static const ledgerCreditsLabel = 'ledger.credits_label';
  static const ledgerCostLabel = 'ledger.cost_label';
  static const ledgerLoadingPrices = 'ledger.loading_prices';
  static const ledgerPricesError = 'ledger.prices_error';
  static const ledgerPacksUnavailable = 'ledger.packs_unavailable';
  static const ledgerNoPacks = 'ledger.no_packs';
  static const ledgerChoosePackOrAmount = 'ledger.choose_pack_or_amount';
  static const ledgerPurchasePausedTitle = 'ledger.purchase_paused_title';
  static const ledgerPurchasePausedBody = 'ledger.purchase_paused_body';
  static const ledgerPremiumUnlimitedTitle = 'ledger.premium_unlimited_title';
  static const ledgerPremiumUnlimitedBody = 'ledger.premium_unlimited_body';
  static const ledgerPaymentFailed = 'ledger.payment_failed';
  static const ledgerPaymentPending = 'ledger.payment_pending';
  static const ledgerPaymentSuccessful = 'ledger.payment_successful';
  static const ledgerCreditsAdded = 'ledger.credits_added';
  static const ledgerNewBalance = 'ledger.new_balance';
  static const ledgerPaid = 'ledger.paid';
  static const ledgerReceipt = 'ledger.receipt';
  static const ledgerDate = 'ledger.date';
  static const ledgerStartStudy = 'ledger.start_study';
  static const ledgerBackToCredits = 'ledger.back_to_credits';
  static const ledgerSince = 'ledger.since';
  static const ledgerCreditsUsed = 'ledger.credits_used';
  static const ledgerStudies = 'ledger.studies';
  static const ledgerAvgPerStudy = 'ledger.avg_per_study';
  static const ledgerMostUsed = 'ledger.most_used';
  static const ledgerToday = 'ledger.today';
  static const ledgerYesterday = 'ledger.yesterday';
  static const ledgerFromDaily = 'ledger.from_daily';
  static const ledgerFromPurchased = 'ledger.from_purchased';
  static const ledgerDailyPlusPurchased = 'ledger.daily_plus_purchased';
  static const ledgerStudyGuide = 'ledger.study_guide';
  static const ledgerFollowUp = 'ledger.follow_up';
  static const ledgerStatsError = 'ledger.stats_error';
  static const ledgerPurchasesTitle = 'ledger.purchases_title';
  static const ledgerPurchasesSubtitle = 'ledger.purchases_subtitle';
  static const ledgerPurchasesCount = 'ledger.purchases_count';
  static const ledgerCredits = 'ledger.credits';
  static const ledgerSpent = 'ledger.spent';
  static const ledgerCreditsCount = 'ledger.credits_count';
  static const ledgerStatusSuccess = 'ledger.status_success';
  static const ledgerStatusPending = 'ledger.status_pending';
  static const ledgerStatusFailed = 'ledger.status_failed';
  static const ledgerReportIssue = 'ledger.report_issue';
  static const ledgerDetails = 'ledger.details';
  static const ledgerHideDetails = 'ledger.hide_details';
  static const ledgerPaymentId = 'ledger.payment_id';
  static const ledgerOrderId = 'ledger.order_id';
  static const ledgerCopied = 'ledger.copied';
  static const ledgerPlansTitle = 'ledger.plans_title';
  static const ledgerPlansSubtitle = 'ledger.plans_subtitle';
  static const ledgerRecommended = 'ledger.recommended';
  static const ledgerYourCurrentPlan = 'ledger.your_current_plan';
  static const ledgerPerMo = 'ledger.per_mo';
  static const ledgerPerMonth = 'ledger.per_month';
  static const ledgerSubscriptionsPaused = 'ledger.subscriptions_paused';
  static const ledgerLoadingPlans = 'ledger.loading_plans';
  static const ledgerPlansError = 'ledger.plans_error';
  static const ledgerNoPlans = 'ledger.no_plans';
  static const ledgerCancelAnytimeMonthly = 'ledger.cancel_anytime_monthly';
  static const ledgerWhatYouGet = 'ledger.what_you_get';
  static const ledgerRenewsNote = 'ledger.renews_note';
  static const ledgerRestorePurchases = 'ledger.restore_purchases';
  static const ledgerCtaWithPrice = 'ledger.cta_with_price';
  static const ledgerBilling = 'ledger.billing';
  static const ledgerPaidWith = 'ledger.paid_with';
  static const ledgerCancelPlan = 'ledger.cancel_plan';
  static const ledgerDowngrade = 'ledger.downgrade';
  static const ledgerStatusActive = 'ledger.status_active';
  static const ledgerStudyCostsTitle = 'ledger.study_costs_title';
  static const ledgerStudyCostsLine = 'ledger.study_costs_line';
  static const ledgerCancelEyebrow = 'ledger.cancel_eyebrow';
  static const ledgerCancelTitle = 'ledger.cancel_title';
  static const ledgerCancelBody = 'ledger.cancel_body';
  static const ledgerCancelEnd = 'ledger.cancel_end';
  static const ledgerCancelEndSub = 'ledger.cancel_end_sub';
  static const ledgerCancelNow = 'ledger.cancel_now';
  static const ledgerCancelNowSub = 'ledger.cancel_now_sub';
  static const ledgerKeepPlan = 'ledger.keep_plan';
  static const ledgerConfirmCancel = 'ledger.confirm_cancel';
  static const ledgerInvoicesTitle = 'ledger.invoices_title';
  static const ledgerInvoicesSubtitle = 'ledger.invoices_subtitle';
  static const ledgerPaidOn = 'ledger.paid_on';
  static const ledgerDownloadInvoice = 'ledger.download_invoice';
  static const ledgerGeneratingPdf = 'ledger.generating_pdf';
  static const ledgerInvoicesEmpty = 'ledger.invoices_empty';
  static const ledgerInvoicesEmptyBody = 'ledger.invoices_empty_body';
  static const ledgerInvoicesError = 'ledger.invoices_error';
  static const ledgerInvoiceNumber = 'ledger.invoice_number';
  static const ledgerPaisePerCredit = 'ledger.paise_per_credit';
  static const ledgerStandardTagline = 'ledger.standard_tagline';
  static const ledgerPlusTagline = 'ledger.plus_tagline';

  // Discipler voice settings: language sheet and monthly limit dialog
  static const voiceLanguageSheetTitle = 'voice_buddy.language_sheet.title';

  /// "Uses your app language ({language})".
  static const voiceLanguageSheetDefaultSubtitle =
      'voice_buddy.language_sheet.default_subtitle';
  static const voiceLimitMessageOne = 'voice_buddy.limit_dialog.message_one';
  static const voiceLimitMessageOther =
      'voice_buddy.limit_dialog.message_other';
  static const voiceLimitThisMonth = 'voice_buddy.limit_dialog.this_month';

  /// "{used} of {limit} used".
  static const voiceLimitUsed = 'voice_buddy.limit_dialog.used';
  static const voiceLimitUpgradeHeading =
      'voice_buddy.limit_dialog.upgrade_heading';
  static const voiceLimitViewPlans = 'voice_buddy.limit_dialog.view_plans';
  static const voiceLimitMaybeLater = 'voice_buddy.limit_dialog.maybe_later';

  // Community shared widgets (fellowship cards, posts, Community tab)
  /// "Mentor: {name}".
  static const communitySharedMentor = 'community_shared.mentor';

  /// "{name} (you)".
  static const communitySharedMentorYou = 'community_shared.mentor_you';

  /// "Lesson {number}".
  static const communitySharedLesson = 'community_shared.lesson';

  /// "Lesson {number} of {total}".
  static const communitySharedLessonOf = 'community_shared.lesson_of';

  /// "{current} of {total}".
  static const communitySharedProgress = 'community_shared.progress';
  static const communitySharedDailyStudy = 'community_shared.daily_study';
  static const communitySharedStartStudy = 'community_shared.start_study';
  static const communitySharedReplyOne = 'community_shared.reply_one';

  /// "{count} replies".
  static const communitySharedReplies = 'community_shared.replies';
  static const communitySharedDiscoverTab = 'community_shared.discover_tab';
  static const communitySharedSearchHint = 'community_shared.search_hint';
  static const communitySharedJoinWithCode = 'community_shared.join_with_code';
  static const communitySharedCreateLocked = 'community_shared.create_locked';
  static const communitySharedOfflineTitle = 'community_shared.offline_title';
  static const communitySharedOfflineBody = 'community_shared.offline_body';
  static const communitySharedLoadErrorBody =
      'community_shared.load_error_body';
  static const communitySharedMoreOptions = 'community_shared.more_options';

  // Fellowship lessons path (status markers, summary card).
  static const communityLessonsStatusDone = 'community_lessons.status_done';
  static const communityLessonsStatusUpcoming =
      'community_lessons.status_upcoming';
  static const communityLessonsStatusLocked = 'community_lessons.status_locked';

  /// "{done} of {total} done".
  static const communityLessonsGroupDone = 'community_lessons.group_done';

  /// "+{xp} XP earned".
  static const communityLessonsXpEarned = 'community_lessons.xp_earned';

  /// "Finished all {total} lessons together" (group finished its path).
  static const communityLessonsGroupFinished =
      'community_lessons.group_finished';

  /// "Moves everyone to lesson {number}" (mentor advance hint).
  static const communityLessonsAdvanceHint = 'community_lessons.advance_hint';

  /// "{count} of {total} caught up" (mentor member progress).
  static const communityLessonsCaughtUp = 'community_lessons.caught_up';

  // Community post cards (shared-guide card, study-note chip).
  /// "Open study guide".
  static const communityPostOpenGuide = 'community_post.open_guide';

  /// "Copy text" (post and reply menus).
  static const communityPostCopyText = 'community_post.copy_text';

  /// "On: {title}".
  static const communityPostOnTopic = 'community_post.on_topic';
  static const communityPostInputScripture = 'community_post.input_scripture';
  static const communityPostInputTopic = 'community_post.input_topic';
  static const communityPostInputQuestion = 'community_post.input_question';

  /// "{mode} study guide", e.g. "Standard study guide".
  static const communityPostModeStudyGuide = 'community_post.mode_study_guide';

  // Post timestamps: "Just now", "5m ago", "2h ago", "Yesterday",
  // "3 days ago"; older posts show a localized date.
  static const communityPostTimeJustNow = 'community_post.time_just_now';
  static const communityPostTimeMinutesAgo = 'community_post.time_minutes_ago';
  static const communityPostTimeHoursAgo = 'community_post.time_hours_ago';
  static const communityPostTimeYesterday = 'community_post.time_yesterday';
  static const communityPostTimeDaysAgo = 'community_post.time_days_ago';

  // Reaction pill labels. The stored reaction keys stay the same; these are
  // only how each one reads on the pill.
  static const communityPostReactionAmen = 'community_post.reaction_amen';
  static const communityPostReactionPrayed = 'community_post.reaction_prayed';
  static const communityPostReactionPraise = 'community_post.reaction_praise';
  static const communityPostReactionHelpful = 'community_post.reaction_helpful';
  static const communityPostReactionLove = 'community_post.reaction_love';
  static const communityPostReactionFire = 'community_post.reaction_fire';

  // Community inner pages (meetings, schedule sheet, fellowship settings,
  // daily post, lesson discussion, share-guide sheet).
  static const communityPagesThisWeek = 'community_pages.this_week';
  static const communityPagesNextWeek = 'community_pages.next_week';
  static const communityPagesLater = 'community_pages.later';
  static const communityPagesJoin = 'community_pages.join';
  static const communityPagesNoLink = 'community_pages.no_link';
  static const communityPagesOnline = 'community_pages.online';
  static const communityPagesLoadError = 'community_pages.load_error';
  static const communityPagesCancelMeeting = 'community_pages.cancel_meeting';

  /// "Cancel \"{title}\"? …".
  static const communityPagesCancelBody = 'community_pages.cancel_body';
  static const communityPagesKeep = 'community_pages.keep';
  static const communityPagesOneTime = 'community_pages.one_time';
  static const communityPagesDaily = 'community_pages.daily';
  static const communityPagesWeekly = 'community_pages.weekly';
  static const communityPagesMonthly = 'community_pages.monthly';
  static const communityPagesScheduleTitle = 'community_pages.schedule_title';
  static const communityPagesTitleLabel = 'community_pages.title_label';
  static const communityPagesTitleHint = 'community_pages.title_hint';
  static const communityPagesTitleRequired = 'community_pages.title_required';
  static const communityPagesDescriptionLabel =
      'community_pages.description_label';
  static const communityPagesDateTime = 'community_pages.date_time';
  static const communityPagesMeetingType = 'community_pages.meeting_type';
  static const communityPagesInPerson = 'community_pages.in_person';
  static const communityPagesLocationLabel = 'community_pages.location_label';
  static const communityPagesLocationHint = 'community_pages.location_hint';
  static const communityPagesLocationRequired =
      'community_pages.location_required';
  static const communityPagesDuration = 'community_pages.duration';

  /// "{count} min".
  static const communityPagesMinutes = 'community_pages.minutes';

  /// "{count} hr".
  static const communityPagesHours = 'community_pages.hours';

  /// "{hours} hr {minutes} min".
  static const communityPagesHoursMinutes = 'community_pages.hours_minutes';
  static const communityPagesRepeat = 'community_pages.repeat';
  static const communityPagesSubmit = 'community_pages.submit';
  static const communityPagesCalendarTitle = 'community_pages.calendar_title';
  static const communityPagesCalendarBody = 'community_pages.calendar_body';
  static const communityPagesCalendarSkip = 'community_pages.calendar_skip';
  static const communityPagesContinue = 'community_pages.continue';
  static const communityPagesCalendarFailedTitle =
      'community_pages.calendar_failed_title';
  static const communityPagesCalendarFailedBody =
      'community_pages.calendar_failed_body';
  static const communityPagesCreateAnyway = 'community_pages.create_anyway';
  static const communityPagesYouAreMentor = 'community_pages.you_are_mentor';
  static const communityPagesAbout = 'community_pages.about';
  static const communityPagesByDiscipler = 'community_pages.by_discipler';
  static const communityPagesDiscussion = 'community_pages.discussion';
  static const communityPagesDiscussionSubtitle =
      'community_pages.discussion_subtitle';
  static const communityPagesDiscussionEmpty =
      'community_pages.discussion_empty';
  static const communityPagesOpenGuide = 'community_pages.open_guide';
  static const communityPagesMilestone = 'community_pages.milestone';
  static const communityPagesReplyHint = 'community_pages.reply_hint';
  static const communityPagesReflectionHint = 'community_pages.reflection_hint';
  static const communityPagesSend = 'community_pages.send';
  static const communityPagesShareTitle = 'community_pages.share_title';
  static const communityPagesShareTo = 'community_pages.share_to';
  static const communityPagesShareNone = 'community_pages.share_none';
  static const communityPagesShareMessageLabel =
      'community_pages.share_message_label';
  static const communityPagesShareMessageHint =
      'community_pages.share_message_hint';
  static const communityPagesShareSelect = 'community_pages.share_select';
  static const communityPagesShareToOne = 'community_pages.share_to_one';

  /// "Share to {count} fellowships".
  static const communityPagesShareToMany = 'community_pages.share_to_many';
  static const communityPagesMemberOne = 'community_pages.member_one';

  /// "{count} members".
  static const communityPagesMembers = 'community_pages.members';

  // Fellowship home, feed, post detail, members and lessons screens
  static const communityFellowshipPostTitle = 'community_fellowship.post_title';
  static const communityFellowshipPostUnavailable =
      'community_fellowship.post_unavailable';
  static const communityFellowshipCommentsEmpty =
      'community_fellowship.comments_empty';
  static const communityFellowshipCommentsLoadFailed =
      'community_fellowship.comments_load_failed';
  static const communityFellowshipCommentHint =
      'community_fellowship.comment_hint';
  static const communityFellowshipSend = 'community_fellowship.send';
  static const communityFellowshipMention = 'community_fellowship.mention';
  static const communityFellowshipStudyingTogether =
      'community_fellowship.studying_together';
  static const communityFellowshipGroupProgress =
      'community_fellowship.group_progress';
  static const communityFellowshipViewAllPosts =
      'community_fellowship.view_all_posts';
  static const communityFellowshipNow = 'community_fellowship.now';
  static const communityFellowshipPathActive =
      'community_fellowship.path_active';
  static const communityFellowshipAssignFailed =
      'community_fellowship.assign_failed';
  static const communityFellowshipAdvanceFailed =
      'community_fellowship.advance_failed';
  static const communityFellowshipResetFailed =
      'community_fellowship.reset_failed';
  static const communityFellowshipNoPaths = 'community_fellowship.no_paths';
  static const communityFellowshipReportReasonShort =
      'community_fellowship.report_reason_short';
  static const communityFellowshipPostHintGeneral =
      'community_fellowship.post_hint_general';
  static const communityFellowshipPostHintPrayer =
      'community_fellowship.post_hint_prayer';
  static const communityFellowshipPostHintPraise =
      'community_fellowship.post_hint_praise';
  static const communityFellowshipPostHintQuestion =
      'community_fellowship.post_hint_question';
  static const communityFellowshipTypeDescGeneral =
      'community_fellowship.type_desc_general';
  static const communityFellowshipTypeDescPrayer =
      'community_fellowship.type_desc_prayer';
  static const communityFellowshipTypeDescPraise =
      'community_fellowship.type_desc_praise';
  static const communityFellowshipTypeDescQuestion =
      'community_fellowship.type_desc_question';

  // Study guide feedback: snackbars, listen controls, verse sheet eyebrow.
  static const guideFeedbackCompletedWhileAway =
      'guide_feedback.completed_while_away';
  static const guideFeedbackFellowshipPathComplete =
      'guide_feedback.fellowship_path_complete';
  static const guideFeedbackFellowshipNextGuide =
      'guide_feedback.fellowship_next_guide';
  static const guideFeedbackNotesSaved = 'guide_feedback.notes_saved';
  static const guideFeedbackReflectionNotLoaded =
      'guide_feedback.reflection_not_loaded';
  static const guideFeedbackReflectionSaved = 'guide_feedback.reflection_saved';
  static const guideFeedbackReflectionFailed =
      'guide_feedback.reflection_failed';
  static const guideFeedbackSavedNotesFailed =
      'guide_feedback.saved_notes_failed';
  static const guideFeedbackAuthExpired = 'guide_feedback.auth_expired';
  static const guideFeedbackNetworkError = 'guide_feedback.network_error';
  static const guideFeedbackAlreadySaved = 'guide_feedback.already_saved';
  static const guideFeedbackSharedToFellowship =
      'guide_feedback.shared_to_fellowship';
  static const guideFeedbackOk = 'guide_feedback.ok';
  static const guideFeedbackTtsPrevSection = 'guide_feedback.tts_prev_section';
  static const guideFeedbackTtsNextSection = 'guide_feedback.tts_next_section';
  static const guideFeedbackTtsPlay = 'guide_feedback.tts_play';
  static const guideFeedbackTtsReplay = 'guide_feedback.tts_replay';
  static const guideFeedbackTtsProgress = 'guide_feedback.tts_progress';
  static const guideFeedbackVerseEyebrow = 'guide_feedback.verse_eyebrow';

  // Study screens: screenshot share prompt, interrupted generation, offline
  // Generate button, download picker.
  static const studyUiScreenshotEyebrow = 'study_ui.screenshot.eyebrow';
  static const studyUiScreenshotTitle = 'study_ui.screenshot.title';
  static const studyUiScreenshotBody = 'study_ui.screenshot.body';
  static const studyUiScreenshotShareFellowship =
      'study_ui.screenshot.share_fellowship';
  static const studyUiDismiss = 'study_ui.dismiss';
  static const studyUiGenerationInterrupted = 'study_ui.generation_interrupted';
  static const studyUiGenerationTimeout = 'study_ui.generation_timeout';
  static const studyUiOfflineGenerate = 'study_ui.offline_generate';
  static const studyUiTokensPerGuide = 'study_ui.tokens_per_guide';

  // Path lesson eyebrow on the study guide header.
  static const lessonEyebrow = 'lesson.eyebrow';
  static const lessonMarkComplete = 'lesson.mark_complete';
  static const lessonCompleteTitle = 'lesson.complete_title';
  static const lessonUpNext = 'lesson.up_next';
  static const lessonContinueTo = 'lesson.continue_to';
  static const lessonBackHome = 'lesson.back_home';
  static const lessonPathFinished = 'lesson.path_finished';
  static const lessonFullGuideLink = 'lesson.full_guide_link';
  static const lessonQuickRead = 'lesson.quick_read';
  static const lessonFullGuide = 'lesson.full_guide';

  // Out-of-credits sheet.
  static const creditsOutEyebrow = 'credits.out_eyebrow';
  static const creditsOutTitle = 'credits.out_title';
  static const creditsOutBody = 'credits.out_body';
  static const creditsOutNeed = 'credits.out_need';
  static const creditsGet = 'credits.get';
  static const creditsViewSaved = 'credits.view_saved';
  static const creditsMaybeLater = 'credits.maybe_later';
  static const creditsStudyCosts = 'credits.study_costs';
  static const creditsFollowUp = 'credits.follow_up';
  static const creditsExactCostNote = 'credits.exact_cost_note';

  // My Plan summary card
  static const planTrialUntil = 'plan.trial_until';
  static const planLeftToday = 'plan.left_today';
  static const planResetsAt = 'plan.resets_at';
  static const planBilledVia = 'plan.billed_via';
  static const planRenewsOn = 'plan.renews_on';
  static const planViewPlans = 'plan.view_plans';

  // Single-input Generate screen.
  static const generateSimpleEyebrow = 'generate_simple.eyebrow';
  static const generateSimpleTitle = 'generate_simple.title';
  static const generateSimpleHint = 'generate_simple.hint';
  static const generateSimpleTypeScripture = 'generate_simple.type_scripture';
  static const generateSimpleTypeTopic = 'generate_simple.type_topic';
  static const generateSimpleTypeQuestion = 'generate_simple.type_question';
  static const generateSimpleChooseDepth = 'generate_simple.choose_depth';
  static const generateSimpleAllDepths = 'generate_simple.all_depths';
  static const generateSimpleGenerate = 'generate_simple.generate';

  /// "Using {n} credits" under the Generate button.
  static const generateSimpleUsingCredits = 'generate_simple.using_credits';
  static const generateSimpleVerseOfDay = 'generate_simple.verse_of_day';

  // New first run: language and goal screens.
  static const firstRunWelcomeEyebrow = 'first_run.welcome_eyebrow';
  static const firstRunWelcomeTitle = 'first_run.welcome_title';
  static const firstRunWelcomeSubtitle = 'first_run.welcome_subtitle';

  /// Under English on the language screen: the English Bible version.
  static const firstRunEnglishBible = 'first_run.english_bible';
  static const firstRunContinue = 'first_run.continue';
  static const firstRunLogIn = 'first_run.log_in';
  static const firstRunHaveAccount = 'first_run.have_account';
  static const firstRunGoalTitle = 'first_run.goal_title';
  static const firstRunSkip = 'first_run.skip';
  static const firstRunStartLessonOne = 'first_run.start_lesson_one';
  static const firstRunTerms = 'first_run.terms';

  /// "{title} · {n} lessons" under a goal.
  static const firstRunPathMeta = 'first_run.path_meta';

  /// Helper under the goal title for a signed-in person.
  static const firstRunPickOne = 'first_run.pick_one';

  /// Helper for a guest: "…unlock all {n} paths".
  static const firstRunPickOneGuest = 'first_run.pick_one_guest';

  /// Guest helper without a number, when the path count is unknown.
  static const firstRunPickOneGuestPlain = 'first_run.pick_one_guest_plain';
  static const firstRunError = 'first_run.error';
  static const firstRunErrorHasPath = 'first_run.error_has_path';
  static const firstRunRetry = 'first_run.retry';
  static const firstRunGoHome = 'first_run.go_home';
  static const firstRunBack = 'first_run.back';

  /// "Step {n} of {total}" for the progress dashes.
  static const firstRunStep = 'first_run.step';

  // Growth goals on the first-run goal screen.
  static const goalNewToFaith = 'goal.new_to_faith';
  static const goalFreshStart = 'goal.fresh_start';
  static const goalWalkWithGod = 'goal.walk_with_god';
  static const goalHopeHardTimes = 'goal.hope_hard_times';
  static const goalReadGospel = 'goal.read_gospel';
  static const goalUnderstandGospel = 'goal.understand_gospel';

  // Guest "account needed" sheet and sign-up nudges.
  static const accountSaveProgressTitle = 'account.save_progress_title';
  static const accountPathFinishedTitle = 'account.path_finished_title';
  static const accountContinueGoogle = 'account.continue_google';
  static const accountContinueApple = 'account.continue_apple';
  static const accountContinueEmail = 'account.continue_email';
  static const accountNotNow = 'account.not_now';
  static const accountContinueGuest = 'account.continue_guest';
  static const accountGroupsTitle = 'account.groups_title';
  static const accountDisciplerTitle = 'account.discipler_title';
  static const accountSecondPathTitle = 'account.second_path_title';
  static const accountGenerateTitle = 'account.generate_title';
  static const accountMemoryVersesTitle = 'account.memory_verses_title';
  static const accountGenericTitle = 'account.generic_title';
  static const accountBody = 'account.body';
  static const accountBenefitMoves = 'account.benefit_moves';
  static const accountBenefitPaths = 'account.benefit_paths';
  static const accountBenefitGroups = 'account.benefit_groups';
  static const accountCheckEmail = 'account.check_email';
  static const accountKeepDaysSafe = 'account.keep_days_safe';
  static const accountKeepCta = 'account.keep_cta';
  static const accountNextPaths = 'account.next_paths';
  static const accountSignUpToStart = 'account.sign_up_to_start';
  static const accountLessonsCount = 'account.lessons_count';
  static const accountMergePending = 'account.merge_pending';
  static const accountLinkFailed = 'account.link_failed';
  static const accountDismiss = 'account.dismiss';
}
