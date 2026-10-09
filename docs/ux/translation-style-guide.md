# Translation style guide (Hindi, Malayalam)

One vocabulary for the whole app, in both `lib/core/i18n/translations_*.dart` and the older `lib/core/localization/app_localizations.dart`. Use the terms below every time. Do not swap in a synonym on one screen only. `test/core/i18n/wording_guard_test.dart` enforces the main terms.

## Principles

- Use plain, spoken language: modern conversational Hindi and Malayalam, not literary or archaic words.
- **Owner rule (October 2026): simple everyday Hindi / Malayalam over transliteration.** Transliterate only when the native word is literary or unclear, or when the English word is one people really use in everyday speech (क्रेडिट / ക്രെഡിറ്റ്, प्लान / പ്ലാൻ, अपग्रेड / അപ്‌ഗ്രേഡ്, സേവ്, ഗൈഡ്, PDF). Avoid literary Sanskritised words too (पवित्रशास्त्र in UI labels, स्मरण, मार्गदर्शिका). Discipler stays in Latin script. Use one form everywhere.
- **Discipler** is always written in Latin script. Hindi takes postpositions after a space ("Discipler से"). Malayalam joins suffixes with a hyphen ("Discipler-നോട്", "Discipler-ന്റെ").
- Owner decisions override reviewer suggestions:
  - One noun for path items: lesson, पाठ / പാഠം. Never "topic".
  - One currency: credits. Never "tokens".
  - No "AI" anywhere, and no XP on new-user surfaces.
  - No daily gate in the copy.
- Strings must fit:
  - Labels should stay within about 1.3x the English width and inside their slot. `short_string_audit_test` checks this and lists the exceptions.
  - Pick the shorter natural form over a longer, fuller one.
- Buttons use the polite imperative: Hindi "-ें / करें"; Malayalam "-ൂ" (കാണൂ, ചെയ്യൂ). Settings rows and feature names may use the dictionary form (-ുക).
- Do not re-translate Bible verse text. Verse text must match the app's licensed translation (Hindi OV, Malayalam BSI); fix typos only.

## Vocabulary

