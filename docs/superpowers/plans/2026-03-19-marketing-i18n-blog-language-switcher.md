# Marketing i18n + Blog Language Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Translate all static content on the Pricing and About pages for Hindi/Malayalam, and add a language switcher to the blog filters.

**Architecture:** The `[locale]/layout.tsx` already provides `NextIntlClientProvider` for all locale routes — the fix is to make `[locale]/pricing` and `[locale]/about` render their components directly instead of re-exporting the English base page. Content moves from hardcoded strings into the three message files, consumed via `useTranslations()`. The blog language switcher passes `locale` as a prop (no `useTranslations` in filters — avoids provider issues on the English base route).

**Tech Stack:** Next.js 14 App Router, next-intl v3, TypeScript, framer-motion (existing)

**Spec:** `docs/superpowers/specs/2026-03-19-marketing-i18n-blog-language-switcher-design.md`

**Working directory for all commands:** `marketing/`

---

## Task 1: Add translation keys to all three message files

**Files:**
- Modify: `marketing/messages/en.json`
- Modify: `marketing/messages/hi.json`
- Modify: `marketing/messages/ml.json`

> ⚠️ All edits are MERGES — add new top-level keys `"pricingPage"` and `"about"`, and merge new keys into the existing `"blog"` object. Do NOT replace existing content.

- [ ] **Step 1: Add `pricingPage` and `about` keys to `en.json`, and merge into `blog`**

Open `marketing/messages/en.json`. Add the following at the top level (after the last existing key, before the closing `}`):

```json
  "pricingPage": {
    "pageTitle": "Simple, Affordable Plans",
    "pageSubtitle": "Start free. Upgrade when you need more.",
    "faqTitle": "Frequently Asked Questions",
    "ctaText": "Ready to start your Bible study journey?",
    "startFreeNoCard": "Start Free — No Credit Card Required",
    "getStarted": "Get Started",
    "startFree": "Start Free",
    "mostPopular": "Most Popular",
    "perMonth": "/mo",
    "plans": [
      {
        "name": "Free",
        "price": 0,
        "tokens": "8 tokens/day",
        "popular": false,
        "features": [
          "Quick Read study guide mode",
          "3 memory verses",
          "2 practice modes",
          "1 practice per verse/day",
          "Token top-ups available",
          "Daily verse"
        ]
      },
      {
        "name": "Standard",
        "price": 79,
        "tokens": "20 tokens/day",
        "popular": false,
        "features": [
          "All study guide modes",
          "5 follow-up questions/day",
          "3 AI Discipler calls/month",
          "5 memory verses",
          "2 practices per verse/day",
          "Token top-ups available"
        ]
      },
      {
        "name": "Plus",
        "price": 149,
        "tokens": "50 tokens/day",
        "popular": true,
        "features": [
          "All study guide modes",
          "10 follow-up questions/day",
          "10 AI Discipler calls/month",
          "10 memory verses",
          "3 practices per verse/day",
          "Token top-ups available"
        ]
      },
      {
        "name": "Premium",
        "price": 499,
        "tokens": "Unlimited tokens",
        "popular": false,
        "features": [
          "All study guide modes",
          "Unlimited follow-up questions",
          "Unlimited AI Discipler calls",
          "Unlimited memory verses",
          "Unlimited practice",
          "Priority support"
        ]
      }
    ],
    "faqs": [
      {
        "q": "What is a token?",
        "a": "Tokens are the currency for AI features in Disciplefy. Each study guide, follow-up, or AI Discipler call uses a small number of tokens. Your plan resets your token count daily."
      },
      {
        "q": "Can I switch plans?",
        "a": "Yes, you can upgrade or downgrade at any time. Changes take effect at the start of your next billing cycle."
      },
      {
        "q": "How does payment work?",
        "a": "Payments are processed securely via Razorpay. We accept UPI, debit/credit cards, and net banking."
      },
      {
        "q": "Is my data safe?",
        "a": "Yes. We use Supabase Auth and follow India's DPDP 2023 guidelines. We never sell your data."
      },
      {
        "q": "What languages are supported?",
        "a": "English, Hindi, and Malayalam. All AI features including study guides and Voice Buddy work in all three languages."
      }
    ]
  },
  "about": {
    "title": "About Disciplefy",
    "mission": {
      "title": "Our Mission",
      "content": "We believe every believer deserves to understand God's Word in their heart language. Disciplefy exists to make deep, meaningful Bible study accessible to every Indian Christian — in English, Hindi, and Malayalam."
    },
    "vision": {
      "title": "Our Vision",
      "content": "To enable every Indian Christian to study Scripture deeply, daily, in the language they think and pray in. We envision a generation of believers who are rooted in God's Word and equipped to live it out in their communities."
    },
    "theology": {
      "title": "Theological Stance",
      "p1": "Disciplefy is built on orthodox Protestant Christian theology. All content is reviewed for doctrinal accuracy and follows historical-grammatical interpretation of Scripture. We hold to the foundational truths of the Christian faith as expressed in historic creeds.",
      "p2": "We do not replace the local church or its leadership. Disciplefy is a tool to complement your church community, Sunday school, and personal devotional life — not to substitute them."
    },
    "technology": {
      "title": "The Technology",
      "content": "Disciplefy uses AI to generate Bible study content — summaries, context, interpretation, prayer points, and discussion questions. The AI follows strict theological guidelines and all output is constrained to align with orthodox Christian teaching. The AI assists study; it does not interpret Scripture with authority. That authority belongs to Scripture alone."
    },
    "contact": {
      "title": "Contact Us",
      "text": "Questions, partnerships, or feedback:"
    }
  }
```

