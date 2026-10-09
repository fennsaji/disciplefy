# Translation style guide (Hindi, Malayalam)

One vocabulary for the whole app, in both `lib/core/i18n/translations_*.dart` and the older `lib/core/localization/app_localizations.dart`. Use the terms below every time. Do not swap in a synonym on one screen only. `test/core/i18n/wording_guard_test.dart` enforces the main terms.

## Principles

- Use plain, spoken language: modern conversational Hindi and Malayalam, not literary or archaic words.
- Product terms may stay transliterated or in Latin script: Credits, Discipler, Streak, Plan, Upgrade, PDF, Quick read, Deep dive. What matters is using one form everywhere.
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
| Memory verses | Memory verses | स्मरण वचन | മനഃപാഠ വാക്യങ്ങൾ (singular വാക്യം) |
| Verse (counts, a single verse) | verse | आयत (counts), वचन (the Word, the daily verse, the Scripture tab) | വാക്യം; വചനം for the Word |
| Streak | Streak / {n}-day streak | स्ट्रीक / {n} दिन की स्ट्रीक | സ്റ്റ്രീക്ക് / {n} ദിവസ സ്റ്റ്രീക്ക് |
| Learning path | Learning path | लर्निंग पाथ (short form: पाथ) | പഠന പാത (short form: പാത) |
| Study guide | Study guide | स्टडी गाइड (feminine) | പഠന ഗൈഡ് |
| Discipler | Discipler | Discipler | Discipler |
| Talk to Discipler | Talk to Discipler | Discipler से बात करें | Discipler-നോട് സംസാരിക്കുക |
| Credits | Credits | क्रेडिट | ക്രെഡിറ്റ് / ക്രെഡിറ്റുകൾ |
| {n} study credits daily | 15 study credits daily | हर दिन 15 अध्ययन क्रेडिट | ദിവസവും 15 പഠന ക്രെഡിറ്റുകൾ |
| Plan | Plan | प्लान | പ്ലാൻ |
| Upgrade | Upgrade | अपग्रेड (करें) | അപ്‌ഗ്രേഡ് (with ZWNJ) |
| Fellowship | Fellowship | संगति | കൂട്ടായ്മ |
| Lesson | Lesson | पाठ | പാഠം |
| Quick read | Quick read | क्विक | ക്വിക്ക് |
| Standard / Full guide | Standard, Full guide | स्टैंडर्ड; पूरी गाइड | സ്റ്റാൻഡേർഡ്; പൂർണ ഗൈഡ് |
| Deep dive | Deep dive | डीप डाइव | ഡീപ് ഡൈവ് / ആഴത്തിലുള്ള പഠനം (in preview copy) |
| Follow-up question | Follow-up (question) | फॉलो-अप प्रश्न | തുടർചോദ്യം |
| See all | See all | सभी देखें | എല്ലാം കാണൂ |
| Due (review) | Due | दोहराना है | ബാക്കി |
| Done | Done | पूर्ण | പൂർത്തിയായി |
| Save (button) | Save | सेव करें | സേവ് ചെയ്യൂ |
| Saved (status) | Saved | सहेजा गया / सेव की गई | സേവ് ചെയ്തു |
| Resume | Resume | जारी रखें | തുടരുക |
| Trial | Trial | ट्रायल | ട്രയൽ |
| Recommended | Recommended | सुझाया गया | ശുപാർശ ചെയ്ത |
| Level: Beginner (key `seeker`) | Beginner | शुरुआती | തുടക്കക്കാരൻ |
| Level: Follower | Follower | अनुयायी | അനുയായി |
| Level: Disciple | Disciple | शिष्य | ശിഷ്യൻ |
| Level: Leader | Leader | नेता | നേതാവ് |

## Where we departed from the native reviewer, and why

- **Due, Malayalam: ബാക്കി, not ആവർത്തിക്കണം.** The reviewer was right that the old "ഇന്ന്" ("today") was wrong. But ആവർത്തിക്കണം is 111px wide and the chip slot is 64px. ബാക്കി ("pending") fits, and the onboarding preview already uses it ("3 ബാക്കി").
- **Full guide, Malayalam: പൂർണ ഗൈഡ്, not പൂർണ്ണ പഠന ഗൈഡ്.** The longer form does not fit the 140px lesson chip. The `lesson.full_guide` label also drops the "·" separator (`പൂർണ ഗൈഡ് {min} മി`) to fit.
- **walk_with_god, Malayalam: ദൈവത്തോടൊപ്പം നടക്കുക.** The reviewer's ദിവസവും ദൈവത്തോടൊപ്പം നടക്കുക overflows its 230px slot. We kept the verb, which was the reviewer's point, and dropped "daily".
- **keep_days_safe, Malayalam: {n} ദിവസ സ്റ്റ്രീക്ക് കാക്കൂ.** This is shorter than a "നിലനിർത്തൂ" phrasing and still says the streak is being kept.
- **See all paths, Malayalam: എല്ലാ പാതകളും (no verb).** Adding കാണൂ overflows the 140px header link. The bare "See all" link does get എല്ലാം കാണൂ.
- **Done, Hindi: पूर्ण.** This is the reviewer's first option. "पाठ पूरा" would wrongly read as "lesson complete" on the text-size sheet.
- **Verse, Hindi: आयत kept for counts and verse lists.** The reviewer flagged only the Scripture tab and the streak hint; both now say वचन. Replacing every आयत would change gender agreement in about 50 strings with no reviewer request behind it.
- **Streak, Malayalam: സ്റ്റ്രീക്ക്.** This reverses an earlier choice (തുടർച്ച) on the reviewer's recommendation. Adverbial "തുടർച്ചയായി" (continuously) stays where it means "in a row", not the streak noun.
- **Fellowship: संगति / കൂട്ടായ്മ (native words), not transliterated.** The reviewer allowed either form as long as one is used everywhere. Both runtimes already used the native word in most strings (Hindi about 56 to 25, Malayalam about 60 to 20), and it is the natural church word, so the transliterated forms were switched to it.
- **Save: सेव करें / സേവ് ചെയ്യൂ on buttons.** Hindi status messages keep सहेजा गया where they already read naturally.