| Concept | English | Hindi | Malayalam |
|---|---|---|---|
| Memory verses | Memory verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ (singular വാക്യം) |
| Verse (counts, a single verse) | verse | आयत (counts), वचन (the Word, the daily verse, the Scripture tab) | വാക്യം; വചനം for the Word |
| Streak | Streak / {n}-day streak | स्ट्रीक (noun); counts: लगातार {n} दिन; stat label under a number: दिन लगातार | തുടർച്ച / {n} ദിവസ തുടർച്ച; {n} ദിവസം തുടർച്ചയായി! |
| Learning path | Learning path | सीखने का रास्ता / सीखने के रास्ते (short form: रास्ता / रास्ते) | പഠന പാത (short form: പാത) |
| Study guide | Study guide | अध्ययन गाइड (feminine) | പഠന ഗൈഡ് |
| Discipler | Discipler | Discipler | Discipler |
| Talk to Discipler | Talk to Discipler | Discipler से बात करें | Discipler-നോട് സംസാരിക്കുക |
| Credits | Credits | क्रेडिट | ക്രെഡിറ്റ് / ക്രെഡിറ്റുകൾ |
| {n} study credits daily | 15 study credits daily | हर दिन 15 अध्ययन क्रेडिट | ദിവസവും 15 പഠന ക്രെഡിറ്റുകൾ |
| Plan | Plan | प्लान | പ്ലാൻ |
| Upgrade | Upgrade | अपग्रेड (करें) | അപ്‌ഗ്രേഡ് (with ZWNJ) |
| Scripture (UI label) | Scripture | वचन; बाइबल in sentences (not पवित्रशास्त्र) | തിരുവെഴുത്ത് / വേദഭാഗം |
| Fellowship | Fellowship | संगति (owner-confirmed) | കൂട്ടായ്മ (owner-confirmed) |
| Lesson | Lesson | पाठ | പാഠം |
| Quick read | Quick read | छोटी पढ़ाई (mode name); छोटी on space-tight chips; "छोटी या पूरी गाइड" | വേഗ വായന |
| Standard (mode) / Full guide | Standard, Full guide | सामान्य / सामान्य पढ़ाई; पूरी गाइड (the Standard *plan* stays स्टैंडर्ड) | സാധാരണ / സാധാരണ പഠനം; പൂർണ ഗൈഡ് (the Standard *plan* stays സ്റ്റാൻഡേർഡ്) |
| Deep dive | Deep dive | गहरी पढ़ाई | ആഴത്തിൽ (short) / ആഴത്തിലുള്ള പഠനം |
| Follow-up question | Follow-up (question) | आगे के सवाल | തുടർചോദ്യം (one word) |
| Daily verse / Verse of the day | Daily verse | आज का वचन or दैनिक वचन (never आयत) | ഇന്നത്തെ വചനം or ദിനവചനം (not ദൈനിക / ദിവസത്തെ വചനം) |
| See all | See all | सभी देखें | എല്ലാം കാണൂ |
| Due (review) | Due | दोहराना है | ബാക്കി |
| Done (button) | Done | हो गया (status "x of y done" stays पूर्ण) | പൂർത്തിയായി |
| Save (button) | Save | सहेजें | സേവ് ചെയ്യൂ |
| Saved (status) | Saved | सहेजा गया / सहेजी गई | സേവ് ചെയ്തു |
| Resume | Resume | जारी रखें | തുടരുക |
| Trial | Trial | ट्रायल | ട്രയൽ |
| Recommended | Recommended | सुझाया गया | ശുപാർശ ചെയ്ത |
| Level: Beginner (key `seeker`) | Beginner | शुरुआती | തുടക്കക്കാരൻ |
| Level: Follower | Follower | अनुयायी | അനുയായി |
| Level: Disciple | Disciple | शिष्य | ശിഷ്യൻ |
| Level: Leader | Leader | नेता | നേതാവ് |
| Daily (credits, limit) | 15 daily credits, Daily limit | हर दिन 15 क्रेडिट; रोज़ की सीमा; label रोज़ | ദിവസവും 15 ക്രെഡിറ്റ്; ദിവസ പരിധി; label ദിവസവും |
| Limit | Limit | सीमा | പരിധി |
| Unlimited | Unlimited | असीमित | പരിധിയില്ലാത്ത |
| Best for … | Best for group leaders | … के लिए सबसे अच्छा (समूह के अगुवों, सक्रिय बाइबल विद्यार्थियों, पास्टरों और शिक्षकों) | … ക്ക് (ഗ്രൂപ്പ് നേതാക്കൾക്ക്, പാസ്റ്റർമാർക്കും അധ്യാപകർക്കും) |
| Features | Features | सुविधाएं / सुविधा | സവിശേഷതകൾ / സവിശേഷത |
| Free / Standard users | Free users | फ्री प्लान में …; स्टैंडर्ड प्लान में … | സൗജന്യ ഉപയോക്താക്കൾ; സ്റ്റാൻഡേർഡ് ഉപയോക്താക്കൾ |
| Current plan | Current plan | मौजूदा प्लान | നിലവിലെ പ്ലാൻ |
| Assign (a path) | Assign | सौंपें / सौंपा | — |
| History, Statistics | History, Statistics | इतिहास, आंकड़े | ചരിത്രം, കണക്കുകൾ |
| Delete, Edit, Cancel | Delete, Edit, Cancel | हटाएं, बदलें, रद्द करें | ഇല്ലാതാക്കൂ, തിരുത്തൂ, റദ്ദാക്കൂ |
| Practice | Practice | अभ्यास | പരിശീലനം |
| Preferences | Preferences | प्राथमिकताएं | മുൻഗണനകൾ |
| Disciplefy (app name) | Disciplefy | Disciplefy (Latin script) | Disciplefy (Latin script) |

## Where we departed from the native reviewer, and why