Also merge into the existing `"blog"` object (find `"blog": {` and add before its closing `}`):

```json
    "searchPlaceholder": "Search articles…",
    "allTag": "All"
```

- [ ] **Step 2: Add keys to `hi.json`**

Add to `marketing/messages/hi.json`:

```json
  "pricingPage": {
    "pageTitle": "सरल, किफायती योजनाएं",
    "pageSubtitle": "मुफ्त शुरू करें। जब अधिक की जरूरत हो तो अपग्रेड करें।",
    "faqTitle": "अक्सर पूछे जाने वाले प्रश्न",
    "ctaText": "आज अपनी बाइबल अध्ययन यात्रा शुरू करने के लिए तैयार हैं?",
    "startFreeNoCard": "मुफ्त में शुरू करें — कोई क्रेडिट कार्ड आवश्यक नहीं",
    "getStarted": "शुरू करें",
    "startFree": "मुफ्त शुरू करें",
    "mostPopular": "सबसे लोकप्रिय",
    "perMonth": "/माह",
    "plans": [
      {
        "name": "मुफ्त",
        "price": 0,
        "tokens": "8 टोकन/दिन",
        "popular": false,
        "features": [
          "क्विक रीड अध्ययन मार्गदर्शिका मोड",
          "3 स्मृति पद",
          "2 अभ्यास मोड",
          "1 अभ्यास प्रति पद/दिन",
          "टोकन टॉप-अप उपलब्ध",
          "दैनिक पद"
        ]
      },
      {
        "name": "स्टैंडर्ड",
        "price": 79,
        "tokens": "20 टोकन/दिन",
        "popular": false,
        "features": [
          "सभी अध्ययन मार्गदर्शिका मोड",
          "5 फॉलो-अप प्रश्न/दिन",
          "3 AI डिसाइप्लर कॉल/माह",
          "5 स्मृति पद",
          "2 अभ्यास प्रति पद/दिन",
          "टोकन टॉप-अप उपलब्ध"
        ]
      },
      {
        "name": "प्लस",
        "price": 149,
        "tokens": "50 टोकन/दिन",
        "popular": true,
        "features": [
          "सभी अध्ययन मार्गदर्शिका मोड",
          "10 फॉलो-अप प्रश्न/दिन",
          "10 AI डिसाइप्लर कॉल/माह",
          "10 स्मृति पद",
          "3 अभ्यास प्रति पद/दिन",
          "टोकन टॉप-अप उपलब्ध"
        ]
      },
      {
        "name": "प्रीमियम",
        "price": 499,
        "tokens": "असीमित टोकन",
        "popular": false,
        "features": [
          "सभी अध्ययन मार्गदर्शिका मोड",
          "असीमित फॉलो-अप प्रश्न",
          "असीमित AI डिसाइप्लर कॉल",
          "असीमित स्मृति पद",
          "असीमित अभ्यास",
          "प्राथमिकता सहायता"
        ]
      }
    ],
    "faqs": [
      {
        "q": "टोकन क्या है?",
        "a": "टोकन Disciplefy में AI सुविधाओं की मुद्रा हैं। प्रत्येक अध्ययन मार्गदर्शिका, फॉलो-अप, या AI डिसाइप्लर कॉल में कुछ टोकन लगते हैं। आपकी योजना प्रतिदिन आपके टोकन को रीसेट करती है।"
      },
      {
        "q": "क्या मैं योजना बदल सकता हूं?",
        "a": "हां, आप किसी भी समय अपग्रेड या डाउनग्रेड कर सकते हैं। परिवर्तन आपके अगले बिलिंग चक्र की शुरुआत में प्रभावी होते हैं।"
      },
      {
        "q": "भुगतान कैसे काम करता है?",
        "a": "भुगतान Razorpay के माध्यम से सुरक्षित रूप से संसाधित किए जाते हैं। हम UPI, डेबिट/क्रेडिट कार्ड और नेट बैंकिंग स्वीकार करते हैं।"
      },
      {
        "q": "क्या मेरा डेटा सुरक्षित है?",
        "a": "हां। हम Supabase Auth का उपयोग करते हैं और भारत के DPDP 2023 दिशानिर्देशों का पालन करते हैं। हम आपका डेटा कभी नहीं बेचते।"
      },
      {
        "q": "कौन सी भाषाएं समर्थित हैं?",
        "a": "English, हिन्दी और मलयालम। सभी AI फीचर तीनों भाषाओं में काम करते हैं।"
      }
    ]
  },
  "about": {
    "title": "Disciplefy के बारे में",
    "mission": {
      "title": "हमारा मिशन",
      "content": "हम मानते हैं कि हर विश्वासी को ईश्वर के वचन को अपनी हृदय की भाषा में समझने का अधिकार है। Disciplefy हर भारतीय ईसाई के लिए गहरे, सार्थक बाइबल अध्ययन को सुलभ बनाने के लिए अस्तित्व में है — अंग्रेजी, हिंदी और मलयालम में।"
    },
    "vision": {
      "title": "हमारी दृष्टि",
      "content": "हर भारतीय ईसाई को उस भाषा में गहराई से, दैनिक पवित्र शास्त्र का अध्ययन करने में सक्षम बनाना जिसमें वे सोचते और प्रार्थना करते हैं। हम विश्वासियों की एक पीढ़ी की कल्पना करते हैं जो ईश्वर के वचन में जड़े हुए हैं और अपने समुदायों में उसे जीने के लिए सुसज्जित हैं।"
    },
    "theology": {
      "title": "धर्मशास्त्रीय स्थिति",
      "p1": "Disciplefy रूढ़िवादी प्रोटेस्टेंट ईसाई धर्मशास्त्र पर बनाया गया है। सभी सामग्री की सिद्धांत सटीकता के लिए समीक्षा की जाती है और पवित्र शास्त्र की ऐतिहासिक-व्याकरणिक व्याख्या का पालन करती है। हम ऐतिहासिक पंथों में व्यक्त ईसाई विश्वास की बुनियादी सच्चाइयों को मानते हैं।",
      "p2": "हम स्थानीय कलीसिया या उसके नेतृत्व की जगह नहीं लेते। Disciplefy आपके चर्च समुदाय, रविवार स्कूल और व्यक्तिगत भक्ति जीवन को पूरक बनाने का एक उपकरण है — उनका विकल्प नहीं।"
    },
    "technology": {
      "title": "तकनीक",
      "content": "Disciplefy बाइबल अध्ययन सामग्री उत्पन्न करने के लिए AI का उपयोग करता है — सारांश, संदर्भ, व्याख्या, प्रार्थना बिंदु, और चर्चा प्रश्न। AI सख्त धर्मशास्त्रीय दिशानिर्देशों का पालन करता है और सभी आउटपुट रूढ़िवादी ईसाई शिक्षा के साथ संरेखित करने के लिए सीमित है। AI अध्ययन में सहायता करता है; यह अधिकार से पवित्र शास्त्र की व्याख्या नहीं करता। वह अधिकार केवल पवित्र शास्त्र का है।"
    },
    "contact": {
      "title": "संपर्क करें",
      "text": "प्रश्न, साझेदारी, या प्रतिक्रिया:"
    }
  }
```

