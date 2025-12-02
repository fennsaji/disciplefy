/// Translation key constants for type-safe translation access
class TranslationKeys {
  // Study Guide Section Titles
  static const studyGuideSummary = 'study_guide.sections.summary';
  static const studyGuideInterpretation = 'study_guide.sections.interpretation';
  static const studyGuideContext = 'study_guide.sections.context';
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
  static const commonCancel = 'common.actions.cancel';
  static const commonShare = 'common.actions.share';
  static const commonCopy = 'common.actions.copy';
  static const commonSave = 'common.actions.save';
  static const commonDelete = 'common.actions.delete';
  static const commonEdit = 'common.actions.edit';

  // Common Messages
  static const commonError = 'common.messages.error';
  static const commonSuccess = 'common.messages.success';

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
  static const followUpChatListening = 'follow_up_chat.listening';
  static const followUpChatStop = 'follow_up_chat.stop';
  static const followUpChatStopListening = 'follow_up_chat.stop_listening';
  static const followUpChatTapToSpeak = 'follow_up_chat.tap_to_speak';
  static const followUpChatSpeechNotAvailable =
      'follow_up_chat.speech_not_available';

  // Home Screen
  static const homeWelcomeBack = 'home.welcome_back';
  static const homeContinueJourney = 'home.continue_journey';
  static const homeMemoryVerses = 'home.memory_verses';
  static const homeGenerateStudyGuide = 'home.generate_study_guide';
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
  static const generateStudyInProgress = 'generate_study.in_progress';
  static const generateStudyGenerationFailed =
      'generate_study.generation_failed';
  static const generateStudyGenerationFailedMessage =
      'generate_study.generation_failed_message';
  static const generateStudyManageTokens = 'generate_study.manage_tokens';

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
  static const loginContinueAsGuest = 'login.continue_as_guest';
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
  static const loginPrivacyPolicy = 'login.privacy_policy';

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

  // Settings Screen
  static const settingsTitle = 'settings.title';
  static const settingsAccount = 'settings.account';
  static const settingsSignInToSync = 'settings.sign_in_to_sync';
  static const settingsSignIn = 'settings.sign_in';
  static const settingsAppearance = 'settings.appearance';
  static const settingsNotifications = 'settings.notifications';
  static const settingsNotificationPreferences =
      'settings.notification_preferences';
  static const settingsNotificationSubtitle = 'settings.notification_subtitle';
  static const settingsTheme = 'settings.theme';
  static const settingsContentLanguage = 'settings.content_language';
  static const settingsAccountActions = 'settings.account_actions';
  static const settingsSignOut = 'settings.sign_out';
  static const settingsClearGuestSession = 'settings.clear_guest_session';
  static const settingsSignOutOfAccount = 'settings.sign_out_of_account';
  static const settingsAbout = 'settings.about';
  static const settingsAppVersion = 'settings.app_version';
  static const settingsSupportDeveloper = 'settings.support_developer';
  static const settingsSupportDeveloperSubtitle =
      'settings.support_developer_subtitle';
  static const settingsPrivacyPolicy = 'settings.privacy_policy';
  static const settingsPrivacyPolicySubtitle =
      'settings.privacy_policy_subtitle';
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
  static const settingsClearSession = 'settings.clear_session';
  static const settingsClearSessionMessage = 'settings.clear_session_message';
  static const settingsSignOutTitle = 'settings.sign_out_title';
  static const settingsSignOutMessage = 'settings.sign_out_message';
  static const settingsClear = 'settings.clear';
  static const settingsSupportTitle = 'settings.support_title';
  static const settingsSupportMessage = 'settings.support_message';
  static const settingsClose = 'settings.close';
  static const settingsSupport = 'settings.support';
  static const settingsNoEmail = 'settings.no_email';

  // Settings - Personalization
  static const settingsPersonalization = 'settings.personalization';
  static const settingsRetakeQuestionnaire = 'settings.retake_questionnaire';
  static const settingsRetakeQuestionnaireSubtitle =
      'settings.retake_questionnaire_subtitle';
  static const settingsTakeQuestionnaire = 'settings.take_questionnaire';
  static const settingsTakeQuestionnaireSubtitle =
      'settings.take_questionnaire_subtitle';

