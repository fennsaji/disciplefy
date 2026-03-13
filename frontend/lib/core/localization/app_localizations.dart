import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('hi', ''), // Hindi
    Locale('ml', ''), // Malayalam
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Common
      'app_title': 'Disciplefy | Bible Study App',
      'continue_button': 'Continue',
      'back_button': 'Back',
      'next_button': 'Next',
      'cancel_button': 'Cancel',
      'retry_button': 'Retry',
      'loading': 'Loading...',
      'error_title': 'Something went wrong',
      'error_message': 'Please try again or contact support.',

      // Onboarding
      'onboarding_welcome_title': 'Welcome to Disciplefy',
      'onboarding_welcome_subtitle':
          'AI-powered Bible study guides following  methodology',
      'onboarding_language_title': 'Choose Your Language',
      'onboarding_language_subtitle':
          'Select your preferred language for the app',
      'onboarding_purpose_title': 'Transform Your Bible Study',
      'onboarding_purpose_subtitle':
          'Generate personalized study guides for any verse or topic',
      'language_english': 'English',
      'language_hindi': 'हिन्दी',
      'language_malayalam': 'മലയാളം',

      // Study Input
      'study_input_title': 'Generate Study Guide',
      'study_input_verse_tab': 'Bible Verse',
      'study_input_topic_tab': 'Topic',
      'study_input_verse_hint': 'Enter Bible reference (e.g., John 3:16)',
      'study_input_topic_hint': 'Enter study topic (e.g., faith, love)',
      'study_input_generate_button': 'Generate Study Guide',
      'study_input_verse_validation': 'Please enter a valid Bible reference',
      'study_input_topic_validation': 'Please enter a topic (2-100 characters)',
      'study_input_generating': 'Generating your study guide...',

      // Study Result
      'study_result_title': 'Study Guide',
      'study_result_new_button': 'Generate New Guide',
      'study_result_share_button': 'Share',

      // Error Page
      'error_page_title': 'Oops!',
      'error_page_network': 'Please check your internet connection',
      'error_page_server': 'Server error occurred',
      'error_page_unknown': 'An unexpected error occurred',

      // Loading Screen Stages
      'loading_stage_preparing': 'Preparing your study guide...',
      'loading_stage_analyzing': 'Analyzing scripture context...',
      'loading_stage_gathering': 'Gathering insights...',
      'loading_stage_crafting': 'Crafting reflections...',
      'loading_stage_finalizing': 'Finalizing your guide...',

      // Loading Screen Time Estimate
      'loading_time_estimate': 'This usually takes 20-30 seconds',

      // Gamification - My Progress Page
      'progress_title': 'My Progress',
      'progress_xp_total': 'XP total',
      'progress_xp_to_next_level': 'XP to next level',
      'progress_max_level': 'Max Level Reached!',
      'progress_streaks': 'Streaks',
      'progress_study_streak': 'Study',
      'progress_verse_streak': 'Verse',
      'progress_days': 'days',
      'progress_personal_best': 'Personal Best',
      'progress_statistics': 'Statistics',
      'progress_studies': 'Studies',
      'progress_time_spent': 'Time Spent',
      'progress_memory_verses': 'Memory Verses',
      'progress_voice_sessions': 'Voice Sessions',
      'progress_saved_guides': 'Saved Guides',
      'progress_study_days': 'Study Days',
      'progress_achievements': 'Achievements',
      'progress_failed_load': 'Failed to load stats',
      'progress_try_again': 'Please try again later',
      'progress_retry': 'Retry',
      'progress_unlocked_on': 'Unlocked on',
      'progress_locked': 'Locked',
      'progress_view_leaderboard': 'View Leaderboard',
      'progress_unlocked': 'Unlocked',
      'progress_today': 'today',
      'progress_yesterday': 'yesterday',
      'progress_days_ago': 'days ago',
      'progress_achievement_unlocked': '🎉 Achievement Unlocked! 🎉',
      'progress_awesome': 'Awesome!',

      // Achievement Categories
      'achievement_category_study': 'Study Guides',
      'achievement_category_streak': 'Study Streaks',
      'achievement_category_memory': 'Memory Verses',
      'achievement_category_voice': 'Voice Discipler',
      'achievement_category_saved': 'Saved Guides',

      // First Century Christian Facts for Loading Screen (60 facts)
      'loading_fact_1':
          'Early Christians met in private homes, not church buildings.',
      'loading_fact_2':
          'The New Testament was originally written in Greek, not Hebrew.',
      'loading_fact_3':
          'By 100 AD, over 40 Christian communities existed across the Roman Empire.',
      'loading_fact_4':
          'First-century Christians were often from the urban poor and lower classes.',
      'loading_fact_5':
          'Christians greeted each other with a "holy kiss" as a sign of fellowship.',
      'loading_fact_6':
          'The earliest Christians continued to worship in Jewish synagogues.',
      'loading_fact_7':
          'Baptism was performed by full immersion in water, often in rivers.',
      'loading_fact_8':
          'Christians were called "atheists" by Romans for rejecting pagan gods.',
      'loading_fact_9':
          'The Lord\'s Supper was celebrated as an actual meal, not just bread and wine.',
      'loading_fact_10':
          'Women played significant roles as deacons, prophets, and house church leaders.',
      'loading_fact_11':
          'Early Christians practiced communal sharing of possessions and resources.',
      'loading_fact_12':
          'Persecution under Nero (64 AD) saw Christians burned alive as torches.',
      'loading_fact_13':
          'The fish symbol (Ichthys) was a secret Christian identification sign.',
      'loading_fact_14':
          'Most early Christians were literate and valued education highly.',
      'loading_fact_15':
          'Sunday worship began because it was the day of Jesus\' resurrection.',
      'loading_fact_16':
          'Early Christians cared for widows, orphans, and the sick systematically.',
      'loading_fact_17':
          'The apostle Paul wrote letters that became New Testament books.',
      'loading_fact_18':
          'Christians refused to participate in emperor worship, risking execution.',
      'loading_fact_19':
          'House churches could accommodate 30-50 people on average.',
      'loading_fact_20':
          'Early Christian worship included singing psalms and hymns.',
      'loading_fact_21':
          'The Jerusalem church was led by James, the brother of Jesus.',
      'loading_fact_22':
          'Christians were accused of cannibalism due to misunderstanding Communion.',
      'loading_fact_23':
          'Aramaic was Jesus\' spoken language, but Greek was used for spreading the Gospel.',
      'loading_fact_24':
          'Early Christians practiced fasting twice a week, on Wednesdays and Fridays.',
      'loading_fact_25':
          'The term "Christian" was first used in Antioch around 40-44 AD.',
      'loading_fact_26':
          'Believers memorized and recited Scripture since books were expensive.',
      'loading_fact_27':
          'Early Christians met before dawn to avoid persecution.',
      'loading_fact_28':
          'The apostles performed healings and miracles in Jesus\' name.',
      'loading_fact_29':
          'Christianity spread fastest in urban areas along trade routes.',
      'loading_fact_30':
          'Early Christians practiced footwashing as an act of humility.',
      'loading_fact_31':
          'Deacons were appointed to ensure fair distribution of food to widows.',
      'loading_fact_32':
          'The earliest Christian creed dates to within 5 years of Jesus\' death.',
      'loading_fact_33':
          'Paul\'s missionary journeys covered over 10,000 miles on foot and by ship.',
      'loading_fact_34':
          'Early Christians refused to attend gladiator games and theater shows.',
      'loading_fact_35':
          'The Gospel spread to Ethiopia, India, and Armenia in the first century.',
      'loading_fact_36':
          'Christians used house churches until the 3rd century when buildings emerged.',
      'loading_fact_37':
          'Prayer was offered three times daily, continuing Jewish tradition.',
      'loading_fact_38':
          'Early Christians called each other "brothers" and "sisters" regardless of social status.',
      'loading_fact_39':
          'The book of Revelation was written during intense Roman persecution.',
      'loading_fact_40':
          'Converts underwent extensive teaching before baptism, lasting months.',
      'loading_fact_41':
          'Early Christians rejected abortion and infanticide, unlike Roman society.',
      'loading_fact_42':
          'Women couldn\'t testify in Roman courts, but Jesus appeared first to women.',
      'loading_fact_43':
          'The oldest surviving Christian building is from 233 AD in Syria.',
      'loading_fact_44':
          'Early believers called their gatherings "the breaking of bread."',
      'loading_fact_45':
          'Christians were forbidden from serving in the Roman military initially.',
      'loading_fact_46':
          'The apostles spoke in tongues at Pentecost, understood by all present.',
      'loading_fact_47':
          'Early Christian letters were copied and shared between churches.',
      'loading_fact_48':
          'Believers sold property to support traveling missionaries and teachers.',
      'loading_fact_49':
          'The earliest Gospel, Mark, was likely written around 65-70 AD.',
      'loading_fact_50':
          'Christians practiced anointing the sick with oil for healing.',
      'loading_fact_51':
          'Early believers faced loss of jobs, property, and Roman citizenship.',
      'loading_fact_52':
          'The church in Rome had both Jewish and Gentile believers by 50 AD.',
      'loading_fact_53':
          'Christians used caves and catacombs for secret worship during persecution.',
      'loading_fact_54':
          'Early believers avoided lawsuits, settling disputes within the church.',
      'loading_fact_55':
          'The apostle John was exiled to Patmos island for preaching Christ.',
      'loading_fact_56':
          'Christians practiced hospitality, hosting traveling believers without charge.',
      'loading_fact_57':
          'Early church leaders were typically elders, not professional clergy.',
      'loading_fact_58':
          'Believers were persecuted by both Romans and Jewish authorities.',
      'loading_fact_59':
          'The first century saw rapid church growth despite severe persecution.',
      'loading_fact_60':
          'Early Christians believed Jesus would return in their lifetime.',

      // Community Feature
      'communityTitle': 'Community',
      'communityJoinButton': 'Join',
      'communityJoinedSuccess': 'You joined the fellowship!',
      'communityJoinFailed': 'Failed to join fellowship. Please retry.',
      'communityLoadError': 'Could not load fellowships',
      'communityRetry': 'Try Again',
      'communityEmptyTitle': "You haven't joined\na fellowship yet",
      'communityEmptyDescription':
          'Join a fellowship to study the Bible together\nwith a community of believers.',
      'communityJoinFellowship': 'Join a Fellowship',
      'communityMyFellowships': 'My Fellowships',
      'communityDiscover': 'Explore Public Fellowships',
      'communityMembers': 'members',
      'communityGuideLabel': 'Guide',
      'joinFellowshipTitle': 'Join Fellowship',
      'joinFellowshipHeading': 'Enter your invite code',
      'joinFellowshipInstructions':
          'Ask your fellowship leader for an invite\ncode and enter it below.',
      'joinFellowshipCodeLabel': 'Invite Code',
      'joinFellowshipCodeHint': 'Enter your invite code',
      'joinFellowshipButton': 'Join Fellowship',
      'joinFellowshipHelper':
          'Invite codes are provided by fellowship mentors.',
      'fellowshipDefaultTitle': 'Fellowship',
      'fellowshipTabFeed': 'Feed',
      'fellowshipTabLessons': 'Lessons',
      'fellowshipTabMembers': 'Members',
      'feedNewPost': 'New Post',
      'feedLoadError': 'Something went wrong.',
      'feedRetry': 'Retry',
      'feedEmpty': 'No posts yet.\nBe the first to share!',
      'postTypePrayer': 'Prayer',
      'postTypePraise': 'Praise',
      'postTypeQuestion': 'Question',
      'postTypeGeneral': 'General',
      'postTypeStudyNote': 'Study Note',
      'postTypeSharedGuide': 'Shared Guide',
      'studyNoteLesson': 'Lesson',
      'sharedGuideCta': 'Study This Guide',
      'feedCreateTitle': 'New Post',
      'feedCreateTypeLabel': 'Post type',
      'feedCreateContentLabel': 'Share something with your fellowship',
      'feedCreateContentHint': "What's on your heart?",
      'feedCreatePost': 'Post',
      'lessonsComing': 'Lessons coming soon',
      'lessonsDescription': 'Your fellowship study guides will appear here.',
      'lessonsAssignPath': 'Assign Learning Path',
      'lessonsChangePath': 'Change Learning Path',
      'lessonsNoPathMentor':
          'No learning path assigned yet.\nTap below to assign one.',
      'lessonsNoPathMember': "Your mentor hasn't assigned a learning path yet.",
      'lessonsCurrentStudy': 'Current Study',
      'lessonsSelectPath': 'Select a Learning Path',
      'lessonsPickPathTitle': 'Pick a Learning Path for Your Fellowship',
      'searchPathsHint': 'Search learning paths...',
      'searchNoResults': 'No paths match your search',
      'lessonsGuide': 'Guide',
      'lessonsTitle': 'Lessons',
      'lessonsMemberProgress': 'Member Progress',
      'lessonsMembersCompleted': 'completed',
      'membersInvite': 'Invite',
      'membersEmpty': 'No members yet',
      'membersEmptyDescription': 'Invite someone to join your fellowship.',
      'membersLoadError': 'Failed to load members.',
      'membersRetry': 'Retry',
      'membersMuted': 'Muted',
      'membersInviteTitle': 'Invite to Fellowship',
      'membersInviteSubtitle':
          'Share this code with someone to invite them to your fellowship.',
      'membersInviteComingSoon':
          'Coming soon \u2014 invite links will appear here',
      'membersCopy': 'Copy',
      'leaveFellowshipTitle': 'Leave Fellowship',
      'leaveFellowshipConfirm':
          'Are you sure you want to leave this fellowship?',
      'cancel': 'Cancel',
      'muteSuccess': 'Member muted',
      'unmuteSuccess': 'Member unmuted',
      'inviteGenerating': 'Generating invite...',
      'inviteShareCode': 'Share this code',
      'inviteExpires': 'Expires in 7 days',
      'lessonsAdvanceGuide': 'Advance to Next Guide',
      'lessonsAdvanceConfirm':
          'Mark current guide complete and advance to the next?',
      'lessonsCompleted': 'Study Completed!',
      'lessonsGuideProgress': 'Guide',
      'lessonsOf': 'of',
      // Edit Fellowship
      'editFellowshipTitle': 'Edit Fellowship',
      'editFellowshipSave': 'Save Changes',
      'editFellowshipSuccess': 'Fellowship updated',
      // Invite list + revoke
      'inviteListEmpty': 'No active invite links',
      'inviteRevoke': 'Revoke',
      'inviteRevokeSuccess': 'Invite revoked',
      // Transfer mentor
      'transferMentorTitle': 'Transfer Mentor Role',
      'transferMentorConfirm':
          'Transfer the mentor role to this member? You will become a regular member.',
      'transferMentorSuccess': 'Mentor role transferred',
      'removeMemberTitle': 'Remove Member',
      'removeMemberConfirm':
          'Remove this member from the fellowship? They can rejoin with a new invite.',
      'removeMemberAction': 'Remove',
      'removeMemberSuccess': 'Member removed',
      'memberJoinedLabel': 'Joined',
      // Report
      'reportTitle': 'Report Content',
      'reportReasonLabel': 'Reason',
      'reportReasonHint': 'Why are you reporting this? (5–500 characters)',
      'reportSubmit': 'Submit Report',
      'reportSuccess': 'Report submitted. Thank you.',
      // Create Fellowship Screen
      'createFellowshipTitle': 'Create Fellowship',
      'createFellowshipHeading': 'Start a new fellowship',
      'createFellowshipSubtitle':
          'Give your group a name and invite others to study the Bible together.',
      'createFellowshipNameLabel': 'Fellowship Name',
      'createFellowshipNameHint': 'e.g. Morning Bible Warriors',
      'createFellowshipDescLabel': 'Description (optional)',
      'createFellowshipDescHint': 'What will your fellowship study together?',
      'createFellowshipMaxLabel': 'Max Members (2–50)',
      'createFellowshipButton': 'Create Fellowship',
      'createFellowshipSuccess': 'Fellowship created!',
      'createFellowshipFailed': 'Failed to create fellowship.',
      'createFellowshipNameError': 'Name must be 3–60 characters.',
      'createFellowshipDescError':
          'Description must be 500 characters or fewer.',
      'createFellowshipMaxError': 'Max members must be between 2 and 50.',
      // Discover tab
      'discoverFilterAll': 'All Languages',
      'discoverFilterEnglish': 'English',
      'discoverFilterHindi': 'Hindi',
      'discoverFilterMalayalam': 'Malayalam',
      'discoverEmpty': 'No public fellowships yet',
      'discoverEmptyShowAll': 'Show all languages',
      'discoverJoinButton': 'Join',
      'discoverFull': 'Full',
      'discoverJoinedSnackbar': 'You joined {name}!',
      'discoverMembersCount': '{count} / {max} members',
      'createFellowshipLanguageLabel': 'Language',
      'createFellowshipMakePublicLabel': 'Make Public',
      'createFellowshipMakePublicHint': 'Visible to all users in Discover',
      'meetingsSyncBannerTitle':
          "New members haven't received calendar invites",
      'meetingsSyncCalendar': 'Sync to Calendar',
      'meetingsSyncReconnect': 'Please reconnect Google Calendar',
      'homeAssignPathMentor': 'Assign a study path',
      'homeNoPathAssigned': 'No study path assigned',
      'fellowshipRecentActivity': 'Recent Activity',
      'fellowshipViewAll': 'View All',
      'feedPostSomething': 'Post something',
      'meetingsTitle': 'Meetings',
      'meetingsSchedule': 'Schedule',
      'meetingsSchedulePrompt': 'Tap + to schedule a meeting',
      'meetingsNoUpcoming': 'No upcoming meetings',
      'meetingsNextNoTime': 'Next: {0}',
      'meetingsNextWithTime': 'Next: {0} at {1}',
    },
    'hi': {
      // Common
      'app_title': 'डिसाइपलफाई बाइबल अध्ययन',
      'continue_button': 'जारी रखें',
      'back_button': 'वापस',
      'next_button': 'अगला',
      'cancel_button': 'रद्द करें',
      'retry_button': 'पुनः प्रयास',
      'loading': 'लोड हो रहा है...',
      'error_title': 'कुछ गलत हुआ',
      'error_message': 'कृपया पुनः प्रयास करें या सहायता से संपर्क करें।',

      // Onboarding
      'onboarding_welcome_title': 'डिसाइपलफाई में आपका स्वागत है',
      'onboarding_welcome_subtitle':
          'जेफ रीड पद्धति के अनुसार AI-संचालित बाइबल अध्ययन गाइड',
      'onboarding_language_title': 'अपनी भाषा चुनें',
      'onboarding_language_subtitle': 'ऐप के लिए अपनी पसंदीदा भाषा चुनें',
      'onboarding_purpose_title': 'अपने बाइबल अध्ययन को बदलें',
      'onboarding_purpose_subtitle':
          'किसी भी आयत या विषय के लिए व्यक्तिगत अध्ययन गाइड बनाएं',
      'language_english': 'English',
      'language_hindi': 'हिन्दी',
      'language_malayalam': 'മലയാളം',

      // Study Input
      'study_input_title': 'अध्ययन गाइड बनाएं',
      'study_input_verse_tab': 'बाइबल आयत',
      'study_input_topic_tab': 'विषय',
      'study_input_verse_hint': 'बाइबल संदर्भ दर्ज करें (जैसे, यूहन्ना 3:16)',
      'study_input_topic_hint': 'अध्ययन विषय दर्ज करें (जैसे, विश्वास, प्रेम)',
      'study_input_generate_button': 'अध्ययन गाइड बनाएं',
      'study_input_verse_validation': 'कृपया एक वैध बाइबल संदर्भ दर्ज करें',
      'study_input_topic_validation': 'कृपया एक विषय दर्ज करें (2-100 अक्षर)',
      'study_input_generating': 'आपका अध्ययन गाइड बनाया जा रहा है...',

      // Study Result
      'study_result_title': 'अध्ययन गाइड',
      'study_result_new_button': 'नया गाइड बनाएं',
      'study_result_share_button': 'साझा करें',

      // Error Page
      'error_page_title': 'ओह!',
      'error_page_network': 'कृपया अपना इंटरनेट कनेक्शन जांचें',
      'error_page_server': 'सर्वर त्रुटि हुई',
      'error_page_unknown': 'एक अप्रत्याशित त्रुटि हुई',

      // Loading Screen Stages
      'loading_stage_preparing': 'आपका अध्ययन गाइड तैयार किया जा रहा है...',
      'loading_stage_analyzing':
          'धर्मग्रंथ संदर्भ का विश्लेषण किया जा रहा है...',
      'loading_stage_gathering': 'अंतर्दृष्टि एकत्र की जा रही है...',
      'loading_stage_crafting': 'चिंतन तैयार किए जा रहे हैं...',
      'loading_stage_finalizing': 'आपका गाइड अंतिम रूप दिया जा रहा है...',

      // Loading Screen Time Estimate
      'loading_time_estimate': 'इसमें आमतौर पर 20-30 सेकंड लगते हैं',

      // Gamification - My Progress Page
      'progress_title': 'मेरी प्रगति',
      'progress_xp_total': 'कुल XP',
      'progress_xp_to_next_level': 'अगले स्तर तक XP',
      'progress_max_level': 'अधिकतम स्तर प्राप्त!',
      'progress_streaks': 'स्ट्रीक्स',
      'progress_study_streak': 'अध्ययन',
      'progress_verse_streak': 'वचन',
      'progress_days': 'दिन',
      'progress_personal_best': 'व्यक्तिगत सर्वश्रेष्ठ',
      'progress_statistics': 'आंकड़े',
      'progress_studies': 'अध्ययन',
      'progress_time_spent': 'समय बिताया',
      'progress_memory_verses': 'याद के पद',
      'progress_voice_sessions': 'वॉयस सत्र',
      'progress_saved_guides': 'सहेजी गई गाइड',
      'progress_study_days': 'अध्ययन दिवस',
      'progress_achievements': 'उपलब्धियाँ',
      'progress_failed_load': 'आंकड़े लोड करने में विफल',
      'progress_try_again': 'कृपया बाद में पुनः प्रयास करें',
      'progress_retry': 'पुनः प्रयास',
      'progress_unlocked_on': 'अनलॉक हुआ',
      'progress_locked': 'लॉक्ड',
      'progress_view_leaderboard': 'लीडरबोर्ड देखें',
      'progress_unlocked': 'अनलॉक हुआ',
      'progress_today': 'आज',
      'progress_yesterday': 'कल',
      'progress_days_ago': 'दिन पहले',
      'progress_achievement_unlocked': '🎉 उपलब्धि अनलॉक! 🎉',
      'progress_awesome': 'शानदार!',

      // Achievement Categories
      'achievement_category_study': 'अध्ययन गाइड',
      'achievement_category_streak': 'अध्ययन स्ट्रीक्स',
      'achievement_category_memory': 'स्मृति वचन',
      'achievement_category_voice': 'वॉइस डिसाइपलर',
      'achievement_category_saved': 'सहेजे गए गाइड',

      // First Century Christian Facts for Loading Screen (60 facts - Hindi)
      'loading_fact_1':
          'प्रारंभिक मसीही निजी घरों में मिलते थे, चर्च भवनों में नहीं।',
      'loading_fact_2':
          'नया नियम मूल रूप से यूनानी में लिखा गया था, इब्रानी में नहीं।',
      'loading_fact_3':
          '100 ईस्वी तक, रोमन साम्राज्य में 40 से अधिक मसीही समुदाय मौजूद थे।',
      'loading_fact_4':
          'पहली सदी के मसीही अक्सर शहरी गरीबों और निम्न वर्गों से थे।',
      'loading_fact_5':
          'मसीही एक-दूसरे को संगति के संकेत के रूप में "पवित्र चुंबन" से अभिवादन करते थे।',
      'loading_fact_6':
          'सबसे पहले के मसीही यहूदी आराधनालयों में आराधना करना जारी रखते थे।',
      'loading_fact_7':
          'बपतिस्मा पूर्ण डुबकी द्वारा पानी में किया जाता था, अक्सर नदियों में।',
      'loading_fact_8':
          'रोमनों ने मसीहियों को "नास्तिक" कहा क्योंकि वे मूर्तिपूजक देवताओं को अस्वीकार करते थे।',
      'loading_fact_9':
          'प्रभु भोज एक वास्तविक भोजन के रूप में मनाया जाता था, न कि केवल रोटी और दाखरस।',
      'loading_fact_10':
          'महिलाओं ने डीकन, भविष्यवक्ता और घर-कलीसिया नेताओं के रूप में महत्वपूर्ण भूमिका निभाई।',
      'loading_fact_11':
          'प्रारंभिक मसीहियों ने संपत्ति और संसाधनों की सांप्रदायिक साझेदारी का अभ्यास किया।',
      'loading_fact_12':
          'नीरो के अधीन उत्पीड़न (64 ईस्वी) में मसीहियों को मशालों की तरह जिंदा जलाया गया।',
      'loading_fact_13':
          'मछली का प्रतीक (इक्थिस) एक गुप्त मसीही पहचान चिह्न था।',
      'loading_fact_14':
          'अधिकांश प्रारंभिक मसीही साक्षर थे और शिक्षा को अत्यधिक महत्व देते थे।',
      'loading_fact_15':
          'रविवार की आराधना शुरू हुई क्योंकि यह यीशु के पुनरुत्थान का दिन था।',
      'loading_fact_16':
          'प्रारंभिक मसीहियों ने विधवाओं, अनाथों और बीमारों की व्यवस्थित देखभाल की।',
      'loading_fact_17':
          'प्रेरित पौलुस ने पत्र लिखे जो नए नियम की पुस्तकें बन गईं।',
      'loading_fact_18':
          'मसीहियों ने सम्राट पूजा में भाग लेने से इनकार किया, मृत्युदंड का जोखिम उठाते हुए।',
      'loading_fact_19':
          'घर-कलीसियाएं औसतन 30-50 लोगों को समायोजित कर सकती थीं।',
      'loading_fact_20':
          'प्रारंभिक मसीही आराधना में भजन और स्तुति गीत गाना शामिल था।',
      'loading_fact_21':
          'यरूशलेम की कलीसिया का नेतृत्व याकूब, यीशु के भाई ने किया।',
      'loading_fact_22':
          'मसीहियों पर सहभोजन को गलत समझने के कारण नरभक्षण का आरोप लगाया गया।',
      'loading_fact_23':
          'अरामी यीशु की बोली जाने वाली भाषा थी, लेकिन सुसमाचार फैलाने के लिए यूनानी का उपयोग किया गया।',
      'loading_fact_24':
          'प्रारंभिक मसीहियों ने सप्ताह में दो बार, बुधवार और शुक्रवार को उपवास किया।',
      'loading_fact_25':
          '"मसीही" शब्द का पहली बार उपयोग अंताकिया में लगभग 40-44 ईस्वी में हुआ था।',
      'loading_fact_26':
          'विश्वासियों ने पवित्रशास्त्र को याद किया और पाठ किया क्योंकि पुस्तकें महंगी थीं।',
      'loading_fact_27':
          'प्रारंभिक मसीही उत्पीड़न से बचने के लिए भोर से पहले मिलते थे।',
      'loading_fact_28': 'प्रेरितों ने यीशु के नाम में चंगाई और चमत्कार किए।',
      'loading_fact_29':
          'मसीहियत व्यापार मार्गों के साथ शहरी क्षेत्रों में सबसे तेजी से फैली।',
      'loading_fact_30':
          'प्रारंभिक मसीहियों ने विनम्रता के कार्य के रूप में पैर धोना अभ्यास किया।',
      'loading_fact_31':
          'विधवाओं को भोजन के उचित वितरण को सुनिश्चित करने के लिए डीकन नियुक्त किए गए।',
      'loading_fact_32':
          'सबसे पहला मसीही पंथ यीशु की मृत्यु के 5 वर्षों के भीतर का है।',
      'loading_fact_33':
          'पौलुस की मिशनरी यात्राओं ने पैदल और जहाज से 10,000 मील से अधिक की दूरी तय की।',
      'loading_fact_34':
          'प्रारंभिक मसीहियों ने ग्लैडिएटर खेलों और रंगमंच शो में भाग लेने से इनकार किया।',
      'loading_fact_35':
          'पहली सदी में सुसमाचार इथियोपिया, भारत और आर्मेनिया में फैल गया।',
      'loading_fact_36':
          'मसीहियों ने तीसरी शताब्दी तक घर-कलीसियाओं का उपयोग किया जब भवन उभरे।',
      'loading_fact_37':
          'यहूदी परंपरा को जारी रखते हुए, दिन में तीन बार प्रार्थना की जाती थी।',
      'loading_fact_38':
          'प्रारंभिक मसीही सामाजिक स्थिति की परवाह किए बिना एक-दूसरे को "भाई" और "बहन" कहते थे।',
      'loading_fact_39':
          'प्रकाशितवाक्य की पुस्तक तीव्र रोमन उत्पीड़न के दौरान लिखी गई थी।',
      'loading_fact_40':
          'धर्मान्तरित लोगों को बपतिस्मा से पहले महीनों तक व्यापक शिक्षा दी जाती थी।',
      'loading_fact_41':
          'प्रारंभिक मसीहियों ने गर्भपात और शिशुहत्या को अस्वीकार किया, रोमन समाज के विपरीत।',
      'loading_fact_42':
          'महिलाएं रोमन अदालतों में गवाही नहीं दे सकती थीं, लेकिन यीशु पहले महिलाओं के सामने प्रकट हुए।',
      'loading_fact_43':
          'सबसे पुरानी जीवित मसीही इमारत सीरिया में 233 ईस्वी की है।',
      'loading_fact_44':
          'प्रारंभिक विश्वासियों ने अपनी सभाओं को "रोटी तोड़ना" कहा।',
      'loading_fact_45':
          'मसीहियों को शुरू में रोमन सेना में सेवा करने से मना किया गया था।',
      'loading_fact_46':
          'प्रेरितों ने पेंतेकुस्त पर अन्य भाषाओं में बात की, जो सभी उपस्थित लोगों द्वारा समझी गई।',
      'loading_fact_47':
          'प्रारंभिक मसीही पत्रों को कलीसियाओं के बीच नकल और साझा किया गया।',
      'loading_fact_48':
          'विश्वासियों ने यात्रा करने वाले मिशनरियों और शिक्षकों का समर्थन करने के लिए संपत्ति बेची।',
      'loading_fact_49':
          'सबसे पहला सुसमाचार, मरकुस, संभवतः 65-70 ईस्वी के आसपास लिखा गया था।',
      'loading_fact_50':
          'मसीहियों ने चंगाई के लिए बीमारों का तेल से अभिषेक किया।',
      'loading_fact_51':
          'प्रारंभिक विश्वासियों को नौकरी, संपत्ति और रोमन नागरिकता के नुकसान का सामना करना पड़ा।',
      'loading_fact_52':
          'रोम में कलीसिया में 50 ईस्वी तक यहूदी और गैर-यहूदी दोनों विश्वासी थे।',
      'loading_fact_53':
          'मसीहियों ने उत्पीड़न के दौरान गुप्त आराधना के लिए गुफाओं और कटाकॉम्ब का उपयोग किया।',
      'loading_fact_54':
          'प्रारंभिक विश्वासियों ने मुकदमों से परहेज किया, कलीसिया के भीतर विवादों को निपटाते हुए।',
      'loading_fact_55':
          'प्रेरित यूहन्ना को मसीह का प्रचार करने के लिए पत्मोस द्वीप में निर्वासित किया गया था।',
      'loading_fact_56':
          'मसीहियों ने आतिथ्य का अभ्यास किया, यात्रा करने वाले विश्वासियों को बिना शुल्क आश्रय दिया।',
      'loading_fact_57':
          'प्रारंभिक कलीसिया नेता आमतौर पर बुजुर्ग थे, पेशेवर पादरी नहीं।',
      'loading_fact_58':
          'विश्वासियों को रोमनों और यहूदी अधिकारियों दोनों द्वारा उत्पीड़ित किया गया।',
      'loading_fact_59':
          'पहली शताब्दी में गंभीर उत्पीड़न के बावजूद तेजी से कलीसिया वृद्धि हुई।',
      'loading_fact_60':
          'प्रारंभिक मसीहियों का मानना था कि यीशु उनके जीवनकाल में लौटेंगे।',

      // Community Feature
      'communityTitle': 'समुदाय',
      'communityJoinButton': 'शामिल हों',
      'communityJoinedSuccess': 'आप संगति में शामिल हो गए!',
      'communityJoinFailed':
          'संगति में शामिल होना विफल। कृपया पुनः प्रयास करें।',
      'communityLoadError': 'संगतियां लोड नहीं हो सकीं',
      'communityRetry': 'पुनः प्रयास करें',
      'communityEmptyTitle': 'आप अभी तक किसी संगति में शामिल नहीं हुए',
      'communityEmptyDescription':
          'विश्वासियों के समुदाय के साथ बाइबल का अध्ययन करने के लिए एक संगति में शामिल हों।',
      'communityJoinFellowship': 'एक संगति में शामिल हों',
      'communityMyFellowships': 'मेरी संगतियाँ',
      'communityDiscover': 'सार्वजनिक संगतियाँ खोजें',
      'communityMembers': 'सदस्य',
      'communityGuideLabel': 'पाठ',
      'joinFellowshipTitle': 'संगति में शामिल हों',
      'joinFellowshipHeading': 'अपना आमंत्रण कोड दर्ज करें',
      'joinFellowshipInstructions':
          'अपने संगति नेता से आमंत्रण कोड मांगें और नीचे दर्ज करें।',
      'joinFellowshipCodeLabel': 'आमंत्रण कोड',
      'joinFellowshipCodeHint': 'आमंत्रण कोड दर्ज करें',
      'joinFellowshipButton': 'संगति में शामिल हों',
      'joinFellowshipHelper':
          'आमंत्रण कोड संगति मार्गदर्शकों द्वारा दिए जाते हैं।',
      'fellowshipDefaultTitle': 'संगति',
      'fellowshipTabFeed': 'फ़ीड',
      'fellowshipTabLessons': 'पाठ',
      'fellowshipTabMembers': 'सदस्य',
      'feedNewPost': 'नई पोस्ट',
      'feedLoadError': 'कुछ गलत हो गया।',
      'feedRetry': 'पुनः प्रयास',
      'feedEmpty': 'अभी कोई पोस्ट नहीं।\nपहले साझा करें!',
      'postTypePrayer': 'प्रार्थना',
      'postTypePraise': 'स्तुति',
      'postTypeQuestion': 'प्रश्न',
      'postTypeGeneral': 'सामान्य',
      'postTypeStudyNote': 'अध्ययन नोट',
      'postTypeSharedGuide': 'साझा गाइड',
      'studyNoteLesson': 'पाठ',
      'sharedGuideCta': 'इस गाइड का अध्ययन करें',
      'feedCreateTitle': 'नई पोस्ट',
      'feedCreateTypeLabel': 'पोस्ट प्रकार',
      'feedCreateContentLabel': 'अपनी संगति के साथ कुछ साझा करें',
      'feedCreateContentHint': 'आपके मन में क्या है?',
      'feedCreatePost': 'पोस्ट करें',
      'lessonsComing': 'पाठ जल्द आ रहे हैं',
      'lessonsDescription':
          'आपकी संगति के अध्ययन मार्गदर्शिकाएं यहाँ दिखाई देंगी।',
      'lessonsAssignPath': 'लर्निंग पथ असाइन करें',
      'lessonsChangePath': 'लर्निंग पथ बदलें',
      'lessonsNoPathMentor':
          'अभी कोई लर्निंग पथ असाइन नहीं है।\nएक असाइन करने के लिए नीचे टैप करें।',
      'lessonsNoPathMember':
          'आपके मार्गदर्शक ने अभी कोई लर्निंग पथ असाइन नहीं किया है।',
      'lessonsCurrentStudy': 'वर्तमान अध्ययन',
      'lessonsSelectPath': 'एक लर्निंग पथ चुनें',
      'lessonsPickPathTitle': 'अपनी संगति के लिए एक लर्निंग पथ चुनें',
      'searchPathsHint': 'लर्निंग पथ खोजें...',
      'searchNoResults': 'कोई पथ मेल नहीं खाता',
      'lessonsGuide': 'मार्गदर्शिका',
      'lessonsTitle': 'पाठ',
      'lessonsMemberProgress': 'सदस्य प्रगति',
      'lessonsMembersCompleted': 'पूर्ण',
      'membersInvite': 'आमंत्रित करें',
      'membersEmpty': 'अभी कोई सदस्य नहीं',
      'membersEmptyDescription':
          'किसी को अपनी संगति में शामिल होने के लिए आमंत्रित करें।',
      'membersLoadError': 'सदस्यों को लोड करना विफल।',
      'membersRetry': 'पुनः प्रयास',
      'membersMuted': 'म्यूट',
      'membersInviteTitle': 'संगति में आमंत्रित करें',
      'membersInviteSubtitle':
          'किसी को अपनी संगति में आमंत्रित करने के लिए यह कोड साझा करें।',
      'membersInviteComingSoon':
          'जल्द आ रहा है — आमंत्रण लिंक यहाँ दिखाई देंगे',
      'membersCopy': 'कॉपी करें',
      'leaveFellowshipTitle': 'संगति छोड़ें',
      'leaveFellowshipConfirm': 'क्या आप वाकई इस संगति को छोड़ना चाहते हैं?',
      'cancel': 'रद्द करें',
      'muteSuccess': 'सदस्य म्यूट किया गया',
      'unmuteSuccess': 'सदस्य अनम्यूट किया गया',
      'inviteGenerating': 'आमंत्रण बना रहे हैं...',
      'inviteShareCode': 'यह कोड साझा करें',
      'inviteExpires': '7 दिनों में समाप्त',
      'lessonsAdvanceGuide': 'अगले गाइड पर जाएं',
      'lessonsAdvanceConfirm': 'वर्तमान गाइड पूर्ण करें और अगले पर जाएं?',
      'lessonsCompleted': 'अध्ययन पूर्ण!',
      'lessonsGuideProgress': 'गाइड',
      'lessonsOf': 'का',
      // Edit Fellowship
      'editFellowshipTitle': 'संगति संपादित करें',
      'editFellowshipSave': 'परिवर्तन सहेजें',
      'editFellowshipSuccess': 'संगति अपडेट हुई',
      // Invite list + revoke
      'inviteListEmpty': 'कोई सक्रिय आमंत्रण लिंक नहीं',
      'inviteRevoke': 'रद्द करें',
      'inviteRevokeSuccess': 'आमंत्रण रद्द किया गया',
      // Transfer mentor
      'transferMentorTitle': 'मार्गदर्शक भूमिका स्थानांतरित करें',
      'transferMentorConfirm':
          'इस सदस्य को मार्गदर्शक भूमिका दें? आप एक सामान्य सदस्य बन जाएंगे।',
      'transferMentorSuccess': 'मार्गदर्शक भूमिका स्थानांतरित की गई',
      'removeMemberTitle': 'सदस्य हटाएं',
      'removeMemberConfirm':
          'इस सदस्य को संगति से हटाएं? वे नए आमंत्रण से पुनः शामिल हो सकते हैं।',
      'removeMemberAction': 'हटाएं',
      'removeMemberSuccess': 'सदस्य हटाया गया',
      'memberJoinedLabel': 'शामिल हुए',
      // Report
      'reportTitle': 'सामग्री की रिपोर्ट करें',
      'reportReasonLabel': 'कारण',
      'reportReasonHint': 'आप इसे क्यों रिपोर्ट कर रहे हैं? (5–500 अक्षर)',
      'reportSubmit': 'रिपोर्ट सबमिट करें',
      'reportSuccess': 'रिपोर्ट सबमिट हुई। धन्यवाद।',
      // Create Fellowship Screen
      'createFellowshipTitle': 'संगति बनाएं',
      'createFellowshipHeading': 'एक नई संगति शुरू करें',
      'createFellowshipSubtitle':
          'अपने समूह को एक नाम दें और दूसरों को बाइबल का अध्ययन करने के लिए आमंत्रित करें।',
      'createFellowshipNameLabel': 'संगति का नाम',
      'createFellowshipNameHint': 'जैसे. सुबह के बाइबिल योद्धा',
      'createFellowshipDescLabel': 'विवरण (वैकल्पिक)',
      'createFellowshipDescHint': 'आपकी संगति मिलकर क्या अध्ययन करेगी?',
      'createFellowshipMaxLabel': 'अधिकतम सदस्य (2–50)',
      'createFellowshipButton': 'संगति बनाएं',
      'createFellowshipSuccess': 'संगति बन गई!',
      'createFellowshipFailed': 'संगति बनाना विफल।',
      'createFellowshipNameError': 'नाम 3–60 अक्षरों का होना चाहिए।',
      'createFellowshipDescError': 'विवरण अधिकतम 500 अक्षर।',
      'createFellowshipMaxError': 'अधिकतम सदस्य 2 से 50 के बीच होने चाहिए।',
      // Discover tab
      'discoverFilterAll': 'सभी भाषाएं',
      'discoverFilterEnglish': 'अंग्रेज़ी',
      'discoverFilterHindi': 'हिन्दी',
      'discoverFilterMalayalam': 'मलयालम',
      'discoverEmpty': 'अभी कोई सार्वजनिक संगति नहीं',
      'discoverEmptyShowAll': 'सभी भाषाएं दिखाएं',
      'discoverJoinButton': 'शामिल हों',
      'discoverFull': 'पूर्ण',
      'discoverJoinedSnackbar': 'आप {name} में शामिल हो गए!',
      'discoverMembersCount': '{count} / {max} सदस्य',
      'createFellowshipLanguageLabel': 'भाषा',
      'createFellowshipMakePublicLabel': 'सार्वजनिक करें',
      'createFellowshipMakePublicHint':
          'Discover में सभी उपयोगकर्ताओं को दिखाई देगा',
      'meetingsSyncBannerTitle': 'नए सदस्यों को कैलेंडर इनवाइट नहीं मिले',
      'meetingsSyncCalendar': 'कैलेंडर से सिंक करें',
      'meetingsSyncReconnect': 'कृपया Google Calendar फिर से कनेक्ट करें',
      'homeAssignPathMentor': 'अध्ययन पथ असाइन करें',
      'homeNoPathAssigned': 'कोई अध्ययन पथ नहीं',
      'fellowshipRecentActivity': 'हाल की गतिविधि',
      'fellowshipViewAll': 'सभी देखें',
      'feedPostSomething': 'कुछ पोस्ट करें',
      'meetingsTitle': 'मीटिंग',
      'meetingsSchedule': 'शेड्यूल करें',
      'meetingsSchedulePrompt': 'मीटिंग शेड्यूल करने के लिए + दबाएं',
      'meetingsNoUpcoming': 'कोई आगामी मीटिंग नहीं',
      'meetingsNextNoTime': 'अगला: {0}',
      'meetingsNextWithTime': 'अगला: {0} at {1}',
    },
    'ml': {
      // Common
      'app_title': 'ഡിസൈപ്പിൾഫൈ ബൈബിൾ പഠനം',
      'continue_button': 'തുടരുക',
      'back_button': 'തിരികെ',
      'next_button': 'അടുത്തത്',
      'cancel_button': 'റദ്ദാക്കുക',
      'retry_button': 'വീണ്ടും ശ്രമിക്കുക',
      'loading': 'ലോഡ് ചെയ്യുന്നു...',
      'error_title': 'എന്തോ തെറ്റ് സംഭവിച്ചു',
      'error_message':
          'ദയവായി വീണ്ടും ശ്രമിക്കുക അല്ലെങ്കിൽ പിന്തുണയുമായി ബന്ധപ്പെടുക.',

      // Onboarding
      'onboarding_welcome_title': 'ഡിസൈപ്പിൾഫൈയിലേക്ക് സ്വാഗതം',
      'onboarding_welcome_subtitle':
          'ജെഫ് റീഡ് രീതി പിന്തുടർന്ന് AI-നയിക്കുന്ന ബൈബിൾ പഠന ഗൈഡുകൾ',
      'onboarding_language_title': 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക',
      'onboarding_language_subtitle':
          'ആപ്പിനായി നിങ്ങളുടെ പ്രിയപ്പെട്ട ഭാഷ തിരഞ്ഞെടുക്കുക',
      'onboarding_purpose_title': 'നിങ്ങളുടെ ബൈബിൾ പഠനം പരിവർത്തനം ചെയ്യുക',
      'onboarding_purpose_subtitle':
          'ഏതൊരു വാക്യത്തിനും അല്ലെങ്കിൽ വിഷയത്തിനും വ്യക്തിഗത പഠന ഗൈഡുകൾ സൃഷ്ടിക്കുക',
      'language_english': 'English',
      'language_hindi': 'हिन्दी',
      'language_malayalam': 'മലയാളം',

      // Study Input
      'study_input_title': 'പഠന ഗൈഡ് സൃഷ്ടിക്കുക',
      'study_input_verse_tab': 'ബൈബിൾ വാക്യം',
      'study_input_topic_tab': 'വിഷയം',
      'study_input_verse_hint': 'ബൈബിൾ റഫറൻസ് നൽകുക (ഉദാ., യോഹന്നാൻ 3:16)',
      'study_input_topic_hint': 'പഠന വിഷയം നൽകുക (ഉദാ., വിശ്വാസം, സ്നേഹം)',
      'study_input_generate_button': 'പഠന ഗൈഡ് സൃഷ്ടിക്കുക',
      'study_input_verse_validation': 'ദയവായി സാധുവായ ബൈബിൾ റഫറൻസ് നൽകുക',
      'study_input_topic_validation':
          'ദയവായി ഒരു വിഷയം നൽകുക (2-100 അക്ഷരങ്ങൾ)',
      'study_input_generating': 'നിങ്ങളുടെ പഠന ഗൈഡ് സൃഷ്ടിക്കുന്നു...',

      // Study Result
      'study_result_title': 'പഠന ഗൈഡ്',
      'study_result_new_button': 'പുതിയ ഗൈഡ് സൃഷ്ടിക്കുക',
      'study_result_share_button': 'പങ്കിടുക',

      // Error Page
      'error_page_title': 'ഓ!',
      'error_page_network': 'ദയവായി നിങ്ങളുടെ ഇന്റർനെറ്റ് കണക്ഷൻ പരിശോധിക്കുക',
      'error_page_server': 'സെർവർ പിശക് സംഭവിച്ചു',
      'error_page_unknown': 'അപ്രതീക്ഷിത പിശക് സംഭവിച്ചു',

      // Loading Screen Stages
      'loading_stage_preparing': 'നിങ്ങളുടെ പഠന ഗൈഡ് തയ്യാറാക്കുന്നു...',
      'loading_stage_analyzing': 'വേദപുസ്തക സന്ദർഭം വിശകലനം ചെയ്യുന്നു...',
      'loading_stage_gathering': 'ഉൾക്കാഴ്ചകൾ ശേഖരിക്കുന്നു...',
      'loading_stage_crafting': 'ചിന്തകൾ രൂപപ്പെടുത്തുന്നു...',
      'loading_stage_finalizing': 'നിങ്ങളുടെ ഗൈഡ് പൂർത്തീകരിക്കുന്നു...',

      // Loading Screen Time Estimate
      'loading_time_estimate': 'ഇതിന് സാധാരണയായി 20-30 സെക്കൻഡ് എടുക്കും',

      // Gamification - My Progress Page
      'progress_title': 'എന്റെ പുരോഗതി',
      'progress_xp_total': 'ആകെ XP',
      'progress_xp_to_next_level': 'അടുത്ത ലെവലിലേക്ക് XP',
      'progress_max_level': 'പരമാവധി ലെവൽ എത്തി!',
      'progress_streaks': 'സ്ട്രീക്കുകൾ',
      'progress_study_streak': 'പഠനം',
      'progress_verse_streak': 'വചനം',
      'progress_days': 'ദിവസം',
      'progress_personal_best': 'വ്യക്തിഗത മികച്ചത്',
      'progress_statistics': 'സ്ഥിതിവിവരക്കണക്കുകൾ',
      'progress_studies': 'പഠനങ്ങൾ',
      'progress_time_spent': 'ചെലവഴിച്ച സമയം',
      'progress_memory_verses': 'ഓർമ്മ വാക്യങ്ങൾ',
      'progress_voice_sessions': 'വോയ്സ് സെഷനുകൾ',
      'progress_saved_guides': 'സേവ് ചെയ്ത ഗൈഡുകൾ',
      'progress_study_days': 'പഠന ദിനങ്ങൾ',
      'progress_achievements': 'നേട്ടങ്ങൾ',
      'progress_failed_load': 'സ്ഥിതിവിവരക്കണക്കുകൾ ലോഡ് ചെയ്യാനായില്ല',
      'progress_try_again': 'ദയവായി പിന്നീട് വീണ്ടും ശ്രമിക്കുക',
      'progress_retry': 'വീണ്ടും ശ്രമിക്കുക',
      'progress_unlocked_on': 'അൺലോക്ക് ചെയ്തത്',
      'progress_locked': 'ലോക്ക് ചെയ്തിരിക്കുന്നു',
      'progress_view_leaderboard': 'ലീഡർബോർഡ് കാണുക',
      'progress_unlocked': 'അൺലോക്ക് ചെയ്തു',
      'progress_today': 'ഇന്ന്',
      'progress_yesterday': 'ഇന്നലെ',
      'progress_days_ago': 'ദിവസം മുമ്പ്',
      'progress_achievement_unlocked': '🎉 നേട്ടം അൺലോക്ക്! 🎉',
      'progress_awesome': 'അതിശയകരം!',

      // Achievement Categories
      'achievement_category_study': 'പഠന ഗൈഡുകൾ',
      'achievement_category_streak': 'പഠന സ്ട്രീക്കുകൾ',
      'achievement_category_memory': 'ഓർമ്മ വാക്യങ്ങൾ',
      'achievement_category_voice': 'വോയ്സ് ഡിസൈപ്ലർ',
      'achievement_category_saved': 'സേവ് ചെയ്ത ഗൈഡുകൾ',

      // First Century Christian Facts for Loading Screen (60 facts - Malayalam)
      'loading_fact_1':
          'ആദ്യകാല ക്രിസ്ത്യാനികൾ സഭാ കെട്ടിടങ്ങളിലല്ല, സ്വകാര്യ ഭവനങ്ങളിൽ കൂടിച്ചേർന്നു.',
      'loading_fact_2':
          'പുതിയ നിയമം യഥാർത്ഥത്തിൽ ഗ്രീക്കിൽ എഴുതപ്പെട്ടു, എബ്രായഭാഷയിലല്ല.',
      'loading_fact_3':
          'എഡി 100-ഓടെ, റോമൻ സാമ്രാജ്യത്തിലുടനീളം 40-ലധികം ക്രിസ്ത്യൻ സമൂഹങ്ങൾ നിലനിന്നിരുന്നു.',
      'loading_fact_4':
          'ഒന്നാം നൂറ്റാണ്ടിലെ ക്രിസ്ത്യാനികൾ പലപ്പോഴും നഗര ദരിദ്രരിൽനിന്നും താഴ്ന്ന വർഗക്കാരിൽനിന്നുമായിരുന്നു.',
      'loading_fact_5':
          'ക്രിസ്ത്യാനികൾ കൂട്ടായ്മയുടെ അടയാളമായി പരസ്പരം "പരിശുദ്ധ ചുംബനം" നൽകി.',
      'loading_fact_6':
          'ആദ്യകാല ക്രിസ്ത്യാനികൾ യഹൂദ സിനഗോഗുകളിൽ ആരാധനാക്രമങ്ങളിൽ തുടർന്നുകൊണ്ടിരുന്നു.',
      'loading_fact_7':
          'സ്നാനം പൂർണ്ണമായി വെള്ളത്തിൽ മുങ്ങിക്കൊണ്ട് നടത്തിയിരുന്നു, പലപ്പോഴും നദികളിൽ.',
      'loading_fact_8':
          'വിഗ്രഹ ദൈവങ്ങളെ നിരസിച്ചതിനാൽ റോമാക്കാർ ക്രിസ്ത്യാനികളെ "നിരീശ്വരവാദികൾ" എന്ന് വിളിച്ചു.',
      'loading_fact_9':
          'കർത്താവിന്റെ അത്താഴം അപ്പവും വീഞ്ഞും മാത്രമല്ല, യഥാർത്ഥ ഭക്ഷണമായിട്ടായിരുന്നു ആചരിച്ചിരുന്നത്.',
      'loading_fact_10':
          'സ്ത്രീകൾ ഡീക്കന്മാരായും പ്രവാചകരായും ഗൃഹസഭാ നേതാക്കളായും പ്രധാന പങ്കുവഹിച്ചു.',
      'loading_fact_11':
          'ആദ്യകാല ക്രിസ്ത്യാനികൾ സ്വത്തും വിഭവങ്ങളും സാമുദായികമായി പങ്കുവെച്ചു.',
      'loading_fact_12':
          'നീറോയുടെ കീഴിലെ പീഡനം (എഡി 64) ക്രിസ്ത്യാനികളെ വിളക്കുകളായി ജീവനോടെ ചുട്ടെരിച്ചു.',
      'loading_fact_13':
          'മത്സ്യചിഹ്നം (ഇക്തിസ്) രഹസ്യ ക്രിസ്ത്യൻ തിരിച്ചറിയൽ ചിഹ്നമായിരുന്നു.',
      'loading_fact_14':
          'മിക്ക ആദ്യകാല ക്രിസ്ത്യാനികളും സാക്ഷരതയുള്ളവരായിരുന്നു, വിദ്യാഭ്യാസത്തെ വളരെയേറെ വിലമതിച്ചിരുന്നു.',
      'loading_fact_15':
          'യേശുവിന്റെ പുനരുത്ഥാന ദിവസമായതിനാൽ ഞായറാഴ്ച ആരാധന ആരംഭിച്ചു.',
      'loading_fact_16':
          'ആദ്യകാല ക്രിസ്ത്യാനികൾ വിധവകൾ, അനാഥർ, രോഗികൾ എന്നിവരെ വ്യവസ്ഥാപിതമായി പരിപാലിച്ചു.',
      'loading_fact_17':
          'അപ്പൊസ്തലനായ പൗലോസ് എഴുതിയ ലേഖനങ്ങൾ പുതിയനിയമ പുസ്തകങ്ങളായി മാറി.',
      'loading_fact_18':
          'ക്രിസ്ത്യാനികൾ സാമ്രാജ്യാരാധനയിൽ പങ്കെടുക്കാൻ വിസമ്മതിച്ചു, വധശിക്ഷ അപകടത്തിലാക്കി.',
      'loading_fact_19':
          'ഗൃഹസഭകൾക്ക് ശരാശരി 30-50 ആളുകളെ ഉൾക്കൊള്ളാൻ കഴിയുമായിരുന്നു.',
      'loading_fact_20':
          'ആദ്യകാല ക്രിസ്ത്യൻ ആരാധനയിൽ സങ്കീർത്തനങ്ങളും സ്തുതിഗീതങ്ങളും പാടുന്നത് ഉൾപ്പെടുന്നു.',
      'loading_fact_21':
          'ജെറുസലേം സഭയുടെ നേതൃത്വം യേശുവിന്റെ സഹോദരനായ യാക്കോബായിരുന്നു.',
      'loading_fact_22':
          'കാർന്യൂഹാരിസ്തയെ തെറ്റിദ്ധരിച്ചതിനാൽ ക്രിസ്ത്യാനികളെ നരഭോജിയെന്ന് ആരോപിച്ചു.',
      'loading_fact_23':
          'അരാമിയായിരുന്നു യേശു സംസാരിച്ച ഭാഷ, പക്ഷേ സുവിശേഷം പ്രചരിപ്പിക്കാൻ ഗ്രീക്ക് ഉപയോഗിച്ചു.',
      'loading_fact_24':
          'ആദ്യകാല ക്രിസ്ത്യാനികൾ ആഴ്ചയിൽ രണ്ടുതവണ, ബുധനും വെള്ളിയും ഉപവസിച്ചു.',
      'loading_fact_25':
          '"ക്രിസ്ത്യാനികൾ" എന്ന പദം ആദ്യമായി അന്ത്യോക്യയിൽ ഏകദേശം എഡി 40-44ൽ ഉപയോഗിച്ചു.',
      'loading_fact_26':
          'പുസ്തകങ്ങൾ ചെലവേറിയതിനാൽ വിശ്വാസികൾ തിരുവെഴുത്തുകൾ മനഃപാഠമാക്കി ചൊല്ലിയിരുന്നു.',
      'loading_fact_27':
          'പീഡനം ഒഴിവാക്കാൻ ആദ്യകാല ക്രിസ്ത്യാനികൾ പുലർച്ചെക്ക് മുമ്പ് കൂടിച്ചേർന്നിരുന്നു.',
      'loading_fact_28':
          'അപ്പൊസ്തലന്മാർ യേശുവിന്റെ നാമത്തിൽ സൗഖ്യങ്ങളും അത്ഭുതങ്ങളും പ്രവർത്തിച്ചു.',
      'loading_fact_29':
          'വാണിജ്യ മാർഗങ്ങളിലൂടെയുള്ള നഗര പ്രദേശങ്ങളിൽ ക്രിസ്തുമതം അതിവേഗം വ്യാപിച്ചു.',
      'loading_fact_30':
          'ആദ്യകാല ക്രിസ്ത്യാനികൾ വിനയത്തിന്റെ പ്രവൃത്തിയായി കാലുകഴുകൽ ആചരിച്ചിരുന്നു.',
      'loading_fact_31':
          'വിധവകൾക്ക് ഭക്ഷണം നീതിപൂർവ്വം വിതരണം ചെയ്യാൻ ഡീക്കന്മാരെ നിയമിച്ചു.',
      'loading_fact_32':
          'ആദ്യകാല ക്രിസ്ത്യൻ വിശ്വാസപ്രമാണം യേശുവിന്റെ മരണത്തിന് 5 വർഷത്തിനുള്ളിൽ രൂപീകരിക്കപ്പെട്ടു.',
      'loading_fact_33':
          'പൗലോസിന്റെ മിഷനറി യാത്രകൾ കാൽനടയായും കപ്പലിലും 10,000 മൈലിലധികം സഞ്ചരിച്ചു.',
      'loading_fact_34':
          'ആദ്യകാല ക്രിസ്ത്യാനികൾ ഗ്ലാഡിയേറ്റർ ഗെയിമുകളിലും നാടക പ്രദർശനങ്ങളിലും പങ്കെടുക്കാൻ വിസമ്മതിച്ചു.',
      'loading_fact_35':
          'ഒന്നാം നൂറ്റാണ്ടിൽ സുവിശേഷം എത്യോപ്യ, ഇന്ത്യ, അർമേനിയ എന്നിവിടങ്ങളിലേക്ക് വ്യാപിച്ചു.',
      'loading_fact_36':
          'മൂന്നാം നൂറ്റാണ്ട് വരെ കെട്ടിടങ്ങൾ ഉയർന്നുവന്നപ്പോൾ ക്രിസ്ത്യാനികൾ ഗൃഹസഭകൾ ഉപയോഗിച്ചിരുന്നു.',
      'loading_fact_37':
          'യഹൂദ പാരമ്പര്യം തുടർന്ന് ദിവസവും മൂന്നു തവണ പ്രാർത്ഥന നടത്തിയിരുന്നു.',
      'loading_fact_38':
          'സാമൂഹിക പദവി പരിഗണിക്കാതെ ആദ്യകാല ക്രിസ്ത്യാനികൾ പരസ്പരം "സഹോദരങ്ങൾ" എന്ന് വിളിച്ചു.',
      'loading_fact_39':
          'തീവ്രമായ റോമൻ പീഡനകാലത്താണ് വെളിപാടിന്റെ പുസ്തകം എഴുതപ്പെട്ടത്.',
      'loading_fact_40':
          'സ്നാനത്തിന് മുമ്പ് പരിവർത്തിതർ മാസങ്ങളോളം വിപുലമായ ഉപദേശം സ്വീകരിച്ചിരുന്നു.',
      'loading_fact_41':
          'റോമൻ സമൂഹത്തിൽ നിന്ന് വ്യത്യസ്തമായി ആദ്യകാല ക്രിസ്ത്യാനികൾ ഗർഭച്ഛിദ്രവും ശിശുഹത്യയും നിരസിച്ചു.',
      'loading_fact_42':
          'സ്ത്രീകൾക്ക് റോമൻ കോടതികളിൽ സാക്ഷ്യം നൽകാൻ കഴിഞ്ഞില്ല, പക്ഷേ യേശു ആദ്യം സ്ത്രീകൾക്ക് പ്രത്യക്ഷനായി.',
      'loading_fact_43':
          'നിലനിൽക്കുന്ന ഏറ്റവും പഴക്കമുള്ള ക്രിസ്ത്യൻ കെട്ടിടം സിറിയയിലെ എഡി 233 മുതലുള്ളതാണ്.',
      'loading_fact_44':
          'ആദ്യകാല വിശ്വാസികൾ തങ്ങളുടെ സമ്മേളനങ്ങളെ "അപ്പം മുറിക്കൽ" എന്ന് വിളിച്ചു.',
      'loading_fact_45':
          'തുടക്കത്തിൽ ക്രിസ്ത്യാനികൾ റോമൻ സൈന്യത്തിൽ സേവനം ചെയ്യുന്നത് നിരോധിച്ചിരുന്നു.',
      'loading_fact_46':
          'പെന്തെക്കൊസ്തിൽ അപ്പൊസ്തലന്മാർ വിവിധ ഭാഷകളിൽ സംസാരിച്ചു, അവിടെയുണ്ടായിരുന്ന എല്ലാവർക്കും മനസ്സിലായി.',
      'loading_fact_47':
          'ആദ്യകാല ക്രിസ്ത്യൻ ലേഖനങ്ങൾ സഭകൾക്കിടയിൽ പകർത്തി പങ്കിട്ടിരുന്നു.',
      'loading_fact_48':
          'സഞ്ചാരി മിഷനറിമാരെയും അധ്യാപകരെയും പിന്തുണയ്ക്കാൻ വിശ്വാസികൾ സ്വത്ത് വിറ്റു.',
      'loading_fact_49':
          'ആദ്യത്തെ സുവിശേഷം മർക്കോസ്, ഏകദേശം എഡി 65-70-ൽ എഴുതപ്പെട്ടതാണ്.',
      'loading_fact_50':
          'ക്രിസ്ത്യാനികൾ സൗഖ്യത്തിനായി രോഗികളെ എണ്ണകൊണ്ട് അഭിഷേകം ചെയ്തു.',
      'loading_fact_51':
          'ആദ്യകാല വിശ്വാസികൾ ജോലി, സ്വത്ത്, റോമൻ പൗരത്വം എന്നിവയുടെ നഷ്ടം നേരിട്ടു.',
      'loading_fact_52':
          'എഡി 50-ഓടെ റോമിലെ സഭയിൽ യഹൂദരും വിജാതീയരുമായ വിശ്വാസികൾ ഉണ്ടായിരുന്നു.',
      'loading_fact_53':
          'പീഡനകാലത്ത് രഹസ്യ ആരാധനയ്ക്കായി ക്രിസ്ത്യാനികൾ ഗുഹകളും കാറ്റകോമ്പുകളും ഉപയോഗിച്ചു.',
      'loading_fact_54':
          'ആദ്യകാല വിശ്വാസികൾ കോടതി കേസുകൾ ഒഴിവാക്കി, സഭയ്ക്കുള്ളിൽ തർക്കങ്ങൾ പരിഹരിച്ചു.',
      'loading_fact_55':
          'ക്രിസ്തുവിനെ പ്രസംഗിച്ചതിന് അപ്പൊസ്തലനായ യോഹന്നാൻ പത്മോസ് ദ്വീപിലേക്ക് പ്രവാസം അയക്കപ്പെട്ടു.',
      'loading_fact_56':
          'ക്രിസ്ത്യാനികൾ ആതിഥ്യമര്യാദ ആചരിച്ചു, സഞ്ചാരി വിശ്വാസികളെ സൗജന്യമായി ആതിഥേയത്വം നൽകി.',
      'loading_fact_57':
          'ആദ്യകാല സഭാ നേതാക്കൾ സാധാരണയായി മുഖ്യന്മാരായിരുന്നു, പ്രൊഫഷണൽ വൈദികരല്ല.',
      'loading_fact_58':
          'വിശ്വാസികൾ റോമാക്കാരാലും യഹൂദ അധികാരികളാലും പീഡിപ്പിക്കപ്പെട്ടു.',
      'loading_fact_59':
          'കഠിനമായ പീഡനം ഉണ്ടായിട്ടും ഒന്നാം നൂറ്റാണ്ടിൽ സഭാ വളർച്ച അതിവേഗമായിരുന്നു.',
      'loading_fact_60':
          'യേശു തങ്ങളുടെ ജീവിതകാലത്ത് തന്നെ മടങ്ങിവരുമെന്ന് ആദ്യകാല ക്രിസ്ത്യാനികൾ വിശ്വസിച്ചു.',

      // Community Feature
      'communityTitle': 'സമൂഹം',
      'communityJoinButton': 'ചേരുക',
      'communityJoinedSuccess': 'നിങ്ങൾ കൂട്ടായ്മയിൽ ചേർന്നു!',
      'communityJoinFailed':
          'കൂട്ടായ്മയിൽ ചേരാൻ കഴിഞ്ഞില്ല. ദയവായി വീണ്ടും ശ്രമിക്കുക.',
      'communityLoadError': 'കൂട്ടായ്മകൾ ലോഡ് ചെയ്യാൻ കഴിഞ്ഞില്ല',
      'communityRetry': 'വീണ്ടും ശ്രമിക്കുക',
      'communityEmptyTitle': 'നിങ്ങൾ ഇതുവരെ ഒരു കൂട്ടായ്മയിലും ചേർന്നിട്ടില്ല',
      'communityEmptyDescription':
          'വിശ്വാസികളുടെ സമൂഹത്തോടൊപ്പം ബൈബിൾ പഠിക്കാൻ ഒരു കൂട്ടായ്മയിൽ ചേരുക.',
      'communityJoinFellowship': 'ഒരു കൂട്ടായ്മയിൽ ചേരുക',
      'communityMyFellowships': 'എന്റെ കൂട്ടായ്മകൾ',
      'communityDiscover': 'പൊതു ഫെല്ലോഷിപ്പുകൾ പര്യവേക്ഷണം ചെയ്യുക',
      'communityMembers': 'അംഗങ്ങൾ',
      'communityGuideLabel': 'ഗൈഡ്',
      'joinFellowshipTitle': 'കൂട്ടായ്മയിൽ ചേരുക',
      'joinFellowshipHeading': 'നിങ്ങളുടെ ക്ഷണ കോഡ് നൽകുക',
      'joinFellowshipInstructions':
          'നിങ്ങളുടെ കൂട്ടായ്മ നേതാവിനോട് ക്ഷണ കോഡ് ചോദിച്ച് ചുവടെ നൽകുക.',
      'joinFellowshipCodeLabel': 'ക്ഷണ കോഡ്',
      'joinFellowshipCodeHint': 'ക്ഷണ കോഡ് നൽകുക',
      'joinFellowshipButton': 'കൂട്ടായ്മയിൽ ചേരുക',
      'joinFellowshipHelper': 'ക്ഷണ കോഡുകൾ കൂട്ടായ്മ മെൻ്ററുകൾ നൽകുന്നു.',
      'fellowshipDefaultTitle': 'കൂട്ടായ്മ',
      'fellowshipTabFeed': 'ഫീഡ്',
      'fellowshipTabLessons': 'പാഠങ്ങൾ',
      'fellowshipTabMembers': 'അംഗങ്ങൾ',
      'feedNewPost': 'പുതിയ പോസ്റ്റ്',
      'feedLoadError': 'എന്തോ തകരാറുണ്ടായി.',
      'feedRetry': 'വീണ്ടും ശ്രമിക്കുക',
      'feedEmpty': 'ഇതുവരെ പോസ്റ്റുകൾ ഇല്ല.\nആദ്യം പങ്കുവെക്കൂ!',
      'postTypePrayer': 'പ്രാർഥന',
      'postTypePraise': 'സ്തുതി',
      'postTypeQuestion': 'ചോദ്യം',
      'postTypeGeneral': 'പൊതുവായ',
      'postTypeStudyNote': 'പഠന കുറിപ്പ്',
      'postTypeSharedGuide': 'പങ്കിട്ട ഗൈഡ്',
      'studyNoteLesson': 'പാഠം',
      'sharedGuideCta': 'ഈ ഗൈഡ് പഠിക്കുക',
      'feedCreateTitle': 'പുതിയ പോസ്റ്റ്',
      'feedCreateTypeLabel': 'പോസ്റ്റ് തരം',
      'feedCreateContentLabel':
          'നിങ്ങളുടെ കൂട്ടായ്മയുമായി എന്തെങ്കിലും പങ്കിടുക',
      'feedCreateContentHint': 'നിങ്ങളുടെ മനസ്സിൽ എന്തുണ്ട്?',
      'feedCreatePost': 'പോസ്റ്റ് ചെയ്യുക',
      'lessonsComing': 'പാഠങ്ങൾ ഉടൻ വരും',
      'lessonsDescription': 'നിങ്ങളുടെ കൂട്ടായ്മ പഠന ഗൈഡുകൾ ഇവിടെ ദൃശ്യമാകും.',
      'lessonsAssignPath': 'ലേണിംഗ് പാത്ത് നിശ്ചയിക്കുക',
      'lessonsChangePath': 'ലേണിംഗ് പാത്ത് മാറ്റുക',
      'lessonsNoPathMentor':
          'ഇതുവരെ ഒരു ലേണിംഗ് പാത്ത് നിശ്ചയിച്ചിട്ടില്ല.\nഒന്ന് നിശ്ചയിക്കാൻ ചുവടെ ടാപ്പ് ചെയ്യുക.',
      'lessonsNoPathMember':
          'നിങ്ങളുടെ മെൻ്ററർ ഇതുവരെ ഒരു ലേണിംഗ് പാത്ത് നിശ്ചയിച്ചിട്ടില്ല.',
      'lessonsCurrentStudy': 'നിലവിലെ പഠനം',
      'lessonsSelectPath': 'ഒരു ലേണിംഗ് പാത്ത് തിരഞ്ഞെടുക്കുക',
      'lessonsPickPathTitle':
          'നിങ്ങളുടെ കൂട്ടായ്മക്കായി ഒരു ലേണിംഗ് പാത്ത് തിരഞ്ഞെടുക്കുക',
      'searchPathsHint': 'ലേണിംഗ് പാത്തുകൾ തിരയുക...',
      'searchNoResults': 'തിരയലുമായി പൊരുത്തപ്പെടുന്ന പാത്തുകൾ ഇല്ല',
      'lessonsGuide': 'ഗൈഡ്',
      'lessonsTitle': 'പാഠങ്ങൾ',
      'lessonsMemberProgress': 'അംഗ പുരോഗതി',
      'lessonsMembersCompleted': 'പൂർത്തിയാക്കി',
      'membersInvite': 'ക്ഷണിക്കുക',
      'membersEmpty': 'ഇതുവരെ അംഗങ്ങൾ ഇല്ല',
      'membersEmptyDescription':
          'ആരെയെങ്കിലും നിങ്ങളുടെ കൂട്ടായ്മയിൽ ചേരാൻ ക്ഷണിക്കുക.',
      'membersLoadError': 'അംഗങ്ങളെ ലോഡ് ചെയ്യാൻ കഴിഞ്ഞില്ല.',
      'membersRetry': 'വീണ്ടും ശ്രമിക്കുക',
      'membersMuted': 'നിശ്ശബ്ദമാക്കി',
      'membersInviteTitle': 'കൂട്ടായ്മയിലേക്ക് ക്ഷണിക്കുക',
      'membersInviteSubtitle':
          'ആരെയെങ്കിലും നിങ്ങളുടെ കൂട്ടായ്മയിലേക്ക് ക്ഷണിക്കാൻ ഈ കോഡ് പങ്കിടുക.',
      'membersInviteComingSoon':
          'ഉടൻ വരും \u2014 ക്ഷണ ലിങ്കുകൾ ഇവിടെ ദൃശ്യമാകും',
      'membersCopy': 'പകർത്തുക',
      'leaveFellowshipTitle': 'കൂട്ടായ്മ വിടുക',
      'leaveFellowshipConfirm': 'നിങ്ങൾക്ക് ഈ കൂട്ടായ്മ വിടണോ?',
      'cancel': 'റദ്ദാക്കുക',
      'muteSuccess': 'അംഗം നിശ്ശബ്ദമാക്കി',
      'unmuteSuccess': 'അംഗം നിശ്ശബ്ദം മാറ്റി',
      'inviteGenerating': 'ക്ഷണം സൃഷ്ടിക്കുന്നു...',
      'inviteShareCode': 'ഈ കോഡ് പങ്കിടുക',
      'inviteExpires': '7 ദിവസത്തിൽ കാലഹരണം',
      'lessonsAdvanceGuide': 'അടുത്ത ഗൈഡിലേക്ക് മുന്നേറുക',
      'lessonsAdvanceConfirm':
          'നിലവിലെ ഗൈഡ് പൂർത്തിയാക്കി അടുത്തതിലേക്ക് മുന്നേറണോ?',
      'lessonsCompleted': 'പഠനം പൂർത്തിയായി!',
      'lessonsGuideProgress': 'ഗൈഡ്',
      'lessonsOf': 'ൽ',
      // Edit Fellowship
      'editFellowshipTitle': 'കൂട്ടായ്മ തിരുത്തുക',
      'editFellowshipSave': 'മാറ്റങ്ങൾ സംരക്ഷിക്കുക',
      'editFellowshipSuccess': 'കൂട്ടായ്മ അപ്ഡേറ്റ് ചെയ്തു',
      // Invite list + revoke
      'inviteListEmpty': 'സജീവ ക്ഷണ ലിങ്കുകൾ ഇല്ല',
      'inviteRevoke': 'റദ്ദാക്കുക',
      'inviteRevokeSuccess': 'ക്ഷണം റദ്ദാക്കി',
      // Transfer mentor
      'transferMentorTitle': 'മെൻ്റർ റോൾ കൈമാറുക',
      'transferMentorConfirm':
          'ഈ അംഗത്തിന് മെൻ്റർ റോൾ കൈമാറണോ? നിങ്ങൾ ഒരു സാധാരണ അംഗമാകും.',
      'transferMentorSuccess': 'മെൻ്റർ റോൾ കൈമാറ്റം ചെയ്തു',
      'removeMemberTitle': 'അംഗത്തെ നീക്കംചെയ്യുക',
      'removeMemberConfirm':
          'ഈ അംഗത്തെ കൂട്ടായ്മയിൽ നിന്ന് നീക്കംചെയ്യണോ? പുതിയ ക്ഷണം ഉപയോഗിച്ച് അവർക്ക് വീണ്ടും ചേരാം.',
      'removeMemberAction': 'നീക്കംചെയ്യുക',
      'removeMemberSuccess': 'അംഗത്തെ നീക്കംചെയ്തു',
      'memberJoinedLabel': 'ചേർന്നത്',
      // Report
      'reportTitle': 'ഉള്ളടക്കം റിപ്പോർട്ട് ചെയ്യുക',
      'reportReasonLabel': 'കാരണം',
      'reportReasonHint':
          'നിങ്ങൾ ഇത് എന്തിന് റിപ്പോർട്ട് ചെയ്യുന്നു? (5–500 അക്ഷരങ്ങൾ)',
      'reportSubmit': 'റിപ്പോർട്ട് സമർപ്പിക്കുക',
      'reportSuccess': 'റിപ്പോർട്ട് സമർപ്പിച്ചു. നന്ദി.',
      // Create Fellowship Screen
      'createFellowshipTitle': 'കൂട്ടായ്മ ഉണ്ടാക്കുക',
      'createFellowshipHeading': 'ഒരു പുതിയ കൂട്ടായ്മ ആരംഭിക്കുക',
      'createFellowshipSubtitle':
          'നിങ്ങളുടെ ഗ്രൂപ്പിന് ഒരു പേര് നൽകി മറ്റുള്ളവരെ ബൈബിൾ പഠിക്കാൻ ക്ഷണിക്കുക.',
      'createFellowshipNameLabel': 'കൂട്ടായ്മ പേര്',
      'createFellowshipNameHint': 'ഉദാ. Morning Bible Warriors',
      'createFellowshipDescLabel': 'വിവരണം (ഐച്ഛികം)',
      'createFellowshipDescHint': 'നിങ്ങളുടെ കൂട്ടായ്മ എന്ത് പഠിക്കും?',
      'createFellowshipMaxLabel': 'പരമാവധി അംഗങ്ങൾ (2–50)',
      'createFellowshipButton': 'കൂട്ടായ്മ ഉണ്ടാക്കുക',
      'createFellowshipSuccess': 'കൂട്ടായ്മ ഉണ്ടായി!',
      'createFellowshipFailed': 'കൂട്ടായ്മ ഉണ്ടാക്കാൻ കഴിഞ്ഞില്ല.',
      'createFellowshipNameError': 'പേര് 3–60 അക്ഷരങ്ങൾ ആയിരിക്കണം.',
      'createFellowshipDescError': 'വിവരണം പരമാവധി 500 അക്ഷരങ്ങൾ.',
      'createFellowshipMaxError': 'പരമാവധി അംഗങ്ങൾ 2–50 ആയിരിക്കണം.',
      // Discover tab
      'discoverFilterAll': 'എല്ലാ ഭാഷകളും',
      'discoverFilterEnglish': 'ഇംഗ്ലീഷ്',
      'discoverFilterHindi': 'ഹിന്ദി',
      'discoverFilterMalayalam': 'മലയാളം',
      'discoverEmpty': 'ഇനിയും പൊതു കൂട്ടായ്മകൾ ഇല്ല',
      'discoverEmptyShowAll': 'എല്ലാ ഭാഷകളും കാണുക',
      'discoverJoinButton': 'ചേരുക',
      'discoverFull': 'നിറഞ്ഞു',
      'discoverJoinedSnackbar': 'നിങ്ങൾ {name}-ൽ ചേർന്നു!',
      'discoverMembersCount': '{count} / {max} അംഗങ്ങൾ',
      'createFellowshipLanguageLabel': 'ഭാഷ',
      'createFellowshipMakePublicLabel': 'പൊതുവാക്കുക',
      'createFellowshipMakePublicHint':
          'Discover-ൽ എല്ലാ ഉപയോക്താക്കൾക്കും ദൃശ്യമാകും',
      'meetingsSyncBannerTitle':
          'പുതിയ അംഗങ്ങൾക്ക് കലണ്ടർ ക്ഷണം ലഭിച്ചിട്ടില്ല',
      'meetingsSyncCalendar': 'കലണ്ടറിലേക്ക് സമന്വയിപ്പിക്കുക',
      'meetingsSyncReconnect': 'ദയവായി Google Calendar വീണ്ടും ബന്ധിപ്പിക്കുക',
      'homeAssignPathMentor': 'പഠന പാത നൽകുക',
      'homeNoPathAssigned': 'പഠന പാത ഇല്ല',
      'fellowshipRecentActivity': 'സമീപകാല പ്രവർത്തനം',
      'fellowshipViewAll': 'എല്ലാം കാണുക',
      'feedPostSomething': 'എന്തെങ്കിലും പോസ്റ്റ് ചെയ്യുക',
      'meetingsTitle': 'മീറ്റിംഗുകൾ',
      'meetingsSchedule': 'ഷെഡ്യൂൾ ചെയ്യുക',
      'meetingsSchedulePrompt': 'മീറ്റിംഗ് ഷെഡ്യൂൾ ചെയ്യാൻ + അമർത്തുക',
      'meetingsNoUpcoming': 'വരാനിരിക്കുന്ന മീറ്റിംഗുകൾ ഇല്ല',
      'meetingsNextNoTime': 'അടുത്തത്: {0}',
      'meetingsNextWithTime': 'അടുത്തത്: {0} at {1}',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['app_title']!;
  String get continueButton =>
      _localizedValues[locale.languageCode]!['continue_button']!;
  String get backButton =>
      _localizedValues[locale.languageCode]!['back_button']!;
  String get nextButton =>
      _localizedValues[locale.languageCode]!['next_button']!;
  String get cancelButton =>
      _localizedValues[locale.languageCode]!['cancel_button']!;
  String get retryButton =>
      _localizedValues[locale.languageCode]!['retry_button']!;
  String get loading => _localizedValues[locale.languageCode]!['loading']!;
  String get errorTitle =>
      _localizedValues[locale.languageCode]!['error_title']!;
  String get errorMessage =>
      _localizedValues[locale.languageCode]!['error_message']!;

  // Onboarding
  String get onboardingWelcomeTitle =>
      _localizedValues[locale.languageCode]!['onboarding_welcome_title']!;
  String get onboardingWelcomeSubtitle =>
      _localizedValues[locale.languageCode]!['onboarding_welcome_subtitle']!;
  String get onboardingLanguageTitle =>
      _localizedValues[locale.languageCode]!['onboarding_language_title']!;
  String get onboardingLanguageSubtitle =>
      _localizedValues[locale.languageCode]!['onboarding_language_subtitle']!;
  String get onboardingPurposeTitle =>
      _localizedValues[locale.languageCode]!['onboarding_purpose_title']!;
  String get onboardingPurposeSubtitle =>
      _localizedValues[locale.languageCode]!['onboarding_purpose_subtitle']!;
  String get languageEnglish =>
      _localizedValues[locale.languageCode]!['language_english']!;
  String get languageHindi =>
      _localizedValues[locale.languageCode]!['language_hindi']!;
  String get languageMalayalam =>
      _localizedValues[locale.languageCode]!['language_malayalam']!;

  // Study Input
  String get studyInputTitle =>
      _localizedValues[locale.languageCode]!['study_input_title']!;
  String get studyInputVerseTab =>
      _localizedValues[locale.languageCode]!['study_input_verse_tab']!;
  String get studyInputTopicTab =>
      _localizedValues[locale.languageCode]!['study_input_topic_tab']!;
  String get studyInputVerseHint =>
      _localizedValues[locale.languageCode]!['study_input_verse_hint']!;
  String get studyInputTopicHint =>
      _localizedValues[locale.languageCode]!['study_input_topic_hint']!;
  String get studyInputGenerateButton =>
      _localizedValues[locale.languageCode]!['study_input_generate_button']!;
  String get studyInputVerseValidation =>
      _localizedValues[locale.languageCode]!['study_input_verse_validation']!;
  String get studyInputTopicValidation =>
      _localizedValues[locale.languageCode]!['study_input_topic_validation']!;
  String get studyInputGenerating =>
      _localizedValues[locale.languageCode]!['study_input_generating']!;

  // Study Result
  String get studyResultTitle =>
      _localizedValues[locale.languageCode]!['study_result_title']!;
  String get studyResultNewButton =>
      _localizedValues[locale.languageCode]!['study_result_new_button']!;
  String get studyResultShareButton =>
      _localizedValues[locale.languageCode]!['study_result_share_button']!;

  // Error Page
  String get errorPageTitle =>
      _localizedValues[locale.languageCode]!['error_page_title']!;
  String get errorPageNetwork =>
      _localizedValues[locale.languageCode]!['error_page_network']!;
  String get errorPageServer =>
      _localizedValues[locale.languageCode]!['error_page_server']!;
  String get errorPageUnknown =>
      _localizedValues[locale.languageCode]!['error_page_unknown']!;

  // Loading Screen Stages
  String get loadingStagePreparing =>
      _localizedValues[locale.languageCode]!['loading_stage_preparing']!;
  String get loadingStageAnalyzing =>
      _localizedValues[locale.languageCode]!['loading_stage_analyzing']!;
  String get loadingStageGathering =>
      _localizedValues[locale.languageCode]!['loading_stage_gathering']!;
  String get loadingStageCrafting =>
      _localizedValues[locale.languageCode]!['loading_stage_crafting']!;
  String get loadingStageFinalizing =>
      _localizedValues[locale.languageCode]!['loading_stage_finalizing']!;

  // Loading Screen Time Estimate
  String get loadingTimeEstimate =>
      _localizedValues[locale.languageCode]!['loading_time_estimate']!;

  // Gamification - My Progress Page
  String get progressTitle =>
      _localizedValues[locale.languageCode]!['progress_title']!;
  String get progressXpTotal =>
      _localizedValues[locale.languageCode]!['progress_xp_total']!;
  String get progressXpToNextLevel =>
      _localizedValues[locale.languageCode]!['progress_xp_to_next_level']!;
  String get progressMaxLevel =>
      _localizedValues[locale.languageCode]!['progress_max_level']!;
  String get progressStreaks =>
      _localizedValues[locale.languageCode]!['progress_streaks']!;
  String get progressStudyStreak =>
      _localizedValues[locale.languageCode]!['progress_study_streak']!;
  String get progressVerseStreak =>
      _localizedValues[locale.languageCode]!['progress_verse_streak']!;
  String get progressDays =>
      _localizedValues[locale.languageCode]!['progress_days']!;
  String get progressPersonalBest =>
      _localizedValues[locale.languageCode]!['progress_personal_best']!;
  String get progressStatistics =>
      _localizedValues[locale.languageCode]!['progress_statistics']!;
  String get progressStudies =>
      _localizedValues[locale.languageCode]!['progress_studies']!;
  String get progressTimeSpent =>
      _localizedValues[locale.languageCode]!['progress_time_spent']!;
  String get progressMemoryVerses =>
      _localizedValues[locale.languageCode]!['progress_memory_verses']!;
  String get progressVoiceSessions =>
      _localizedValues[locale.languageCode]!['progress_voice_sessions']!;
  String get progressSavedGuides =>
      _localizedValues[locale.languageCode]!['progress_saved_guides']!;
  String get progressStudyDays =>
      _localizedValues[locale.languageCode]!['progress_study_days']!;
  String get progressAchievements =>
      _localizedValues[locale.languageCode]!['progress_achievements']!;
  String get progressFailedLoad =>
      _localizedValues[locale.languageCode]!['progress_failed_load']!;
  String get progressTryAgain =>
      _localizedValues[locale.languageCode]!['progress_try_again']!;
  String get progressRetry =>
      _localizedValues[locale.languageCode]!['progress_retry']!;
  String get progressUnlockedOn =>
      _localizedValues[locale.languageCode]!['progress_unlocked_on']!;
  String get progressLocked =>
      _localizedValues[locale.languageCode]!['progress_locked']!;
  String get progressViewLeaderboard =>
      _localizedValues[locale.languageCode]!['progress_view_leaderboard']!;
  String get progressUnlocked =>
      _localizedValues[locale.languageCode]!['progress_unlocked']!;
  String get progressToday =>
      _localizedValues[locale.languageCode]!['progress_today']!;
  String get progressYesterday =>
      _localizedValues[locale.languageCode]!['progress_yesterday']!;
  String get progressDaysAgo =>
      _localizedValues[locale.languageCode]!['progress_days_ago']!;
  String get progressAchievementUnlocked =>
      _localizedValues[locale.languageCode]!['progress_achievement_unlocked']!;
  String get progressAwesome =>
      _localizedValues[locale.languageCode]!['progress_awesome']!;

  // Achievement Categories
  String get achievementCategoryStudy =>
      _localizedValues[locale.languageCode]!['achievement_category_study']!;
  String get achievementCategoryStreak =>
      _localizedValues[locale.languageCode]!['achievement_category_streak']!;
  String get achievementCategoryMemory =>
      _localizedValues[locale.languageCode]!['achievement_category_memory']!;
  String get achievementCategoryVoice =>
      _localizedValues[locale.languageCode]!['achievement_category_voice']!;
  String get achievementCategorySaved =>
      _localizedValues[locale.languageCode]!['achievement_category_saved']!;

  // Community Feature
  String get communityTitle =>
      _localizedValues[locale.languageCode]!['communityTitle']!;
  String get communityJoinButton =>
      _localizedValues[locale.languageCode]!['communityJoinButton']!;
  String get communityJoinedSuccess =>
      _localizedValues[locale.languageCode]!['communityJoinedSuccess']!;
  String get communityJoinFailed =>
      _localizedValues[locale.languageCode]!['communityJoinFailed']!;
  String get communityLoadError =>
      _localizedValues[locale.languageCode]!['communityLoadError']!;
  String get communityRetry =>
      _localizedValues[locale.languageCode]!['communityRetry']!;
  String get communityEmptyTitle =>
      _localizedValues[locale.languageCode]!['communityEmptyTitle']!;
  String get communityEmptyDescription =>
      _localizedValues[locale.languageCode]!['communityEmptyDescription']!;
  String get communityJoinFellowship =>
      _localizedValues[locale.languageCode]!['communityJoinFellowship']!;
  String get communityMyFellowships =>
      _localizedValues[locale.languageCode]!['communityMyFellowships']!;
  String get communityDiscover =>
      _localizedValues[locale.languageCode]!['communityDiscover']!;
  String get communityMembers =>
      _localizedValues[locale.languageCode]!['communityMembers']!;
  String get communityGuideLabel =>
      _localizedValues[locale.languageCode]!['communityGuideLabel']!;
  String get joinFellowshipTitle =>
      _localizedValues[locale.languageCode]!['joinFellowshipTitle']!;
  String get joinFellowshipHeading =>
      _localizedValues[locale.languageCode]!['joinFellowshipHeading']!;
  String get joinFellowshipInstructions =>
      _localizedValues[locale.languageCode]!['joinFellowshipInstructions']!;
  String get joinFellowshipCodeLabel =>
      _localizedValues[locale.languageCode]!['joinFellowshipCodeLabel']!;
  String get joinFellowshipCodeHint =>
      _localizedValues[locale.languageCode]!['joinFellowshipCodeHint']!;
  String get joinFellowshipButton =>
      _localizedValues[locale.languageCode]!['joinFellowshipButton']!;
  String get joinFellowshipHelper =>
      _localizedValues[locale.languageCode]!['joinFellowshipHelper']!;
  String get fellowshipDefaultTitle =>
      _localizedValues[locale.languageCode]!['fellowshipDefaultTitle']!;
  String get fellowshipTabFeed =>
      _localizedValues[locale.languageCode]!['fellowshipTabFeed']!;
  String get fellowshipTabLessons =>
      _localizedValues[locale.languageCode]!['fellowshipTabLessons']!;
  String get fellowshipTabMembers =>
      _localizedValues[locale.languageCode]!['fellowshipTabMembers']!;
  String get feedNewPost =>
      _localizedValues[locale.languageCode]!['feedNewPost']!;
  String get feedLoadError =>
      _localizedValues[locale.languageCode]!['feedLoadError']!;
  String get feedRetry => _localizedValues[locale.languageCode]!['feedRetry']!;
  String get feedEmpty => _localizedValues[locale.languageCode]!['feedEmpty']!;
  String get postTypePrayer =>
      _localizedValues[locale.languageCode]!['postTypePrayer']!;
  String get postTypePraise =>
      _localizedValues[locale.languageCode]!['postTypePraise']!;
  String get postTypeQuestion =>
      _localizedValues[locale.languageCode]!['postTypeQuestion']!;
  String get postTypeGeneral =>
      _localizedValues[locale.languageCode]!['postTypeGeneral']!;
  String get postTypeStudyNote =>
      _localizedValues[locale.languageCode]!['postTypeStudyNote']!;
  String get postTypeSharedGuide =>
      _localizedValues[locale.languageCode]!['postTypeSharedGuide']!;
  String get studyNoteLesson =>
      _localizedValues[locale.languageCode]!['studyNoteLesson']!;
  String get sharedGuideCta =>
      _localizedValues[locale.languageCode]!['sharedGuideCta']!;
  String get feedCreateTitle =>
      _localizedValues[locale.languageCode]!['feedCreateTitle']!;
  String get feedCreateTypeLabel =>
      _localizedValues[locale.languageCode]!['feedCreateTypeLabel']!;
  String get feedCreateContentLabel =>
      _localizedValues[locale.languageCode]!['feedCreateContentLabel']!;
  String get feedCreateContentHint =>
      _localizedValues[locale.languageCode]!['feedCreateContentHint']!;
  String get feedCreatePost =>
      _localizedValues[locale.languageCode]!['feedCreatePost']!;
  String get lessonsComing =>
      _localizedValues[locale.languageCode]!['lessonsComing']!;
  String get lessonsDescription =>
      _localizedValues[locale.languageCode]!['lessonsDescription']!;
  String get lessonsAssignPath =>
      _localizedValues[locale.languageCode]!['lessonsAssignPath']!;
  String get lessonsChangePath =>
      _localizedValues[locale.languageCode]!['lessonsChangePath']!;
  String get lessonsNoPathMentor =>
      _localizedValues[locale.languageCode]!['lessonsNoPathMentor']!;
  String get lessonsNoPathMember =>
      _localizedValues[locale.languageCode]!['lessonsNoPathMember']!;
  String get lessonsCurrentStudy =>
      _localizedValues[locale.languageCode]!['lessonsCurrentStudy']!;
  String get lessonsSelectPath =>
      _localizedValues[locale.languageCode]!['lessonsSelectPath']!;
  String get lessonsPickPathTitle =>
      _localizedValues[locale.languageCode]!['lessonsPickPathTitle']!;
  String get searchPathsHint =>
      _localizedValues[locale.languageCode]!['searchPathsHint']!;
  String get searchNoResults =>
      _localizedValues[locale.languageCode]!['searchNoResults']!;
  String get lessonsGuide =>
      _localizedValues[locale.languageCode]!['lessonsGuide']!;
  String get lessonsTitle =>
      _localizedValues[locale.languageCode]!['lessonsTitle']!;
  String get lessonsMemberProgress =>
      _localizedValues[locale.languageCode]!['lessonsMemberProgress']!;
  String get lessonsMembersCompleted =>
      _localizedValues[locale.languageCode]!['lessonsMembersCompleted']!;
  String get membersInvite =>
      _localizedValues[locale.languageCode]!['membersInvite']!;
  String get membersEmpty =>
      _localizedValues[locale.languageCode]!['membersEmpty']!;
  String get membersEmptyDescription =>
      _localizedValues[locale.languageCode]!['membersEmptyDescription']!;
  String get membersLoadError =>
      _localizedValues[locale.languageCode]!['membersLoadError']!;
  String get membersRetry =>
      _localizedValues[locale.languageCode]!['membersRetry']!;
  String get membersMuted =>
      _localizedValues[locale.languageCode]!['membersMuted']!;
  String get membersInviteTitle =>
      _localizedValues[locale.languageCode]!['membersInviteTitle']!;
  String get membersInviteSubtitle =>
      _localizedValues[locale.languageCode]!['membersInviteSubtitle']!;
  String get membersInviteComingSoon =>
      _localizedValues[locale.languageCode]!['membersInviteComingSoon']!;
  String get membersCopy =>
      _localizedValues[locale.languageCode]!['membersCopy']!;

  // Leave / Mute / Invite / Lessons — additional keys
  String get leaveFellowshipTitle =>
      _localizedValues[locale.languageCode]!['leaveFellowshipTitle']!;
  String get leaveFellowshipConfirm =>
      _localizedValues[locale.languageCode]!['leaveFellowshipConfirm']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get muteSuccess =>
      _localizedValues[locale.languageCode]!['muteSuccess']!;
  String get unmuteSuccess =>
      _localizedValues[locale.languageCode]!['unmuteSuccess']!;
  String get inviteGenerating =>
      _localizedValues[locale.languageCode]!['inviteGenerating']!;
  String get inviteShareCode =>
      _localizedValues[locale.languageCode]!['inviteShareCode']!;
  String get inviteExpires =>
      _localizedValues[locale.languageCode]!['inviteExpires']!;
  String get lessonsAdvanceGuide =>
      _localizedValues[locale.languageCode]!['lessonsAdvanceGuide']!;
  String get lessonsAdvanceConfirm =>
      _localizedValues[locale.languageCode]!['lessonsAdvanceConfirm']!;
  String get lessonsCompleted =>
      _localizedValues[locale.languageCode]!['lessonsCompleted']!;
  String get lessonsGuideProgress =>
      _localizedValues[locale.languageCode]!['lessonsGuideProgress']!;
  String get lessonsOf => _localizedValues[locale.languageCode]!['lessonsOf']!;

  // Edit Fellowship
  String get editFellowshipTitle =>
      _localizedValues[locale.languageCode]!['editFellowshipTitle']!;
  String get editFellowshipSave =>
      _localizedValues[locale.languageCode]!['editFellowshipSave']!;
  String get editFellowshipSuccess =>
      _localizedValues[locale.languageCode]!['editFellowshipSuccess']!;
  // Invite list + revoke
  String get inviteListEmpty =>
      _localizedValues[locale.languageCode]!['inviteListEmpty']!;
  String get inviteRevoke =>
      _localizedValues[locale.languageCode]!['inviteRevoke']!;
  String get inviteRevokeSuccess =>
      _localizedValues[locale.languageCode]!['inviteRevokeSuccess']!;
  // Transfer mentor
  String get transferMentorTitle =>
      _localizedValues[locale.languageCode]!['transferMentorTitle']!;
  String get transferMentorConfirm =>
      _localizedValues[locale.languageCode]!['transferMentorConfirm']!;
  String get transferMentorSuccess =>
      _localizedValues[locale.languageCode]!['transferMentorSuccess']!;
  // Remove member
  String get removeMemberTitle =>
      _localizedValues[locale.languageCode]!['removeMemberTitle']!;
  String get removeMemberConfirm =>
      _localizedValues[locale.languageCode]!['removeMemberConfirm']!;
  String get removeMemberAction =>
      _localizedValues[locale.languageCode]!['removeMemberAction']!;
  String get removeMemberSuccess =>
      _localizedValues[locale.languageCode]!['removeMemberSuccess']!;
  String get memberJoinedLabel =>
      _localizedValues[locale.languageCode]!['memberJoinedLabel']!;
  // Report
  String get reportTitle =>
      _localizedValues[locale.languageCode]!['reportTitle']!;
  String get reportReasonLabel =>
      _localizedValues[locale.languageCode]!['reportReasonLabel']!;
  String get reportReasonHint =>
      _localizedValues[locale.languageCode]!['reportReasonHint']!;
  String get reportSubmit =>
      _localizedValues[locale.languageCode]!['reportSubmit']!;
  String get reportSuccess =>
      _localizedValues[locale.languageCode]!['reportSuccess']!;

  // Create Fellowship Screen
  String get createFellowshipTitle =>
      _localizedValues[locale.languageCode]!['createFellowshipTitle']!;
  String get createFellowshipHeading =>
      _localizedValues[locale.languageCode]!['createFellowshipHeading']!;
  String get createFellowshipSubtitle =>
      _localizedValues[locale.languageCode]!['createFellowshipSubtitle']!;
  String get createFellowshipNameLabel =>
      _localizedValues[locale.languageCode]!['createFellowshipNameLabel']!;
  String get createFellowshipNameHint =>
      _localizedValues[locale.languageCode]!['createFellowshipNameHint']!;
  String get createFellowshipDescLabel =>
      _localizedValues[locale.languageCode]!['createFellowshipDescLabel']!;
  String get createFellowshipDescHint =>
      _localizedValues[locale.languageCode]!['createFellowshipDescHint']!;
  String get createFellowshipMaxLabel =>
      _localizedValues[locale.languageCode]!['createFellowshipMaxLabel']!;
  String get createFellowshipButton =>
      _localizedValues[locale.languageCode]!['createFellowshipButton']!;
  String get createFellowshipSuccess =>
      _localizedValues[locale.languageCode]!['createFellowshipSuccess']!;
  String get createFellowshipFailed =>
      _localizedValues[locale.languageCode]!['createFellowshipFailed']!;
  String get createFellowshipNameError =>
      _localizedValues[locale.languageCode]!['createFellowshipNameError']!;
  String get createFellowshipDescError =>
      _localizedValues[locale.languageCode]!['createFellowshipDescError']!;
  String get createFellowshipMaxError =>
      _localizedValues[locale.languageCode]!['createFellowshipMaxError']!;

  // Discover tab
  String get discoverFilterAll =>
      _localizedValues[locale.languageCode]!['discoverFilterAll']!;
  String get discoverFilterEnglish =>
      _localizedValues[locale.languageCode]!['discoverFilterEnglish']!;
  String get discoverFilterHindi =>
      _localizedValues[locale.languageCode]!['discoverFilterHindi']!;
  String get discoverFilterMalayalam =>
      _localizedValues[locale.languageCode]!['discoverFilterMalayalam']!;
  String get discoverEmpty =>
      _localizedValues[locale.languageCode]!['discoverEmpty']!;
  String get discoverEmptyShowAll =>
      _localizedValues[locale.languageCode]!['discoverEmptyShowAll']!;
  String get discoverJoinButton =>
      _localizedValues[locale.languageCode]!['discoverJoinButton']!;
  String get discoverFull =>
      _localizedValues[locale.languageCode]!['discoverFull']!;
  String discoverJoinedSnackbar(String name) =>
      _localizedValues[locale.languageCode]!['discoverJoinedSnackbar']!
          .replaceAll('{name}', name);
  String discoverMembersCount(int count, int max) =>
      _localizedValues[locale.languageCode]!['discoverMembersCount']!
          .replaceAll('{count}', '$count')
          .replaceAll('{max}', '$max');
  String get createFellowshipLanguageLabel =>
      _localizedValues[locale.languageCode]!['createFellowshipLanguageLabel']!;
  String get createFellowshipMakePublicLabel => _localizedValues[
      locale.languageCode]!['createFellowshipMakePublicLabel']!;
  String get createFellowshipMakePublicHint =>
      _localizedValues[locale.languageCode]!['createFellowshipMakePublicHint']!;
  String get meetingsSyncBannerTitle =>
      _localizedValues[locale.languageCode]!['meetingsSyncBannerTitle']!;
  String get meetingsSyncCalendar =>
      _localizedValues[locale.languageCode]!['meetingsSyncCalendar']!;
  String get meetingsSyncReconnect =>
      _localizedValues[locale.languageCode]!['meetingsSyncReconnect']!;
  String get homeAssignPathMentor =>
      _localizedValues[locale.languageCode]!['homeAssignPathMentor']!;
  String get homeNoPathAssigned =>
      _localizedValues[locale.languageCode]!['homeNoPathAssigned']!;
  String get fellowshipRecentActivity =>
      _localizedValues[locale.languageCode]!['fellowshipRecentActivity']!;
  String get fellowshipViewAll =>
      _localizedValues[locale.languageCode]!['fellowshipViewAll']!;
  String get feedPostSomething =>
      _localizedValues[locale.languageCode]!['feedPostSomething']!;
  String get meetingsTitle =>
      _localizedValues[locale.languageCode]!['meetingsTitle']!;
  String get meetingsSchedule =>
      _localizedValues[locale.languageCode]!['meetingsSchedule']!;
  String get meetingsSchedulePrompt =>
      _localizedValues[locale.languageCode]!['meetingsSchedulePrompt']!;
  String get meetingsNoUpcoming =>
      _localizedValues[locale.languageCode]!['meetingsNoUpcoming']!;
  String meetingsNextNoTime(String title) =>
      _localizedValues[locale.languageCode]!['meetingsNextNoTime']!
          .replaceAll('{0}', title);
  String meetingsNextWithTime(String title, String time) =>
      _localizedValues[locale.languageCode]!['meetingsNextWithTime']!
          .replaceAll('{0}', title)
          .replaceAll('{1}', time);

  // First Century Christian Facts for Loading Screen
  String getLoadingFact(int index) {
    if (index < 1 || index > 60) return '';
    return _localizedValues[locale.languageCode]!['loading_fact_$index'] ?? '';
  }

  // Get all 60 facts as a list
  List<String> get allLoadingFacts {
    return List<String>.generate(
      60,
      (index) => getLoadingFact(index + 1),
    );
  }

  static const Map<String, Map<String, String>> _categoryTranslations = {
    'hi': {
      'Foundations': 'आधार',
      'Growth': 'विकास',
      'Service & Mission': 'सेवा और मिशन',
      'Apologetics': 'विश्वास की रक्षा',
      'Life & Relationships': 'जीवन और रिश्ते',
      'Theology': 'धर्मशास्त्र',
    },
    'ml': {
      'Foundations': 'അടിത്തറ',
      'Growth': 'വളർച്ച',
      'Service & Mission': 'സേവനവും ദൗത്യവും',
      'Apologetics': 'വിശ്വാസ സംരക്ഷണം',
      'Life & Relationships': 'ജീവിതവും ബന്ധങ്ങളും',
      'Theology': 'ദൈവശാസ്ത്രം',
    },
  };

  /// Returns the translated category name for the current locale.
  /// Falls back to the original English name if no translation exists.
  String translateLearningPathCategory(String category) {
    return _categoryTranslations[locale.languageCode]?[category] ?? category;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'hi', 'ml'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