Also merge into the existing `"blog"` object in `hi.json`:

```json
    "searchPlaceholder": "लेख खोजें…",
    "allTag": "सभी"
```

- [ ] **Step 3: Add keys to `ml.json`**

Add to `marketing/messages/ml.json`:

```json
  "pricingPage": {
    "pageTitle": "ലളിതമായ, താങ്ങാനാവുന്ന പ്ലാനുകൾ",
    "pageSubtitle": "സൗജന്യമായി ആരംഭിക്കൂ. കൂടുതൽ ആവശ്യമുള്ളപ്പോൾ അപ്ഗ്രേഡ് ചെയ്യൂ.",
    "faqTitle": "പതിവ് ചോദ്യങ്ങൾ",
    "ctaText": "നിങ്ങളുടെ ബൈബിൾ പഠന യാത്ര ആരംഭിക്കാൻ തയ്യാറാണോ?",
    "startFreeNoCard": "സൗജന്യമായി ആരംഭിക്കൂ — ക്രെഡിറ്റ് കാർഡ് ആവശ്യമില്ല",
    "getStarted": "ആരംഭിക്കൂ",
    "startFree": "സൗജന്യമായി ആരംഭിക്കൂ",
    "mostPopular": "ഏറ്റവും ജനപ്രിയം",
    "perMonth": "/മാസം",
    "plans": [
      {
        "name": "സൗജന്യം",
        "price": 0,
        "tokens": "8 ടോക്കൺ/ദിവസം",
        "popular": false,
        "features": [
          "ക്വിക്ക് റീഡ് പഠന ഗൈഡ് മോഡ്",
          "3 മെമ്മറി വചനങ്ങൾ",
          "2 പ്രാക്ടീസ് മോഡുകൾ",
          "1 പ്രാക്ടീസ് പ്രതി വചനം/ദിവസം",
          "ടോക്കൺ ടോപ്പ്-അപ്പ് ലഭ്യമാണ്",
          "ദൈനിക വചനം"
        ]
      },
      {
        "name": "സ്റ്റാൻഡേർഡ്",
        "price": 79,
        "tokens": "20 ടോക്കൺ/ദിവസം",
        "popular": false,
        "features": [
          "എല്ലാ പഠന ഗൈഡ് മോഡുകളും",
          "5 ഫോളോ-അപ്പ് ചോദ്യങ്ങൾ/ദിവസം",
          "3 AI ഡിസൈപ്ലർ കോളുകൾ/മാസം",
          "5 മെമ്മറി വചനങ്ങൾ",
          "2 പ്രാക്ടീസ് പ്രതി വചനം/ദിവസം",
          "ടോക്കൺ ടോപ്പ്-അപ്പ് ലഭ്യമാണ്"
        ]
      },
      {
        "name": "പ്ലസ്",
        "price": 149,
        "tokens": "50 ടോക്കൺ/ദിവസം",
        "popular": true,
        "features": [
          "എല്ലാ പഠന ഗൈഡ് മോഡുകളും",
          "10 ഫോളോ-അപ്പ് ചോദ്യങ്ങൾ/ദിവസം",
          "10 AI ഡിസൈപ്ലർ കോളുകൾ/മാസം",
          "10 മെമ്മറി വചനങ്ങൾ",
          "3 പ്രാക്ടീസ് പ്രതി വചനം/ദിവസം",
          "ടോക്കൺ ടോപ്പ്-അപ്പ് ലഭ്യമാണ്"
        ]
      },
      {
        "name": "പ്രീമിയം",
        "price": 499,
        "tokens": "പരിധിയില്ലാത്ത ടോക്കണുകൾ",
        "popular": false,
        "features": [
          "എല്ലാ പഠന ഗൈഡ് മോഡുകളും",
          "പരിധിയില്ലാത്ത ഫോളോ-അപ്പ് ചോദ്യങ്ങൾ",
          "പരിധിയില്ലാത്ത AI ഡിസൈപ്ലർ കോളുകൾ",
          "പരിധിയില്ലാത്ത മെമ്മറി വചനങ്ങൾ",
          "പരിധിയില്ലാത്ത പ്രാക്ടീസ്",
          "മുൻഗണന പിന്തുണ"
        ]
      }
    ],
    "faqs": [
      {
        "q": "ഒരു ടോക്കൺ എന്താണ്?",
        "a": "ടോക്കണുകൾ Disciplefy-യിലെ AI ഫീച്ചറുകളുടെ കറൻസിയാണ്. ഓരോ പഠന ഗൈഡ്, ഫോളോ-അപ്പ്, അല്ലെങ്കിൽ AI ഡിസൈപ്ലർ കോൾ ചെറിയ ഒരു ടോക്കൺ സംഖ്യ ഉപയോഗിക്കുന്നു. നിങ്ങളുടെ പ്ലാൻ ദൈനിക ടോക്കൺ കൗണ്ട് പുനഃസ്ഥാപിക്കുന്നു."
      },
      {
        "q": "എനിക്ക് പ്ലാൻ മാറ്റാൻ കഴിയുമോ?",
        "a": "അതെ, നിങ്ങൾക്ക് ഏത് സമയത്തും അപ്ഗ്രേഡ് ചെയ്യാനോ ഡൗൺഗ്രേഡ് ചെയ്യാനോ കഴിയും. മാറ്റങ്ങൾ നിങ്ങളുടെ അടുത്ത ബില്ലിംഗ് ചക്രത്തിന്റെ തുടക്കത്തിൽ പ്രാബല്യത്തിൽ വരും."
      },
      {
        "q": "പേയ്‌മെന്റ് എങ്ങനെ പ്രവർത്തിക്കുന്നു?",
        "a": "Razorpay വഴി സുരക്ഷിതമായി പേയ്‌മെന്റ് പ്രോസസ് ചെയ്യുന്നു. ഞങ്ങൾ UPI, ഡെബിറ്റ്/ക്രെഡിറ്റ് കാർഡുകൾ, നെറ്റ് ബാങ്കിംഗ് സ്വീകരിക്കുന്നു."
      },
      {
        "q": "എന്റെ ഡേറ്റ സുരക്ഷിതമാണോ?",
        "a": "അതെ. ഞങ്ങൾ Supabase Auth ഉപയോഗിക്കുന്നു, ഇന്ത്യയുടെ DPDP 2023 മാർഗ്ഗനിർദ്ദേശങ്ങൾ പിന്തുടരുന്നു. ഞങ്ങൾ ഒരിക്കലും നിങ്ങളുടെ ഡേറ്റ വിൽക്കുന്നില്ല."
      },
      {
        "q": "ഏതൊക്കെ ഭാഷകൾ പിന്തുണയ്ക്കുന്നു?",
        "a": "English, Hindi, Malayalam. എല്ലാ AI ഫീച്ചറുകളും മൂന്ന് ഭാഷകളിലും പ്രവർത്തിക്കുന്നു."
      }
    ]
  },
  "about": {
    "title": "Disciplefy-യെക്കുറിച്ച്",
    "mission": {
      "title": "ഞങ്ങളുടെ ദൗത്യം",
      "content": "ഓരോ വിശ്വാസിക്കും ദൈവ വചനം അവരുടെ ഹൃദയ ഭാഷയിൽ മനസ്സിലാക്കാൻ അർഹതയുണ്ടെന്ന് ഞങ്ങൾ വിശ്വസിക്കുന്നു. Disciplefy ഓരോ ഇന്ത്യൻ ക്രിസ്ത്യാനിക്കും — ഇംഗ്ലീഷ്, ഹിന്ദി, മലയാളം എന്നിവയിൽ — ആഴമേറിയ, അർത്ഥവത്തായ ബൈബിൾ പഠനം ലഭ്യമാക്കാനാണ് നിലകൊള്ളുന്നത്."
    },
    "vision": {
      "title": "ഞങ്ങളുടെ കാഴ്ചപ്പാട്",
      "content": "ഓരോ ഇന്ത്യൻ ക്രിസ്ത്യാനിക്കും അവർ ചിന്തിക്കുകയും പ്രാർത്ഥിക്കുകയും ചെയ്യുന്ന ഭാഷയിൽ, ആഴത്തിൽ, ദൈനിക പവിത്ര ഗ്രന്ഥം പഠിക്കാൻ കഴിയുക. ദൈവ വചനത്തിൽ വേരൂന്നി, അവരുടെ സമൂഹങ്ങളിൽ അത് ജീവിക്കാൻ സജ്ജരായ ഒരു വിശ്വാസി തലമുറയെ ഞങ്ങൾ സ്വപ്നം കാണുന്നു."
    },
    "theology": {
      "title": "ദൈവശാസ്ത്ര നിലപാട്",
      "p1": "Disciplefy ഓർത്തഡോക്സ് പ്രൊട്ടസ്റ്റന്റ് ക്രിസ്ത്യൻ ദൈവശാസ്ത്രത്തിൽ ആധാരപ്പെട്ടതാണ്. എല്ലാ ഉള്ളടക്കവും സിദ്ധാന്ത കൃത്യതയ്ക്കായി അവലോകനം ചെയ്യുന്നു, ബൈബിളിന്റെ ചരിത്ര-വ്യാകരണ വ്യാഖ്യാനം പിന്തുടരുന്നു. ചരിത്ര വിശ്വാസ പ്രഖ്യാപനങ്ങളിൽ പ്രകടിപ്പിക്കപ്പെട്ട ക്രിസ്ത്യൻ വിശ്വാസത്തിന്റെ അടിസ്ഥാന സത്യങ്ങൾ ഞങ്ങൾ ഉൾക്കൊള്ളുന്നു.",
      "p2": "ഞങ്ങൾ ലോക്കൽ ചർച്ചിനെ അല്ലെങ്കിൽ അതിന്റെ നേതൃത്വത്തെ മാറ്റിസ്ഥാപിക്കുന്നില്ല. Disciplefy നിങ്ങളുടെ ചർച്ച് സമൂഹം, സൺഡേ സ്കൂൾ, വ്യക്തിഗത ഭക്തി ജീവിതം എന്നിവ പൂർത്തിയാക്കാനുള്ള ഒരു ഉപകരണമാണ് — അവയ്ക്ക് പകരമല്ല."
    },
    "technology": {
      "title": "സാങ്കേതികവിദ്യ",
      "content": "Disciplefy ബൈബിൾ പഠന ഉള്ളടക്കം സൃഷ്ടിക്കാൻ AI ഉപയോഗിക്കുന്നു — സംഗ്രഹങ്ങൾ, സന്ദർഭം, വ്യാഖ്യാനം, പ്രാർത്ഥനാ കുറിപ്പുകൾ, ചർച്ചാ ചോദ്യങ്ങൾ. AI കർശനമായ ദൈവശാസ്ത്ര മാർഗ്ഗനിർദ്ദേശങ്ങൾ പിന്തുടരുന്നു, എല്ലാ ഔട്ട്‌പുട്ടും ഓർത്തഡോക്സ് ക്രിസ്ത്യൻ പഠിപ്പിക്കൽ അനുസരിച്ച് നിയന്ത്രിക്കപ്പെടുന്നു. AI പഠനത്തെ സഹായിക്കുന്നു; ഇത് അധികാരത്തോടെ വേദഗ്രന്ഥം വ്യാഖ്യാനിക്കുന്നില്ല. ആ അധികാരം വേദഗ്രന്ഥം മാത്രത്തിന്റേതാണ്."
    },
    "contact": {
      "title": "ഞങ്ങളെ ബന്ധപ്പെടുക",
      "text": "ചോദ്യങ്ങൾ, പങ്കാളിത്തം, അല്ലെങ്കിൽ പ്രതികരണം:"
    }
  }
```