  // Personalization Questionnaire
  static const questionnaireYourJourney = 'questionnaire.your_journey';
  static const questionnaireWhatYouSeek = 'questionnaire.what_you_seek';
  static const questionnaireYourTime = 'questionnaire.your_time';
  static const questionnairePersonalize = 'questionnaire.personalize';
  static const questionnaireSkip = 'questionnaire.skip';
  static const questionnaireContinue = 'questionnaire.continue';
  static const questionnaireBack = 'questionnaire.back';
  static const questionnaireDone = 'questionnaire.done';
  static const questionnaireSkipTitle = 'questionnaire.skip_title';
  static const questionnaireSkipMessage = 'questionnaire.skip_message';
  static const questionnaireCancel = 'questionnaire.cancel';

  // Question 1: Faith Journey
  static const questionnaireFaithTitle = 'questionnaire.faith.title';
  static const questionnaireFaithSubtitle = 'questionnaire.faith.subtitle';
  static const questionnaireFaithNew = 'questionnaire.faith.new';
  static const questionnaireFaithGrowing = 'questionnaire.faith.growing';
  static const questionnaireFaithMature = 'questionnaire.faith.mature';

  // Question 2: What You Seek
  static const questionnaireSeekingTitle = 'questionnaire.seeking.title';
  static const questionnaireSeekingSubtitle = 'questionnaire.seeking.subtitle';
  static const questionnaireSeekingPeace = 'questionnaire.seeking.peace';
  static const questionnaireSeekingGuidance = 'questionnaire.seeking.guidance';
  static const questionnaireSeekingKnowledge =
      'questionnaire.seeking.knowledge';
  static const questionnaireSeekingRelationships =
      'questionnaire.seeking.relationships';
  static const questionnaireSeekingChallenges =
      'questionnaire.seeking.challenges';

  // Question 3: Time Commitment
  static const questionnaireTimeTitle = 'questionnaire.time.title';
  static const questionnaireTimeSubtitle = 'questionnaire.time.subtitle';
  static const questionnaireTime5Min = 'questionnaire.time.5min';
  static const questionnaireTime15Min = 'questionnaire.time.15min';
  static const questionnaireTime30Min = 'questionnaire.time.30min';

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
  static const savedGuidesUnsaveSuccess = 'saved_guides.unsave_success';
  static const savedGuidesUnsaveError = 'saved_guides.unsave_error';

  // Feedback Screen
  static const feedbackSendFeedback = 'feedback.send_feedback';
  static const feedbackSubtitle = 'feedback.subtitle';
  static const feedbackIsHelpful = 'feedback.is_helpful';
  static const feedbackCategoryGeneral = 'feedback.category.general';
  static const feedbackCategoryContent = 'feedback.category.content';
  static const feedbackCategoryUsability = 'feedback.category.usability';
  static const feedbackCategoryTechnical = 'feedback.category.technical';
  static const feedbackCategorySuggestion = 'feedback.category.suggestion';
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
  static const premiumSecurePayment = 'premium.secure_payment';
  static const premiumSubscriptionCreated = 'premium.subscription_created';
  static const premiumSubscriptionActivated = 'premium.subscription_activated';
  static const premiumPaymentCompletedHint = 'premium.payment_completed_hint';
  static const premiumCheckStatus = 'premium.check_status';

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

  // Memory Verses
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

  // Options Menu
  static const optionsMenuSyncTitle = 'memory.optionsMenu.syncTitle';
  static const optionsMenuSyncSubtitle = 'memory.optionsMenu.syncSubtitle';
  static const optionsMenuStatsTitle = 'memory.optionsMenu.statsTitle';
  static const optionsMenuStatsSubtitle = 'memory.optionsMenu.statsSubtitle';

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
  static const learningPathsLoadingTopics = 'learning_paths.loading_topics';
  static const learningPathsPercentComplete = 'learning_paths.percent_complete';

  // Disciple Levels
  static const discipleLevelSeeker = 'disciple_level.seeker';
  static const discipleLevelBeliever = 'disciple_level.believer';
  static const discipleLevelDisciple = 'disciple_level.disciple';
  static const discipleLevelLeader = 'disciple_level.leader';

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

  // Study Guide Error Screen
  static const studyGuideErrorTitle = 'study_guide.error.title';
  static const studyGuideErrorTitleAlt = 'study_guide.error.title_alt';
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
}