- **Due, Malayalam: ബാക്കി, not ആവർത്തിക്കണം.** The reviewer was right that the old "ഇന്ന്" ("today") was wrong. But ആവർത്തിക്കണം is 111px wide and the chip slot is 64px. ബാക്കി ("pending") fits, and the onboarding preview already uses it ("3 ബാക്കി").
- **Full guide, Malayalam: പൂർണ ഗൈഡ്, not പൂർണ്ണ പഠന ഗൈഡ്.** The longer form does not fit the 140px lesson chip. The `lesson.full_guide` label also drops the "·" separator (`പൂർണ ഗൈഡ് {min} മി`) to fit.
- **walk_with_god, Malayalam: ദൈവത്തോടൊപ്പം നടക്കുക.** The reviewer's ദിവസവും ദൈവത്തോടൊപ്പം നടക്കുക overflows its 230px slot. We kept the verb, which was the reviewer's point, and dropped "daily".
- **keep_days_safe, Malayalam: {n} ദിവസ തുടർച്ച കാക്കൂ.** This is shorter than a "നിലനിർത്തൂ" phrasing and still says the streak is being kept.
- **See all paths, Malayalam: എല്ലാ പാതകളും (no verb).** Adding കാണൂ overflows the 140px header link. The bare "See all" link does get എല്ലാം കാണൂ.
- **Done, Hindi: हो गया** (owner rule: simplest everyday word). पूर्ण stays only for a completion status such as "{n} में से {m} पूर्ण".
- **Verse, Hindi: आयत kept for counts and verse lists.** The reviewer flagged only the Scripture tab and the streak hint; both now say वचन. Replacing every आयत would change gender agreement in about 50 strings with no reviewer request behind it.
- **Streak, Malayalam: തുടർച്ച.** The owner's simple-words rule overrides the reviewer's സ്റ്റ്രീക്ക്; തുടർച്ച was the app's earlier word.
- **Streak, Hindi: स्ट्रीक as the noun, "लगातार {n} दिन" for counts.** The reviewer found the bare noun "लगातार दिन" unnatural, and Hindi has no simple single noun for a streak. With a number, "लगातार 5 दिन" is the most natural phrase.
- **Fellowship: संगति / കൂട്ടായ്മ (native words), not transliterated.** The owner confirmed this after the October localization review, whose terminology sheet suggested फेलोशिप / ഫെലോഷിപ്പ്. The reviewer allowed either form as long as one is used everywhere. Both runtimes already used the native word in most strings (Hindi about 56 to 25, Malayalam about 60 to 20), and it is the natural church word, so the transliterated forms were switched to it.
- **Save: सहेजें in Hindi** (everyday Hindi verb); **സേവ് ചെയ്യൂ in Malayalam** (a word people actually use).
- **Study guide, Malayalam: ഗൈഡ് kept.** ഗൈഡ് is an everyday Malayalam word, and പഠന സഹായി already names Discipler ("study helper") in the fellowship screens.

## Owner localization review (October 2026)

The owner's review spreadsheet was applied with one rule: change a string only when the sheet's text is better (more natural, more accurate, or fixes an error). Where the current text and the sheet are equally good, the current text stays. Per-row decisions are in `.superpowers/sdd/localization-review-apply-report.md`.

- **Kept, although the sheet's terminology guide differs:** संगति / കൂട്ടായ്മ for Fellowship; आयत for verse counts and lists; both बाइबल and बाइबिल spellings where they already read well; ക്രെഡിറ്റ് (singular) after numbers and in compounds; വേദഭാഗം for a Scripture passage.
- **Adopted for consistency:** the daily verse is never आयत in Hindi, and leftover "പഠന സഹായി" for a study guide now says പഠന ഗൈഡ്. (Its study-mode and learning-path changes were reversed by the owner simple-words pass below.)
- **Fit:** the reviewer's Malayalam "Choose quick or full guide" (with the verb) overflows the 280px intro step title, so it is വേഗ വായനയോ പൂർണ ഗൈഡോ (no verb; it fits the slot but needs a ratio exemption).

## Owner simple-words pass (October 2026)

The owner asked for simple everyday words over transliterations in both languages ("सीखने के रास्ते was fine"). This reversed several choices above:

- **Hindi:** लर्निंग पाथ / पाथ → सीखने का रास्ता / रास्ता; स्टडी गाइड → अध्ययन गाइड; स्मरण वचन → याद वचन; क्विक रीड / डीप डाइव → लघु पढ़ाई / गहरी पढ़ाई (Standard mode सामान्य); फॉलो-अप प्रश्न → आगे के सवाल; सेव करें → सहेजें; Done पूर्ण → हो गया; पवित्रशास्त्र in UI labels → वचन / बाइबल; streak counts → लगातार {n} दिन.
- **Malayalam:** സ്റ്റ്രീക്ക് → തുടർച്ച; ക്വിക്ക് റീഡ് / ഡീപ്പ് ഡൈവ് → വേഗ വായന / ആഴത്തിലുള്ള പഠനം (Standard mode സാധാരണ); സ്റ്റഡി → പഠനം; ഫോളോ-അപ്പ് → തുടർചോദ്യങ്ങൾ.
- **Kept:** संगति / കൂട്ടായ്മ; क्रेडिट / ക്രെഡിറ്റ്; प्लान / പ്ലാൻ (योजना reads as a government "scheme"); अपग्रेड / അപ്‌ഗ്രേഡ്; സേവ്; ഗൈഡ്; മനഃപാഠ വാക്യം (an everyday school word); the Standard / Premium plan names.

### Follow-up (October 2026)

- **Quick read, Hindi:** लघु पढ़ाई → छोटी पढ़ाई (chip छोटी). लघु is bookish.
- **Hindi leftovers from before both passes:** डेली → रोज़ / हर दिन; लिमिट → सीमा; बेस्ट → सबसे अच्छा; ग्रुप लीडर्स → समूह के अगुवे (the church word); एक्टिव स्टूडेंट्स → सक्रिय विद्यार्थी; पास्टर्स और टीचर्स → पास्टरों और शिक्षकों; फीचर(्स) → सुविधा(एं); असाइन → सौंपें; यूज़ / यूज़र्स → इस्तेमाल / "… प्लान में"; हिस्ट्री → इतिहास; स्टैटिस्टिक्स → आंकड़े; प्राइवेसी पॉलिसी → गोपनीयता नीति; डिलीट / एडिट / कैंसल → हटाएं / बदलें / रद्द करें; स्मृति → याद; स्वचालित प्रकटीकरण → अपने आप दिखाएं; डिसाइपलर / डिसाइपलफाई → Discipler / Disciplefy.
- **Malayalam leftovers:** ഡെയ്ലി → ദിവസവും / ദിവസ; ലിമിറ്റ് / അൺലിമിറ്റഡ് → പരിധി / പരിധിയില്ലാത്ത; ഫ്രീ യൂസേഴ്‌സ് → സൗജന്യ ഉപയോക്താക്കൾ; ലീഡർസ് → നേതാക്കൾ; ടീച്ചർ → അധ്യാപകൻ; ഫീച്ചർ → സവിശേഷത; പ്രാക്ടീസ് → പരിശീലനം; ഹിസ്റ്ററി / സ്റ്റാറ്റിസ്റ്റിക്സ് → ചരിത്രം / കണക്കുകൾ; ഡിലീറ്റ് / എഡിറ്റ് / കാൻസൽ → ഇല്ലാതാക്കൂ / തിരുത്തൂ / റദ്ദാക്കൂ; ഡിസൈപ്പിൾഫൈ → Disciplefy. Garbled words from an old pass were fixed too (പ്രാതമ്യം / പ്രാപ്തരുകൾ → മുൻഗണന / മുൻഗണനകൾ, ശിഫാരസ്സു → ശുപാർശ, കുറവുന്നു → കുറയുന്നു, വേണംഎന്നാലും → വേണമെങ്കിലും, ലാഗൂ → ബാധകം, സുധാരണ ആവശ്യം → മെച്ചപ്പെടണം, തേർച്ച → തിരഞ്ഞെടുപ്പ്, പ്രഗതി → പുരോഗതി, and a Hindi "।" → ".").
- **Kept as everyday words:** लीडरबोर्ड / ലീഡർബോർഡ് (feature name), एक्सेस / ആക്‌സസ്, डिफ़ॉल्ट / ഡിഫോൾട്ട്, वॉयस / വോയ്സ്, रीसेट, सबमिट (Hindi), फीडबैक, पैकेज, इनवॉइस, प्रीमियम, ट्रायल, ലെവൽ, പ്രിവ്യൂ, ഡ്രാഫ്റ്റ്.
- **Left for an owner decision:** मेंटर / മെൻ്റർ (the fellowship role; some Hindi strings already say मार्गदर्शक), फ्रीज़ दिन / ഫ്രീസ് ദിനം (streak-freeze feature name), चैंपियन, the मास्टर / മാസ്റ്റർ mastery label.

`wording_guard_test` bans the replaced forms in both languages.