Also merge into the existing `"blog"` object in `ml.json`:

```json
    "searchPlaceholder": "ലേഖനങ്ങൾ തിരയൂ…",
    "allTag": "എല്ലാം"
```

- [ ] **Step 4: Verify JSON is valid**

```bash
cd marketing
node -e "JSON.parse(require('fs').readFileSync('messages/en.json','utf8')); console.log('en.json OK')"
node -e "JSON.parse(require('fs').readFileSync('messages/hi.json','utf8')); console.log('hi.json OK')"
node -e "JSON.parse(require('fs').readFileSync('messages/ml.json','utf8')); console.log('ml.json OK')"
```

Expected: each line prints `*.json OK`. If you get a SyntaxError, fix the JSON (usually a missing comma or bracket).

- [ ] **Step 5: Commit**

```bash
git add marketing/messages/en.json marketing/messages/hi.json marketing/messages/ml.json
git commit -m "feat(marketing): add pricingPage, about, and blog i18n keys for all locales"
```

---

## Task 2: Update PricingPageContent to use translations

**Files:**
- Modify: `marketing/components/sections/PricingPageContent.tsx`

The component currently has hardcoded `plans` and `faqs` arrays and all string literals. Replace all of this with `useTranslations('pricingPage')`.

- [ ] **Step 1: Replace the entire file content**

