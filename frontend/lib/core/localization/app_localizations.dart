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

      // Loading Screen Stages
      'loading_stage_preparing': 'Preparing your study guide...',
      'loading_stage_analyzing': 'Analyzing scripture context...',
      'loading_stage_gathering': 'Gathering insights...',
      'loading_stage_crafting': 'Crafting reflections...',
      'loading_stage_finalizing': 'Finalizing your guide...',

      // Loading Screen Time Estimate
      'loading_time_estimate': 'This usually takes 20-30 seconds',

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
