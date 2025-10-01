import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
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
          'AI-powered Bible study guides following Jeff Reed methodology',
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