Replace `marketing/components/sections/PricingPageContent.tsx` with:

```tsx
// marketing/components/sections/PricingPageContent.tsx
"use client";
import { motion } from "framer-motion";
import { useTranslations } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

interface PricingPlan {
  name: string;
  price: number;
  tokens: string;
  popular: boolean;
  features: string[];
}

interface FAQ {
  q: string;
  a: string;
}

export function PricingPageContent({ jsonLd }: { jsonLd: string }) {
  const t = useTranslations("pricingPage");
  const plans = t.raw("plans") as PricingPlan[];
  const faqs = t.raw("faqs") as FAQ[];

  return (
    <>
      <Navbar />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: jsonLd }}
      />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        {/* Header */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="font-display font-extrabold text-4xl sm:text-5xl text-center mb-4"
        >
          {t("pageTitle")}
        </motion.h1>
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="text-[var(--muted)] text-center text-lg mb-16"
        >
          {t("pageSubtitle")}
        </motion.p>

        {/* Pricing grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-24">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: index * 0.1 }}
              whileHover={{ y: plan.popular ? -6 : -3, transition: { duration: 0.2 } }}
              className={`relative flex flex-col rounded-2xl border p-6 snap-start shrink-0 w-72 md:w-auto ${
                plan.popular
                  ? "border-primary bg-primary/10 shadow-xl shadow-primary/20"
                  : "border-[var(--border)] bg-[var(--surface)]"
              }`}
            >
              {plan.popular && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 bg-primary text-white text-xs font-bold px-3 py-1 rounded-full">
                  {t("mostPopular")}
                </span>
              )}
              <p className="font-display font-bold text-xl mb-1">{plan.name}</p>
              <p className="text-3xl font-extrabold text-primary mb-1">
                ₹{plan.price}
                <span className="text-sm font-normal text-[var(--muted)]">{t("perMonth")}</span>
              </p>
              <p className="text-xs text-[var(--muted)] mb-6">{plan.tokens}</p>
              <ul className="space-y-2 flex-1 mb-8">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-[var(--muted)]">
                    <span className="text-primary mt-0.5">✓</span> {f}
                  </li>
                ))}
              </ul>
              <a
                href="https://app.disciplefy.in"
                className={`block text-center py-3 rounded-xl font-semibold text-sm transition-colors ${
                  plan.popular
                    ? "bg-primary text-white hover:bg-primary-hover"
                    : "border border-[var(--border)] hover:border-primary text-[var(--text)]"
                }`}
              >
                {plan.price === 0 ? t("startFree") : t("getStarted")}
              </a>
            </motion.div>
          ))}
        </div>

        {/* FAQ */}
        <div className="max-w-2xl mx-auto">
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="font-display font-bold text-2xl text-center mb-10"
          >
            {t("faqTitle")}
          </motion.h2>
          <div className="space-y-6">
            {faqs.map((faq, index) => (
              <motion.div
                key={faq.q}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-30px" }}
                transition={{ duration: 0.4, delay: index * 0.05 }}
                className="border-b border-[var(--border)] pb-6"
              >
                <p className="font-semibold mb-2">{faq.q}</p>
                <p className="text-sm text-[var(--muted)] leading-relaxed">{faq.a}</p>
              </motion.div>
            ))}
          </div>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="text-center mt-12"
          >
            <p className="text-sm text-[var(--muted)] mb-4">{t("ctaText")}</p>
            <a
              href="https://app.disciplefy.in"
              className="inline-flex items-center gap-2 bg-primary text-white px-8 py-4 rounded-xl font-semibold hover:bg-primary-hover transition-colors"
            >
              {t("startFreeNoCard")}
            </a>
          </motion.div>
        </div>
      </main>
      <Footer />
    </>
  );
}
```

- [ ] **Step 2: TypeScript check**

```bash
cd marketing
npx tsc --noEmit 2>&1 | head -30
```

Expected: no errors related to `PricingPageContent.tsx`. If there are errors, fix them before proceeding.

- [ ] **Step 3: Commit**

```bash
git add marketing/components/sections/PricingPageContent.tsx
git commit -m "feat(marketing): migrate PricingPageContent to useTranslations"
```

---

## Task 3: Update AboutPageContent to use translations

**Files:**
- Modify: `marketing/components/sections/AboutPageContent.tsx`

- [ ] **Step 1: Replace the entire file content**

Replace `marketing/components/sections/AboutPageContent.tsx` with:

```tsx
// marketing/components/sections/AboutPageContent.tsx
"use client";
import { motion } from "framer-motion";
import { useTranslations } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

export function AboutPageContent() {
  const t = useTranslations("about");

  const sections = [
    {
      title: t("mission.title"),
      content: [t("mission.content")],
    },
    {
      title: t("vision.title"),
      content: [t("vision.content")],
    },
    {
      title: t("theology.title"),
      content: [t("theology.p1"), t("theology.p2")],
    },
    {
      title: t("technology.title"),
      content: [t("technology.content")],
    },
  ];

  return (
    <>
      <Navbar />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="font-display font-extrabold text-4xl sm:text-5xl mb-8"
        >
          {t("title")}
        </motion.h1>

        {sections.map((section, index) => (
          <motion.section
            key={section.title}
            initial={{ opacity: 0, y: 25 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.5, delay: index * 0.08 }}
            className="mb-12"
          >
            <h2 className="font-display font-bold text-2xl mb-4 text-primary">{section.title}</h2>
            {section.content.map((paragraph, pIdx) => (
              <p
                key={pIdx}
                className={`text-[var(--muted)] leading-relaxed ${
                  index === 0 ? "text-lg" : ""
                } ${pIdx < section.content.length - 1 ? "mb-4" : ""}`}
              >
                {paragraph}
              </p>
            ))}
          </motion.section>
        ))}

        <motion.section
          initial={{ opacity: 0, y: 25 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-50px" }}
          transition={{ duration: 0.5, delay: 0.32 }}
        >
          <h2 className="font-display font-bold text-2xl mb-4 text-primary">{t("contact.title")}</h2>
          <p className="text-[var(--muted)]">
            {t("contact.text")}{" "}
            <a href="mailto:hello@disciplefy.in" className="text-primary underline">
              hello@disciplefy.in
            </a>
          </p>
        </motion.section>
      </main>
      <Footer />
    </>
  );
}
```

> Note: The `index === 0` check replaces the old `section.title === "Our Mission"` comparison — this correctly applies `text-lg` to the first section regardless of the translated title string.

- [ ] **Step 2: TypeScript check**

```bash
cd marketing
npx tsc --noEmit 2>&1 | head -30
```

Expected: no errors related to `AboutPageContent.tsx`.

- [ ] **Step 3: Commit**

```bash
git add marketing/components/sections/AboutPageContent.tsx
git commit -m "feat(marketing): migrate AboutPageContent to useTranslations"
```

---

## Task 4: Fix [locale]/pricing and [locale]/about pages

**Files:**
- Modify: `marketing/app/[locale]/pricing/page.tsx`
- Modify: `marketing/app/[locale]/about/page.tsx`

Both currently re-export the English base page. Replace them so they render the components directly — the `[locale]/layout.tsx` already provides the `NextIntlClientProvider` with the correct locale.

- [ ] **Step 1: Replace `[locale]/pricing/page.tsx`**

```tsx
// marketing/app/[locale]/pricing/page.tsx
import { PricingPageContent } from "@/components/sections/PricingPageContent";
import { pricingJsonLd } from "@/lib/seo";

export { metadata } from "@/app/pricing/page";

export default function LocalePricingPage() {
  return <PricingPageContent jsonLd={JSON.stringify(pricingJsonLd)} />;
}
```

- [ ] **Step 2: Replace `[locale]/about/page.tsx`**

```tsx
// marketing/app/[locale]/about/page.tsx
import { AboutPageContent } from "@/components/sections/AboutPageContent";

export { metadata } from "@/app/about/page";

export default function LocaleAboutPage() {
  return <AboutPageContent />;
}
```

- [ ] **Step 3: Verify TypeScript**

```bash
cd marketing
npx tsc --noEmit 2>&1 | head -30
```

Expected: no errors.

- [ ] **Step 4: Manual verification — start dev server and check Hindi pricing**

```bash
cd marketing
npm run dev
```

Visit `http://localhost:3000/hi/pricing` — the page should show Hindi text (सरल, किफायती योजनाएं, etc.).
Visit `http://localhost:3000/ml/pricing` — the page should show Malayalam text.
Visit `http://localhost:3000/pricing` — the page should still show English (unchanged).
Visit `http://localhost:3000/hi/about` — should show Hindi (Disciplefy के बारे में).
Visit `http://localhost:3000/ml/about` — should show Malayalam.

- [ ] **Step 5: Commit**

```bash
git add "marketing/app/[locale]/pricing/page.tsx" "marketing/app/[locale]/about/page.tsx"
git commit -m "feat(marketing): fix locale pricing and about pages to use locale-specific translations"
```

---

## Task 5: Add locale prop threading to BlogList and callers

**Files:**
- Modify: `marketing/components/blog/BlogList.tsx`
- Modify: `marketing/app/blog/page.tsx`
- Modify: `marketing/app/[locale]/blog/page.tsx`

`BlogFilters` needs the current locale passed as a prop (cannot use `useLocale()` on the English base route which is outside the `[locale]/layout.tsx` provider).

- [ ] **Step 1: Add `locale` prop to `BlogList`**

In `marketing/components/blog/BlogList.tsx`, update the props interface and pass `locale` to `BlogFilters`:

```tsx
export function BlogList({
  posts,
  pagination,
  basePath,
  tag,
  query,
  tags,
  locale,           // NEW
}: {
  posts: PostMeta[];
  pagination: Pagination;
  basePath: string;
  tag?: string;
  query?: string;
  tags: string[];
  locale: string;   // NEW
}) {
```

And update the `<BlogFilters>` call inside to pass it:

```tsx
<BlogFilters tags={tags} activeTag={tag} query={query} locale={locale} />
```

- [ ] **Step 2: Pass `locale="en"` from English base blog page**

In `marketing/app/blog/page.tsx`, add `locale="en"` to the `<BlogList>` call:

```tsx
  return (
    <BlogList
      posts={posts}
      pagination={pagination}
      basePath="/blog"
      tag={searchParams.tag}
      query={query}
      tags={tags}
      locale="en"
    />
  );
```

- [ ] **Step 3: Pass `locale={params.locale}` from locale blog page**

In `marketing/app/[locale]/blog/page.tsx`, add `locale={params.locale}` to the `<BlogList>` call:

```tsx
  return (
    <BlogList
      posts={posts}
      pagination={pagination}
      basePath={`/${params.locale}/blog`}
      tag={searchParams.tag}
      query={query}
      tags={tags}
      locale={params.locale}
    />
  );
```

- [ ] **Step 4: TypeScript check**

```bash
cd marketing
npx tsc --noEmit 2>&1 | head -30
```

Expected: error on `BlogFilters` saying `locale` prop is missing (because BlogFilters doesn't accept it yet). This is expected — Task 6 fixes it.

- [ ] **Step 5: Commit**

```bash
git add marketing/components/blog/BlogList.tsx marketing/app/blog/page.tsx "marketing/app/[locale]/blog/page.tsx"
git commit -m "feat(marketing): thread locale prop through BlogList for language switcher"
```

---

## Task 6: Add language switcher to BlogFilters

**Files:**
- Modify: `marketing/components/blog/BlogFilters.tsx`

- [ ] **Step 1: Replace the entire file content**

```tsx
'use client'
// marketing/components/blog/BlogFilters.tsx
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useCallback, useTransition } from 'react'

const LOCALE_LABELS: Record<string, string> = {
  en: 'English',
  hi: 'हिन्दी',
  ml: 'മലയാളം',
}

const LOCALE_BASE_PATHS: Record<string, string> = {
  en: '/blog',
  hi: '/hi/blog',
  ml: '/ml/blog',
}

export function BlogFilters({
  tags,
  activeTag,
  query,
  locale,
}: {
  tags: string[]
  activeTag?: string
  query?: string
  locale: string
}) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [, startTransition] = useTransition()

  const pushParams = useCallback(
    (updates: Record<string, string | undefined>) => {
      const params = new URLSearchParams(searchParams.toString())
      params.delete('page')
      for (const [key, val] of Object.entries(updates)) {
        if (val) params.set(key, val)
        else params.delete(key)
      }
      startTransition(() => router.push(`${pathname}?${params.toString()}`))
    },
    [router, pathname, searchParams],
  )

  const switchLocale = useCallback(
    (newLocale: string) => {
      const params = new URLSearchParams(searchParams.toString())
      params.delete('page')
      const base = LOCALE_BASE_PATHS[newLocale] ?? '/blog'
      const qs = params.toString()
      startTransition(() => router.push(qs ? `${base}?${qs}` : base))
    },
    [router, searchParams],
  )

  return (
    <div className="flex flex-col gap-4 mb-8">
      {/* Language switcher */}
      <div className="flex flex-wrap gap-2">
        {Object.entries(LOCALE_LABELS).map(([loc, label]) => (
          <button
            key={loc}
            onClick={() => switchLocale(loc)}
            className={`px-3 py-1 rounded-full text-xs font-semibold transition-colors ${
              locale === loc
                ? 'bg-primary text-white'
                : 'bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:border-primary/40 hover:text-[var(--text)]'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center">
        {/* Search input */}
        <div className="relative flex-1 max-w-sm">
          <svg
            className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--muted)] pointer-events-none"
            fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}
          >
            <path strokeLinecap="round" strokeLinejoin="round"
              d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
          </svg>
          <input
            type="search"
            defaultValue={query}
            placeholder="Search articles…"
            className="w-full pl-9 pr-4 py-2 rounded-xl text-sm
                       bg-[var(--surface)] border border-[var(--border)]
                       text-[var(--text)] placeholder:text-[var(--muted)]
                       focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/30
                       transition-colors"
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                pushParams({ q: (e.target as HTMLInputElement).value.trim() || undefined, tag: undefined })
              }
            }}
            onChange={(e) => {
              const val = e.target.value.trim()
              if (val === '') pushParams({ q: undefined })
            }}
          />
        </div>

        {/* Tag pills */}
        {tags.length > 0 && (
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => pushParams({ tag: undefined, q: query })}
              className={`px-3 py-1 rounded-full text-xs font-semibold transition-colors ${
                !activeTag
                  ? 'bg-primary text-white'
                  : 'bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:border-primary/40 hover:text-[var(--text)]'
              }`}
            >
              All
            </button>
            {tags.map((t) => (
              <button
                key={t}
                onClick={() => pushParams({ tag: activeTag === t ? undefined : t, q: query })}
                className={`px-3 py-1 rounded-full text-xs font-semibold transition-colors ${
                  activeTag === t
                    ? 'bg-primary text-white'
                    : 'bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:border-primary/40 hover:text-[var(--text)]'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: TypeScript check — expect clean**

```bash
cd marketing
npx tsc --noEmit 2>&1 | head -30
```

Expected: no errors.

- [ ] **Step 3: Build check**

```bash
cd marketing
npm run build 2>&1 | tail -20
```

Expected: build completes with no errors (`✓ Compiled successfully` or similar).

- [ ] **Step 4: Manual verification — start dev server**

```bash
cd marketing
npm run dev
```

Verify:
- `http://localhost:3000/blog` — language pills show `[English ✓] [हिन्दी] [മലയാളം]`; clicking हिन्दी navigates to `/hi/blog` showing Hindi posts
- `http://localhost:3000/hi/blog` — pills show `[English] [हिन्दी ✓] [മലയാളം]`; clicking English navigates to `/blog`
- `http://localhost:3000/ml/blog` — pills show `[English] [हिन्दी] [മലയാളം ✓]`
- Tag filter still works after locale switch (params are preserved)
- `http://localhost:3000/hi/blog?tag=prayer` → click English → navigates to `/blog?tag=prayer`

- [ ] **Step 5: Commit**

```bash
git add marketing/components/blog/BlogFilters.tsx
git commit -m "feat(marketing): add language switcher to blog filters"
```

---

## Task 7: Commit spec and plan docs, create PR

**Files:**
- `docs/superpowers/specs/2026-03-19-marketing-i18n-blog-language-switcher-design.md`
- `docs/superpowers/plans/2026-03-19-marketing-i18n-blog-language-switcher.md`

- [ ] **Step 1: Commit docs**

```bash
git add docs/superpowers/specs/2026-03-19-marketing-i18n-blog-language-switcher-design.md
git add docs/superpowers/plans/2026-03-19-marketing-i18n-blog-language-switcher.md
git commit -m "docs: add marketing i18n and blog language switcher spec and plan"
```

- [ ] **Step 2: Push and create PR**

```bash
git push origin dev
gh pr create --title "feat(marketing): i18n for pricing/about pages + blog language switcher" \
  --body "$(cat <<'EOF'
## Summary
- Pricing and About pages now show translated content for Hindi and Malayalam visitors
- Blog filters include a language switcher (English | हिन्दी | മലയാളം) that preserves tag/search params on switch
- Translation keys added to all 3 message files under new `pricingPage` and `about` namespaces

## Test Plan
- [ ] Visit `/hi/pricing` — verify Hindi text for plans, FAQ, CTAs
- [ ] Visit `/ml/pricing` — verify Malayalam text
- [ ] Visit `/pricing` — verify English unchanged
- [ ] Visit `/hi/about` — verify Hindi text for all sections
- [ ] Visit `/ml/about` — verify Malayalam text
- [ ] Visit `/blog` — verify language pills, clicking हिन्दी goes to `/hi/blog`
- [ ] Visit `/hi/blog?tag=grace` — clicking English goes to `/blog?tag=grace`
EOF
)"
```
