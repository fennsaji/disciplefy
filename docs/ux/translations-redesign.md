# Translations added or changed in the UX redesign

Source: `frontend/lib/core/i18n/translations_{en,hi,ml}.dart`, compared with the pre-redesign base. **New** = key did not exist; **Changed** = text edited. Grouped by feature (top-level key). Hindi and Malayalam follow `docs/ux/translation-style-guide.md` (vocabulary from the native-speaker review).

Totals: 1111 new, 360 changed, 90 features.


## ledger (117)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `activity` | New | Activity | गतिविधि | പ്രവർത്തനം |
| `avg_per_study` | New | avg / study | औसत / अध्ययन | ശരാശരി / പഠനം |
| `back_to_credits` | New | Back to credits | क्रेडिट पर वापस | ക്രെഡിറ്റുകളിലേക്ക് മടങ്ങൂ |
| `balance_subtitle` | New | Balance · {count} credits | बैलेंस · {count} क्रेडिट | ബാലൻസ് · {count} ക്രെഡിറ്റുകൾ |
| `billing` | New | Billing | बिलिंग | ബില്ലിംഗ് |
| `buy_cta` | New | Get {count} credits · {price} | {count} क्रेडिट लें · {price} | {count} ക്രെഡിറ്റുകൾ നേടൂ · {price} |
| `cancel_anytime_monthly` | New | Cancel anytime · billed monthly | कभी भी रद्द करें · मासिक बिलिंग | എപ്പോൾ വേണമെങ്കിലും റദ്ദാക്കാം · പ്രതിമാസ ബില്ലിംഗ് |
| `cancel_body` | New | If you cancel at the end of this cycle, you keep {plan} until {date}, then move to the Free plan. | इस चक्र के अंत में रद्द करने पर {date} तक {plan} बना रहेगा, फिर आप फ्री प्लान पर चले जाएंगे। | ഈ സൈക്കിളിന്റെ അവസാനം റദ്ദാക്കിയാൽ {date} വരെ {plan} തുടരും, തുടർന്ന് ഫ്രീ പ്ലാനിലേക്ക് മാറും. |
| `cancel_end` | New | Cancel at end of cycle | चक्र के अंत में रद्द करें | സൈക്കിൾ അവസാനം റദ്ദാക്കൂ |
| `cancel_end_sub` | New | Keep {plan} until {date} | {date} तक {plan} रखें | {date} വരെ {plan} നിലനിർത്തൂ |
| `cancel_eyebrow` | New | Cancel {plan} | {plan} रद्द करें | {plan} റദ്ദാക്കൂ |
| `cancel_now` | New | Cancel now | अभी रद्द करें | ഇപ്പോൾ റദ്ദാക്കൂ |
| `cancel_now_sub` | New | Lose {plan} today · no refund | आज ही {plan} खत्म · कोई रिफंड नहीं | ഇന്നുതന്നെ {plan} നഷ്ടമാകും · റീഫണ്ട് ഇല്ല |
| `cancel_plan` | New | Cancel plan | प्लान रद्द करें | പ്ലാൻ റദ്ദാക്കൂ |
| `cancel_title` | New | Keep studying until {date}? | {date} तक अध्ययन जारी रखें? | {date} വരെ പഠനം തുടരണോ? |
| `choose_pack` | New | Choose a pack | एक पैक चुनें | ഒരു പാക്ക് തിരഞ്ഞെടുക്കൂ |
| `choose_pack_or_amount` | New | Choose a pack or enter an amount | एक पैक चुनें या संख्या दर्ज करें | ഒരു പാക്ക് തിരഞ്ഞെടുക്കൂ അല്ലെങ്കിൽ എണ്ണം നൽകൂ |
| `confirm_cancel` | New | Confirm cancel | रद्द करना पक्का करें | റദ്ദാക്കൽ ഉറപ്പാക്കൂ |
| `copied` | New | Copied | कॉपी किया गया | പകർത്തി |
| `cost_label` | New | Cost | कीमत | വില |
| `credits` | New | credits | क्रेडिट | ക്രെഡിറ്റുകൾ |
| `credits_added` | New | +{count} credits added | +{count} क्रेडिट जोड़े गए | +{count} ക്രെഡിറ്റുകൾ ചേർത്തു |
| `credits_count` | New | {count} credits | {count} क्रेडिट | {count} ക്രെഡിറ്റുകൾ |
| `credits_label` | New | Credits | क्रेडिट | ക്രെഡിറ്റുകൾ |
| `credits_title` | New | Credits | क्रेडिट | ക്രെഡിറ്റുകൾ |
| `credits_used` | New | credits used | क्रेडिट उपयोग | ക്രെഡിറ്റുകൾ ഉപയോഗിച്ചു |
| `cta_with_price` | New | {label} · {price}/mo | {label} · {price}/माह | {label} · {price}/മാസം |
| `custom_hint` | New | Enter a number | संख्या दर्ज करें | ഒരു സംഖ്യ നൽകൂ |
| `custom_label` | New | How many credits? | कितने क्रेडिट? | എത്ര ക്രെഡിറ്റുകൾ? |
| `custom_rate` | New | {rate} credits for ₹1 · no discount | ₹1 में {rate} क्रेडिट · कोई छूट नहीं | ₹1-ന് {rate} ക്രെഡിറ്റുകൾ · ഇളവില്ല |
| `custom_tip` | New | Packs include a discount. | पैक में छूट मिलती है। | പാക്കുകൾക്ക് ഇളവുണ്ട്. |
| `daily_by_plan` | New | Daily credits by plan | प्लान के अनुसार दैनिक क्रेडिट | പ്ലാൻ അനുസരിച്ച് ദിവസേനയുള്ള ക്രെഡിറ്റുകൾ |
| `daily_credits` | New | Daily credits | दैनिक क्रेडिट | ദിവസേനയുള്ള ക്രെഡിറ്റുകൾ |
| `daily_plus_purchased` | New | Daily + {count} purchased | दैनिक + {count} खरीदे गए | ദിവസേന + {count} വാങ്ങിയത് |
| `date` | New | Date | तारीख | തീയതി |
| `details` | New | Details | विवरण | വിശദാംശങ്ങൾ |
| `downgrade` | New | Downgrade | डाउनग्रेड करें | ഡൗൺഗ്രേഡ് |
| `download_invoice` | New | Download invoice (PDF) | इनवॉइस डाउनलोड करें (PDF) | ഇൻവോയ്സ് ഡൗൺലോഡ് (PDF) |
| `follow_up` | New | Follow-up question | आगे के सवाल | തുടർചോദ്യം |
| `from_daily` | New | Daily | दैनिक | ദിവസേന |
| `from_purchased` | New | Purchased | खरीदे गए | വാങ്ങിയത് |
| `generating_pdf` | New | Generating PDF… | PDF बन रहा है… | PDF തയ്യാറാക്കുന്നു… |
| `get_credits` | New | Get credits | क्रेडिट लें | ക്രെഡിറ്റുകൾ നേടൂ |
| `hide_details` | New | Hide details | विवरण छिपाएं | വിശദാംശങ്ങൾ മറയ്ക്കൂ |
| `invoice_number` | New | Invoice {number} | इनवॉइस {number} | ഇൻവോയ്സ് {number} |
| `invoices_empty` | New | No payments yet | अभी कोई भुगतान नहीं | ഇതുവരെ പേയ്മെന്റുകളില്ല |
| `invoices_empty_body` | New | Your subscription payments will appear here. | आपके सदस्यता भुगतान यहां दिखेंगे। | നിങ്ങളുടെ സബ്സ്ക്രിപ്ഷൻ പേയ്മെന്റുകൾ ഇവിടെ കാണാം. |
| `invoices_error` | New | Couldn't load payments | भुगतान लोड नहीं हो सके | പേയ്മെന്റുകൾ ലോഡ് ചെയ്യാനായില്ല |
| `invoices_subtitle` | New | Subscription invoices | सदस्यता इनवॉइस | സബ്സ്ക്രിപ്ഷൻ ഇൻവോയ്സുകൾ |
| `invoices_title` | New | Payment history | भुगतान इतिहास | പേയ്മെന്റ് ചരിത്രം |
| `keep_plan` | New | Keep plan | प्लान रखें | പ്ലാൻ നിലനിർത്തൂ |
| `left_today` | New | {count} left today | आज {count} बचे | ഇന്ന് {count} ബാക്കി |
| `loading_plans` | New | Loading plans… | प्लान लोड हो रहे हैं… | പ്ലാനുകൾ ലോഡ് ചെയ്യുന്നു… |
| `loading_prices` | New | Loading prices… | कीमतें लोड हो रही हैं… | വിലകൾ ലോഡ് ചെയ്യുന്നു… |
| `most_used` | New | Most used | सबसे अधिक उपयोग | ഏറ്റവും കൂടുതൽ |
| `never_expire` | New | Credits never expire. Daily credits are used first. | क्रेडिट कभी समाप्त नहीं होते। पहले दैनिक क्रेडिट उपयोग होते हैं। | ക്രെഡിറ്റുകൾ കാലഹരണപ്പെടില്ല. ആദ്യം ദിവസേനയുള്ള ക്രെഡിറ്റുകൾ ഉപയോഗിക്കും. |
| `new_balance` | New | New balance: {count} credits | नया बैलेंस: {count} क्रेडिट | പുതിയ ബാലൻസ്: {count} ക്രെഡിറ്റുകൾ |
| `no_packs` | New | No packs available right now | अभी कोई पैक उपलब्ध नहीं है | ഇപ്പോൾ പാക്കുകളൊന്നും ലഭ്യമല്ല |
| `no_plans` | New | No plans available right now | अभी कोई प्लान उपलब्ध नहीं है | ഇപ്പോൾ പ്ലാനുകളൊന്നും ലഭ്യമല്ല |
| `of_total` | New | of {total} | {total} में से | {total}-ൽ |
| `order_id` | New | Order ID | ऑर्डर आईडी | ഓർഡർ ഐഡി |
| `packs_unavailable` | New | Credit packs are unavailable right now. Please try again later. | क्रेडिट पैक अभी उपलब्ध नहीं हैं। कृपया बाद में कोशिश करें। | ക്രെഡിറ്റ് പാക്കുകൾ ഇപ്പോൾ ലഭ്യമല്ല. പിന്നീട് ശ്രമിക്കൂ. |
| `paid` | New | Paid | भुगतान | അടച്ചത് |
| `paid_on` | New | Paid {date} | {date} को भुगतान | {date}-ന് അടച്ചു |
| `paid_with` | New | Paid with | भुगतान माध्यम | പേയ്മെന്റ് രീതി |
| `paise_per_credit` | New | {paise} paise/credit | {paise} पैसे/क्रेडिट | {paise} പൈസ/ക്രെഡിറ്റ് |
| `payment_failed` | New | Payment failed. Please try again. | भुगतान विफल रहा। कृपया फिर से कोशिश करें। | പേയ്മെന്റ് പരാജയപ്പെട്ടു. വീണ്ടും ശ്രമിക്കൂ. |
| `payment_id` | New | Payment ID | भुगतान आईडी | പേയ്മെന്റ് ഐഡി |
| `payment_pending` | New | Payment received — your credits will be added shortly. | भुगतान मिल गया — आपके क्रेडिट जल्द जोड़ दिए जाएंगे। | പേയ്മെന്റ് ലഭിച്ചു — ക്രെഡിറ്റുകൾ ഉടൻ ചേർക്കും. |
| `payment_successful` | New | Payment successful | भुगतान सफल | പേയ്മെന്റ് വിജയിച്ചു |
| `per_mo` | New | /mo | /माह | /മാസം |
| `per_month` | New | /month | /महीना | /മാസം |
| `percent_off` | New | {percent}% off | {percent}% छूट | {percent}% ഇളവ് |
| `plan_name` | New | {plan} plan | {plan} प्लान | {plan} പ്ലാൻ |
| `plans_error` | New | Couldn't load plans. Please try again. | प्लान लोड नहीं हो सके। कृपया फिर से कोशिश करें। | പ്ലാനുകൾ ലോഡ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കൂ. |
| `plans_subtitle` | New | Billed monthly · cancel anytime | मासिक बिलिंग · कभी भी रद्द करें | പ്രതിമാസ ബില്ലിംഗ് · എപ്പോൾ വേണമെങ്കിലും റദ്ദാക്കാം |
| `plans_title` | New | Choose your plan | अपना प्लान चुनें | നിങ്ങളുടെ പ്ലാൻ തിരഞ്ഞെടുക്കൂ |
| `plus_tagline` | New | Enhanced features for serious Bible students | गंभीर बाइबल विद्यार्थियों के लिए और बेहतर सुविधाएं | ഗൗരവമുള്ള ബൈബിൾ വിദ്യാർത്ഥികൾക്കായി മെച്ചപ്പെട്ട സവിശേഷതകൾ |
| `popular` | New | Popular | लोकप्रिय | ജനപ്രിയം |
| `premium_unlimited_body` | New | You don't need to buy credits. | आपको क्रेडिट खरीदने की ज़रूरत नहीं है। | നിങ്ങൾ ക്രെഡിറ്റുകൾ വാങ്ങേണ്ടതില്ല. |
| `premium_unlimited_title` | New | Premium includes unlimited credits | प्रीमियम में असीमित क्रेडिट शामिल हैं | പ്രീമിയത്തിൽ പരിധിയില്ലാത്ത ക്രെഡിറ്റുകൾ ഉണ്ട് |
| `price_renews` | New | {price}/month · renews {date} | {price}/महीना · {date} को नवीनीकरण | {price}/മാസം · {date}-ന് പുതുക്കും |
| `prices_error` | New | Couldn't load prices. Check your connection and try again. | कीमतें लोड नहीं हो सकीं। कनेक्शन जांचें और फिर से कोशिश करें। | വിലകൾ ലോഡ് ചെയ്യാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കൂ. |
| `purchase_paused_body` | New | Please check back later. | कृपया बाद में देखें। | പിന്നീട് വീണ്ടും നോക്കൂ. |
| `purchase_paused_title` | New | Buying credits is paused | क्रेडिट खरीदना रुका हुआ है | ക്രെഡിറ്റ് വാങ്ങൽ താൽക്കാലികമായി നിർത്തി |
| `purchased` | New | purchased | खरीदे गए | വാങ്ങിയത് |
| `purchases_count` | New | purchases | खरीदारी | വാങ്ങലുകൾ |
| `purchases_subtitle` | New | Credit packs | क्रेडिट पैक | ക്രെഡിറ്റ് പാക്കുകൾ |
| `purchases_title` | New | Purchases | खरीदारी | വാങ്ങലുകൾ |
| `receipt` | New | Receipt | रसीद | രസീത് |
| `recommended` | New | Recommended | अनुशंसित | ശുപാർശ ചെയ്യുന്നത് |
| `renews_note` | New | Renews monthly. Manage or cancel from My Plan. | हर महीने नवीनीकरण। मेरा प्लान से प्रबंधित या रद्द करें। | എല്ലാ മാസവും പുതുക്കും. എന്റെ പ്ലാനിൽ നിന്ന് നിയന്ത്രിക്കുകയോ റദ്ദാക്കുകയോ ചെയ്യാം. |
| `report_issue` | New | Report an issue | समस्या रिपोर्ट करें | പ്രശ്നം റിപ്പോർട്ട് ചെയ്യൂ |
| `resets_at` | New | Resets at {time} · in {left} | {time} पर रीसेट · {left} में | {time}-ന് റീസെറ്റ് · {left}-ൽ |
| `restore_purchases` | New | Restore purchases | खरीदारी पुनर्स्थापित करें | വാങ്ങലുകൾ പുനഃസ്ഥാപിക്കൂ |
| `since` | New | Since {date} | {date} से | {date} മുതൽ |
| `spent` | New | spent | खर्च | ചെലവ് |
| `standard_tagline` | New | Unlock powerful features for your Bible study | अपने बाइबल अध्ययन के लिए दमदार सुविधाएं पाएं | നിങ്ങളുടെ ബൈബിൾ പഠനത്തിന് ശക്തമായ സവിശേഷതകൾ |
| `start_study` | New | Start a study | अध्ययन शुरू करें | പഠനം തുടങ്ങൂ |
| `stats_error` | New | Couldn't load the summary | सारांश लोड नहीं हो सका | സംഗ്രഹം ലോഡ് ചെയ്യാനായില്ല |
| `status_active` | New | Active | सक्रिय | സജീവം |
| `status_failed` | New | Failed | विफल | പരാജയം |
| `status_pending` | New | Pending | लंबित | പെൻഡിംഗ് |
| `status_success` | New | Success | सफल | വിജയം |
| `studies` | New | studies | अध्ययन | പഠനങ്ങൾ |
| `study_costs_line` | New | Quick Read from 10 · Standard from 20 · Deep Dive from 30 · Follow-up 5. You see the exact cost before each study. | छोटी पढ़ाई 10 से · सामान्य 20 से · गहरी पढ़ाई 30 से · सवाल 5। हर अध्ययन से पहले सही कीमत दिखती है। | വേഗ വായന 10 മുതൽ · സാധാരണ 20 മുതൽ · ആഴത്തിലുള്ള പഠനം 30 മുതൽ · ചോദ്യം 5. ഓരോ പഠനത്തിനും മുമ്പ് കൃത്യമായ ചെലവ് കാണാം. |
| `study_costs_title` | New | What a study costs | एक अध्ययन की कीमत | ഒരു പഠനത്തിന്റെ ചെലവ് |
| `study_guide` | New | Study guide | अध्ययन गाइड | പഠന ഗൈഡ് |
| `subscriptions_paused` | New | New subscriptions are temporarily unavailable. Please check back later. | नई सदस्यताएं अस्थायी रूप से उपलब्ध नहीं हैं। कृपया बाद में देखें। | പുതിയ സബ്സ്ക്രിപ്ഷനുകൾ താൽക്കാലികമായി ലഭ്യമല്ല. പിന്നീട് നോക്കൂ. |
| `today` | New | Today | आज | ഇന്ന് |
| `total` | New | total | कुल | ആകെ |
| `unlimited_title` | New | Unlimited credits | असीमित क्रेडिट | പരിധിയില്ലാത്ത ക്രെഡിറ്റുകൾ |
| `upgrade` | New | Upgrade | अपग्रेड करें | അപ്‌ഗ്രേഡ് |
| `used_today` | New | used today | आज उपयोग | ഇന്ന് ഉപയോഗിച്ചത് |
| `what_you_get` | New | What you get | आपको क्या मिलता है | നിങ്ങൾക്ക് ലഭിക്കുന്നത് |
| `yesterday` | New | Yesterday | कल | ഇന്നലെ |
| `your_current_plan` | New | Your current plan | आपका मौजूदा प्लान | നിങ്ങളുടെ നിലവിലെ പ്ലാൻ |

## settings (85)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `account_actions` | Changed | Account Actions | खाते के विकल्प | അക്കൗണ്ട് പ്രവർ‍ത്തനങ്ങൾ |
| `app_language` | New | App language | ऐप भाषा | ആപ്പ് ഭാഷ |
| `app_language_description` | New | Menus, buttons and messages. Study content follows it unless you choose a content language. | मेनू, बटन और संदेश। जब तक आप अलग सामग्री भाषा न चुनें, अध्ययन सामग्री भी इसी भाषा में रहती है। | മെനുകൾ, ബട്ടണുകൾ, സന്ദേശങ്ങൾ. നിങ്ങൾ മറ്റൊരു ഉള്ളടക്ക ഭാഷ തിരഞ്ഞെടുക്കാത്തിടത്തോളം പഠന ഉള്ളടക്കവും ഈ ഭാഷയിലായിരിക്കും. |
| `app_version` | Changed | App version | ऐप संस्करण | ആപ്പ് പതിപ്പ് |
| `bible_attribution` | New | Bible copyright & attribution | बाइबल कॉपीराइट और श्रेय | ബൈബിൾ പകർപ്പവകാശവും കടപ്പാടും |
| `bible_attribution_subtitle` | New | Bible texts and licences | बाइबल अनुवाद और लाइसेंस | ബൈബിൾ പരിഭാഷകളും ലൈസൻസുകളും |
| `blocked_users` | Changed | Blocked users | ब्लॉक किए गए उपयोगकर्ता | ബ്ലോക്ക് ചെയ്ത ഉപയോക്താക്കൾ |
| `contact_us` | Changed | Contact us | हमसे संपर्क करें | ഞങ്ങളെ ബന്ധപ്പെടുക |
| `content_language` | Changed | Content language | सामग्री भाषा | ഉള്ളടക്ക ഭാഷ |
| `content_language_follows_app` | New | Same as app language ({language}) | ऐप भाषा जैसी ({language}) | ആപ്പ് ഭാഷ തന്നെ ({language}) |
| `content_language_same` | New | Same as app | ऐप जैसी | ആപ്പ് പോലെ |
| `delete_account` | Changed | Delete account | खाता हटाएं | അക്കൗണ്ട് ഇല്ലാതാക്കുക |
| `delete_account_confirm` | Changed | Delete my account | खाता हटाएं | അക്കൗണ്ട് ഇല്ലാതാക്കുക |
| `delete_account_keep` | New | Keep my account | अकाउंट रखें | അക്കൗണ്ട് നിലനിർത്തുക |
| `delete_account_lose_guides` | New | Your study guides and notes | आपकी अध्ययन गाइड और नोट्स | നിങ്ങളുടെ പഠന ഗൈഡുകളും കുറിപ്പുകളും |
| `delete_account_lose_plan` | New | Any active plan (cancel your subscription first) | कोई भी सक्रिय प्लान (पहले अपनी सदस्यता रद्द करें) | സജീവമായ ഏതു പ്ലാനും (ആദ്യം സബ്സ്ക്രിപ്ഷൻ റദ്ദാക്കുക) |
| `delete_account_lose_progress` | New | Your XP, level and achievements | आपके XP, स्तर और उपलब्धियाँ | നിങ്ങളുടെ XP, ലെവൽ, നേട്ടങ്ങൾ |
| `delete_account_lose_title` | New | You will permanently lose | आप हमेशा के लिए खो देंगे | നിങ്ങൾക്ക് സ്ഥിരമായി നഷ്ടപ്പെടും |
| `delete_account_lose_verses` | New | Your memory verses and streaks | आपके याद वचन और स्ट्रीक | നിങ്ങളുടെ മനഃപാഠ വാക്യങ്ങളും തുടർച്ചകളും |
| `delete_account_title` | Changed | Delete account | खाता हटाएं | അക്കൗണ്ട് ഇല്ലാതാക്കുക |
| `delete_account_type_to_confirm` | New | Type DELETE to confirm | पुष्टि के लिए DELETE लिखें | സ്ഥിരീകരിക്കാൻ DELETE എന്ന് ടൈപ്പ് ചെയ്യുക |
| `edit_name_failed` | New | Couldn't update your name. Please try again. | नाम अपडेट नहीं हो सका। कृपया दोबारा कोशिश करें। | പേര് അപ്ഡേറ്റ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `edit_name_hint` | New | Full name | पूरा नाम | മുഴുവൻ പേര് |
| `edit_name_invalid` | New | Enter at least 2 characters | कम से कम 2 अक्षर दर्ज करें | ചുരുങ്ങിയത് 2 അക്ഷരമെങ്കിലും നൽകുക |
| `edit_name_save` | New | Save | सहेजें | സേവ് ചെയ്യുക |
| `edit_name_success` | New | Name updated | नाम अपडेट हो गया | പേര് അപ്ഡേറ്റ് ചെയ്തു |
| `edit_name_title` | New | Your name | आपका नाम | നിങ്ങളുടെ പേര് |
| `error_updating_preference` | Changed | Failed to update preference | प्राथमिकता अपडेट करने में विफल | മുൻഗണന അപ്‌ഡേറ്റ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു |
| `guest_note` | New | You're using a guest account. Progress is saved on this phone. | आप मेहमान खाते पर हैं। प्रगति इसी फ़ोन में सहेजी है। | നിങ്ങൾ അതിഥി അക്കൗണ്ടിലാണ്. പുരോഗതി ഈ ഫോണിൽ സേവ് ആകുന്നു. |
| `help_support` | Changed | Help & support | सहायता और समर्थन | സഹായവും പിന്തുണയും |
| `language_default` | New | Default | डिफ़ॉल्ट | ഡിഫോൾട്ട് |
| `learning_path_study_mode_description` | Changed | Choose how you study path lessons | चुनें कि रास्ते के पाठ कैसे पढ़ें | പാതയിലെ പാഠങ്ങൾ എങ്ങനെ പഠിക്കണമെന്ന് തിരഞ്ഞെടുക്കൂ |
| `learning_path_study_mode_preference` | Changed | Learning path study mode | सीखने के रास्तों का अध्ययन मोड | പാത പഠന രീതി |
| `more` | New | More | और | കൂടുതൽ |
| `more_subtitle` | New | Study, help and legal | अध्ययन, मदद, नीतियाँ | പഠനം, സഹായം, നയങ്ങൾ |
| `my_plan` | Changed | My plan | मेरा प्लान | എന്റെ പ്ലാൻ |
| `notification_preferences` | Changed | Notification Preferences | नोटिफिकेशन प्राथमिकताएं | അറിയിപ്പ് മുൻഗണനകൾ |
| `notification_subtitle` | Changed | Manage daily verse and study reminders | दैनिक वचन और अध्ययन रिमाइंडर | ദിനവചനവും പഠന ഓർമ്മപ്പെടുത്തലുകളും |
| `offline_clear_all` | New | Clear all | सब हटाएँ | എല്ലാം മായ്ക്കുക |
| `offline_clear_all_message` | New | You can download them again from their learning paths. | आप इन्हें उनके सीखने के रास्ते से फिर डाउनलोड कर सकते हैं। | അവയുടെ പഠന പാതകളിൽ നിന്ന് വീണ്ടും ഡൗൺലോഡ് ചെയ്യാം. |
| `offline_clear_all_title` | New | Remove all offline guides? | सभी ऑफ़लाइन गाइड हटाएँ? | എല്ലാ ഓഫ്‌ലൈൻ ഗൈഡുകളും നീക്കണോ? |
| `offline_empty_subtitle` | New | Download a learning path to access it offline | ऑफ़लाइन पढ़ने के लिए कोई सीखने का रास्ता डाउनलोड करें | ഓഫ്‌ലൈനായി വായിക്കാൻ ഒരു പഠന പാത ഡൗൺലോഡ് ചെയ്യുക |
| `offline_empty_title` | New | No offline guides downloaded yet | अभी तक कोई ऑफ़लाइन गाइड डाउनलोड नहीं हुई | ഇതുവരെ ഓഫ്‌ലൈൻ ഗൈഡുകൾ ഡൗൺലോഡ് ചെയ്തിട്ടില്ല |
| `offline_guides` | New | Offline guides | ऑफ़लाइन गाइड | ഓഫ്‌ലൈൻ ഗൈഡുകൾ |
| `offline_guides_count` | New | {count} guides | {count} गाइड | {count} ഗൈഡുകൾ |
| `offline_guides_subtitle` | New | Read without internet | बिना इंटरनेट के पढ़ें | ഇന്റർനെറ്റ് ഇല്ലാതെ വായിക്കുക |
| `offline_path_empty` | New | No completed guides in this path | इस रास्ते में कोई पूरी गाइड नहीं है | ഈ പാതയിൽ പൂർത്തിയായ ഗൈഡുകളില്ല |
| `offline_path_progress` | New | {done} of {total} guides downloaded | {total} में से {done} गाइड डाउनलोड हुईं | {total}-ൽ {done} ഗൈഡുകൾ ഡൗൺലോഡ് ചെയ്തു |
| `offline_remove` | New | Remove | हटाएँ | നീക്കുക |
| `preference_updated_successfully` | Changed | Preference updated successfully | प्राथमिकता सफलतापूर्वक अपडेट की गई | മുൻഗണന വിജയകരമായി അപ്‌ഡേറ്റ് ചെയ്തു |
| `privacy_policy` | Changed | Privacy policy | गोपनीयता नीति | സ്വകാര്യതാ നീതി |
| `privacy_policy_subtitle` | Changed | View our privacy policy | हमारी गोपनीयता नीति देखें | ഞങ്ങളുടെ സ്വകാര്യതാ നീതി കാണുക |
| `reflection_journal` | Changed | Reflection journal | चिंतन डायरी | ചിന്തന ഡയറി |
| `refund_policy` | Changed | Cancellation & refunds | रिफंड नीति | റീഫണ്ട് നയം |
| `replay_walkthrough` | Changed | Replay app walkthrough | ऐप परिचय दोबारा देखें | ആപ്പ് ഗൈഡഡ് ടൂർ വീണ്ടും കാണുക |
| `replay_walkthrough_error` | Changed | Could not reset walkthrough — please try again. | परिचय रीसेट नहीं हो सका — कृपया फिर से प्रयास करें। | ഗൈഡഡ് ടൂർ റീസെറ്റ് ചെയ്യാനായില്ല — ദയവായി വീണ്ടും ശ്രമിക്കുക. |
| `replay_walkthrough_success` | Changed | Walkthrough reset — visit each screen to replay it | परिचय रीसेट हो गया — दोबारा देखने के लिए प्रत्येक स्क्रीन पर जाएं | ഗൈഡഡ് ടൂർ റീസെറ്റ് ചെയ്തു — വീണ്ടും കാണാൻ ഓരോ സ്ക്രീൻ സന്ദർശിക്കുക |
| `report_purchase_issue` | Changed | Report a purchase issue | खरीदारी समस्या रिपोर्ट करें | വാങ്ങൽ പ്രശ്നം റിപ്പോർട്ട് ചെയ്യുക |
| `retake_questionnaire` | Changed | Retake questionnaire | प्रश्नावली फिर से लें | ചോദ്യാവലി വീണ്ടും ചെയ്യുക |
| `retake_questionnaire_subtitle` | Changed | Update your path suggestions | रास्तों के सुझाव बदलें | പാത നിർദ്ദേശങ്ങൾ പുതുക്കുക |
| `save_progress` | New | Save progress to your account | प्रगति खाते में सहेजें | പുരോഗതി സേവ് ചെയ്യൂ |
| `save_progress_subtitle` | New | Keep your lessons on any phone | पाठ किसी भी फ़ोन पर रखें | പാഠങ്ങൾ ഏത് ഫോണിലും സൂക്ഷിക്കാം |
| `section_preferences` | New | Preferences | प्राथमिकताएँ | മുൻഗണനകൾ |
| `section_study` | New | Study | अध्ययन | പഠനം |
| `section_you` | New | You | आप | നിങ്ങൾ |
| `select_theme` | Changed | Select theme | थीम चुनें | ഥീം തിരഞ്ഞെടുക്കുക |
| `sign_in` | Changed | Sign in | साइन इन करें | സൈൻ ഇൻ ചെയ്യുക |
| `sign_out` | Changed | Sign out | साइन आउट करें | സൈൻ ഔട്ട് ചെയ്യുക |
| `sign_out_title` | Changed | Sign out | साइन आउट | സൈൻ ഔട്ട് ചെയ്യുക |
| `study_mode_preference` | Changed | Study mode preference | अध्ययन मोड प्राथमिकता | പഠന രീതി മുൻഗണന |
| `support` | Changed | Support | मदद करें | പിന്തുണയ്ക്കുക |
| `support_developer` | Changed | Support the developer | डेवलपर की मदद करें | ഡെവലപ്പറെ പിന്തുണയ്ക്കുക |
| `support_message` | Changed | Thank you for using Disciplefy! Your support helps us continue improving the app. If this app has blessed you or helped you in any way, and you'd like to encourage the work behind it, you can support it here by buying me a coffee. | Disciplefy का उपयोग करने के लिए धन्यवाद! आपकी मदद से हम ऐप बेहतर बना सकते हैं। अगर इस ऐप ने आपकी मदद की है, तो आप हमें एक कॉफी खरीदकर मदद कर सकते हैं। | Disciplefy ഉപയോഗിച്ചതിന് നന്ദി! നിങ്ങളുടെ പിന്തുണ ആപ്പ് മേല്‍പ്പെടുത്തുന്നതിന് ഞങ്ങളെ സഹായിക്കുന്നു. ഈ ആപ്പ് നിങ്ങളെ അനുഗ്രഹിച്ചിട്ടുണ്ടെങ്കിലോ ഏതെങ്കിലും സഹായിച്ചിട്ടുണ്ടെങ്കിലോ, അതിന് പിന്നിലെ പണി പ്രോത്സാഹിപ്പിക്കാൻ നിങ്ങൾ ആഗ്രഹിക്കുന്നുവെങ്കിൽ, എനിക്ക് ഒരു കോഫി വാങ്ങി ഇവിടെ പിന്തുണയ്ക്കാം. |
| `support_title` | Changed | Support the developer | डेवलपर की मदद करें | ഡെവലപ്പറെ പിന്തുണയ്ക്കുക |
| `terms_of_service` | Changed | Terms of use | सेवा की शर्तें | സേവന നിബന്ധനകൾ |
| `text_size` | Changed | Text size | पाठ आकार | ടെക്സ്റ്റ് വലുപ്പം |
| `text_size_extra_large` | Changed | Extra large | बहुत बड़ा | വളരെ വലുത് |
| `theme_dark` | New | Dark | डार्क | ഡാർക്ക് |
| `theme_light` | New | Light | लाइट | ലൈറ്റ് |
| `theme_system` | New | System | सिस्टम | സിസ്റ്റം |
| `theme_system_caption` | New | System follows your phone's light or dark setting. | सिस्टम आपके फ़ोन की लाइट या डार्क सेटिंग का पालन करता है। | സിസ്റ്റം നിങ്ങളുടെ ഫോണിന്റെ ലൈറ്റ് അല്ലെങ്കിൽ ഡാർക്ക് ക്രമീകരണം പിന്തുടരുന്നു. |
| `tip_thanks` | Changed | Thank you for supporting Disciplefy! 🙏 | Disciplefy की मदद करने के लिए धन्यवाद! 🙏 | Disciplefy-യെ പിന്തുണച്ചതിന് നന്ദി! 🙏 |
| `tip_unavailable` | Changed | Tips are unavailable right now. Please try again later. | सहयोग अभी उपलब्ध नहीं है। कृपया बाद में प्रयास करें। | സംഭാവന ഇപ്പോൾ ലഭ്യമല്ല. ദയവായി പിന്നീട് ശ്രമിക്കുക. |
| `use_recommended` | Changed | Use Recommended | अनुशंसित का उपयोग करें | ശുപാർശ ചെയ്ത രീതി ഉപയോഗിക്കുക |
| `use_recommended_subtitle` | Changed | Each path suggests the best study mode | हर रास्ता सबसे अच्छा अध्ययन मोड सुझाता है | ഓരോ പാതയും മികച്ച പഠന രീതി നിർദ്ദേശിക്കുന്നു |

## tokens (69)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `balance.daily` | Changed | Daily | रोज़ | ദിവസവും |
| `balance.daily_limit` | Changed | Daily Limit | रोज़ की सीमा | ദിവസ പരിധി |
| `balance.getting_low` | Changed | Getting Low | कम हो रहे हैं | കുറയുന്നു |
| `balance.limit` | Changed | Limit | सीमा | പരിധി |
| `balance.running_low` | Changed | Running Low | कम हो रहे हैं | കുറയുന്നു |
| `balance.used_today` | Changed | Used Today | आज इस्तेमाल हुए | ഇന്ന് ഉപയോഗിച്ചത് |
| `dialog.plan_credits_per_day` | New | {credits} credits/day — ₹{price}/month | {credits} क्रेडिट/दिन — ₹{price}/माह | {credits} ക്രെഡിറ്റ്/ദിവസം — ₹{price}/മാസം |
| `dialog.plan_unlimited` | New | Unlimited credits — ₹{price}/month | असीमित क्रेडिट — ₹{price}/माह | പരിധിയില്ലാത്ത ക്രെഡിറ്റ് — ₹{price}/മാസം |
| `history.empty` | Changed | No purchases yet | कोई खरीद इतिहास नहीं | വാങ്ങൽ ചരിത്രമില്ല |
| `history.title` | Changed | Purchase history | खरीद इतिहास | വാങ്ങൽ ചരിത്രം |
| `management.actions` | Changed | Credit Actions | क्रेडिट विकल्प | ക്രെഡിറ്റ് ഓപ്ഷനുകൾ |
| `management.failed_to_load` | Changed | Failed to load credit information | क्रेडिट जानकारी लोड नहीं हुई | ക്രെഡിറ്റ് വിവരം ലോഡ് ആയില്ല |
| `management.refresh` | Changed | Refresh credit status | क्रेडिट अपडेट करें | ക്രെഡിറ്റ് പുതുക്കൂ |
| `management.title` | Changed | Credit Management | क्रेडिट संभालें | ക്രെഡിറ്റ് നിയന്ത്രിക്കൂ |
| `management.upgrade_coming_soon` | Changed | Plan upgrade coming soon! | प्लान अपग्रेड जल्द आ रहा है! | പ്ലാൻ അപ്‌ഗ്രേഡ് ഉടൻ വരുന്നു! |
| `management.view_history` | Changed | View Purchase History | इतिहास देखें | ചരിത്രം കാണൂ |
| `management.view_usage_history` | Changed | View Usage History | उपयोग इतिहास देखें | ഉപയോഗ ചരിത്രം കാണൂ |
| `plans.current` | Changed | Current Plan | मौजूदा प्लान | നിലവിലെ പ്ലാൻ |
| `plans.current_plan` | Changed | Current Plan | मौजूदा प्लान | നിലവിലെ പ്ലാൻ |
| `plans.free_desc` | Changed | Best for daily Bible study | रोज़ के बाइबल अध्ययन के लिए सबसे अच्छा | ദിവസേനയുള്ള ബൈബിൾ പഠനത്തിന് |
| `plans.free_description` | Changed | Create Bible study guides with 15 daily credits. Best for regular daily study. | हर दिन 15 क्रेडिट से बाइबल अध्ययन गाइड बनाएं। रोज़ के अध्ययन के लिए सबसे अच्छा। | ദിവസവും 15 ക്രെഡിറ്റുകൾ, ദിവസേനയുള്ള ബൈബിൾ പഠനത്തിന്. |
| `plans.free_subtitle` | Changed | 15 Daily Credits | हर दिन 15 क्रेडिट | ദിവസവും 15 ക്രെഡിറ്റ് |
| `plans.manage` | Changed | Manage | प्रबंधित करें | നിയന്ത്രിക്കൂ |
| `plans.plus_desc` | Changed | Best for active Bible students | सक्रिय बाइबल विद्यार्थियों के लिए सबसे अच्छा | സജീവമായ ബൈബിൾ വിദ്യാർത്ഥികൾക്ക് |
| `plans.plus_description` | Changed | 60 daily credits plus ability to purchase more. Best for active Bible students. | हर दिन 60 क्रेडिट, और ज़्यादा खरीद सकते हैं। सक्रिय बाइबल विद्यार्थियों के लिए सबसे अच्छा। | ദിവസവും 60 ക്രെഡിറ്റുകൾ, കൂടുതൽ വാങ്ങാം. സജീവമായ ബൈബിൾ വിദ്യാർത്ഥികൾക്ക്. |
| `plans.plus_subtitle` | Changed | 60 Daily Credits + Buy More | हर दिन 60 क्रेडिट + खरीद सकते हैं | ദിവസവും 60 ക്രെഡിറ്റ് + വാങ്ങാം |
| `plans.premium_desc` | Changed | Best for pastors and teachers | पास्टरों और शिक्षकों के लिए सबसे अच्छा | പാസ്റ്റർമാർക്കും അധ്യാപകർക്കും |
| `plans.premium_description` | Changed | Create as many Bible study guides as you want. Best for pastors and teachers. | जितनी चाहें उतनी बाइबल अध्ययन गाइड बनाएं। पास्टरों और शिक्षकों के लिए सबसे अच्छा। | എത്ര വേണമെങ്കിലും ബൈബിൾ പഠിക്കാം. |
| `plans.standard_desc` | Changed | Best for group leaders | समूह के अगुवों के लिए सबसे अच्छा | ഗ്രൂപ്പ് നേതാക്കൾക്ക് |
| `plans.standard_description` | Changed | 40 daily credits plus ability to purchase more. Best for group leaders. | हर दिन 40 क्रेडिट, और ज़्यादा खरीद सकते हैं। समूह के अगुवों के लिए सबसे अच्छा। | ദിവസവും 40 ക്രെഡിറ്റുകൾ, കൂടുതൽ വാങ്ങാം. |
| `plans.standard_subtitle` | Changed | 40 Daily Credits + Buy More | हर दिन 40 क्रेडिट + खरीद सकते हैं | ദിവസവും 40 ക്രെഡിറ്റ് + വാങ്ങാം |
| `plans.upgrade_plan` | Changed | Upgrade Plan | प्लान अपग्रेड करें | പ്ലാൻ അപ്‌ഗ്രേഡ് ചെയ്യൂ |
| `plans.upgrade_premium` | Changed | Upgrade to Premium | प्रीमियम में अपग्रेड करें | പ്രീമിയത്തിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `plans.upgrade_standard` | Changed | Upgrade to Standard | स्टैंडर्ड में अपग्रेड करें | സ്റ്റാൻഡേർഡിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `plans.upgrade_to_premium` | Changed | Upgrade to Premium | प्रीमियम में अपग्रेड करें | പ്രീമിയത്തിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യൂ |
| `plans.upgrade_to_standard` | Changed | Upgrade to Standard | स्टैंडर्ड में अपग्रेड करें | സ്റ്റാൻഡേർഡിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യൂ |
| `purchase.custom` | Changed | Custom | अपनी राशि | സ്വന്തം തുക |
| `purchase.iap_success` | Changed | Purchase successful! {tokens} credits added to your account. | खरीदारी सफल! {tokens} क्रेडिट आपके खाते में जोड़े गए। | വാങ്ങൽ വിജയകരം! {tokens} ക്രെഡിറ്റുകൾ നിങ്ങളുടെ അക്കൗണ്ടിൽ ചേർത്തു. |
| `purchase.restricted_free` | Changed | Free users cannot purchase additional credits. Upgrade to Standard plan to buy extra credits or Premium for unlimited access. | फ्री प्लान में अतिरिक्त क्रेडिट नहीं खरीद सकते। स्टैंडर्ड प्लान में अपग्रेड करें या असीमित एक्सेस के लिए प्रीमियम लें। | സൗജന്യ ഉപയോക്താക്കൾക്ക് അധിക ക്രെഡിറ്റുകൾ വാങ്ങാൻ കഴിയില്ല. സ്റ്റാൻഡേർഡ് പ്ലാനിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക അല്ലെങ്കിൽ പരിധിയില്ലാത്ത ആക്‌സസിനായി പ്രീമിയം എടുക്കുക. |
| `purchase.restricted_premium` | Changed | Premium users have unlimited credits! No need to purchase additional credits. | प्रीमियम प्लान में असीमित क्रेडिट हैं! अतिरिक्त क्रेडिट खरीदने की ज़रूरत नहीं। | പ്രീമിയം ഉപയോക്താക്കൾക്ക് പരിധിയില്ലാത്ത ക്രെഡിറ്റുകളുണ്ട്! അധിക ക്രെഡിറ്റുകൾ വാങ്ങേണ്ട ആവശ്യമില്ല. |
| `purchase.restricted_standard` | Changed | Standard users can purchase additional credits. | स्टैंडर्ड प्लान में अतिरिक्त क्रेडिट खरीद सकते हैं। | സ്റ്റാൻഡേർഡ് ഉപയോക്താക്കൾക്ക് അധിക ക്രെഡിറ്റുകൾ വാങ്ങാം. |
| `purchase_dialog.custom` | Changed | Custom | अपनी राशि | ഇഷ്ടാനുസൃതം |
| `purchase_dialog.custom_tab` | Changed | Custom | अपनी राशि | ഇഷ്ടാനുസൃതം |
| `purchase_dialog.enter_custom` | Changed | Enter custom credit amount: | अपनी क्रेडिट राशि दर्ज करें: | ഇഷ്ടാനുസൃത ക്രെഡിറ്റ് തുക നൽകുക: |
| `purchase_dialog.last_used` | Changed | Last used | आखिरी बार इस्तेमाल | അവസാനം ഉപയോഗിച്ചത് |
| `purchase_dialog.subtitle` | Changed | Add more credits to continue generating study guides | अध्ययन गाइड बनाना जारी रखने के लिए और क्रेडिट जोड़ें | പഠന ഗൈഡുകൾ തുടർന്ന് സൃഷ്ടിക്കാൻ കൂടുതൽ ക്രെഡിറ്റുകൾ ചേർക്കുക |
| `purchase_dialog.upgrade_plan` | Changed | Upgrade Plan | प्लान अपग्रेड करें | പ്ലാൻ അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `soft_paywall.low_title` | Changed | Running low on credits | क्रेडिट कम हो रहे हैं | ക്രെഡിറ്റ് കുറയുന്നു |
| `stats.avg_per_operation` | Changed | Avg per Operation | प्रति उपयोग औसत | ഓരോ ഉപയോഗത്തിനും ശരാശരി |
| `stats.avg_per_token` | Changed | Average per credit | प्रति क्रेडिट औसत | ഓരോ ക്രെഡിറ്റിനും ശരാശരി |
| `stats.daily_available` | Changed | Daily Available | रोज़ उपलब्ध | ദിവസവും ലഭ്യം |
| `stats.daily_limit` | Changed | Daily Limit | रोज़ की सीमा | ദിവസ പരിധി |
| `stats.daily_tokens` | Changed | Daily | रोज़ | ദിവസവും |
| `stats.feature` | Changed | Feature | सुविधा | സവിശേഷത |
| `stats.feature_follow_ups` | New | Follow-up questions | आगे के सवाल | തുടർചോദ്യങ്ങൾ |
| `stats.feature_lessons` | New | Lessons | पाठ | പാഠങ്ങൾ |
| `stats.last_usage` | Changed | Last used | अंतिम उपयोग | അവസാന ഉപയോഗം |
| `stats.most_used` | Changed | Most Used | सबसे ज़्यादा इस्तेमाल | ഏറ്റവും കൂടുതൽ ഉപയോഗിച്ചത് |
| `stats.study_mode` | Changed | Study mode | अध्ययन मोड | പഠന മോഡ് |
| `stats.total_operations` | Changed | Total Operations | कुल उपयोग | മൊത്തം ഉപയോഗം |
| `stats.total_tokens_used` | Changed | Total Credits Used | कुल इस्तेमाल किए गए क्रेडिट | മൊത്തം ഉപയോഗിച്ച ക്രെഡിറ്റുകൾ |
| `stats.unlimited_description` | Changed | Create as many study guides as you want! | जितनी चाहें अध्ययन गाइड बनाएं! | എത്ര വേണമെങ്കിലും പഠന ഗൈഡ് ഉണ്ടാക്കൂ! |
| `stats.usage_info` | Changed | Usage Information | इस्तेमाल की जानकारी | ഉപയോഗ വിവരം |
| `stats.used_today` | Changed | Used Today | आज इस्तेमाल हुए | ഇന്ന് ഉപയോഗിച്ചത് |
| `usage.daily` | Changed | Daily | रोज़ | ദിവസവും |
| `usage.empty` | Changed | No Usage History | कोई उपयोग इतिहास नहीं | ഉപയോഗ ചരിത്രമില്ല |
| `usage.empty_message` | Changed | Your credit usage will appear here once you start generating study guides | जब आप अध्ययन गाइड बनाएंगे तो आपका क्रेडिट उपयोग यहां दिखाई देगा | നിങ്ങൾ പഠന ഗൈഡുകൾ സൃഷ്ടിക്കാൻ തുടങ്ങിയാൽ നിങ്ങളുടെ ക്രെഡിറ്റ് ഉപയോഗം ഇവിടെ ദൃശ്യമാകും |
| `usage.failed` | Changed | Failed to Load Usage History | उपयोग इतिहास लोड करने में विफल | ഉപയോഗ ചരിത്രം ലോഡ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു |
| `usage.title` | Changed | Usage history | उपयोग इतिहास | ഉപയോഗ ചരിത്രം |

## intro (64)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `close` | New | Close | बंद करें | അടയ്ക്കുക |
| `discipler.eyebrow` | New | Discipler | Discipler | Discipler |
| `discipler.primary` | New | Ask a question | सवाल पूछें | ചോദ്യം ചോദിക്കൂ |
| `discipler.question` | New | Why did Jesus have to die? | यीशु को क्यों मरना पड़ा? | യേശു എന്തിന് മരിക്കണമായിരുന്നു? |
| `discipler.secondary` | New | Not now | अभी नहीं | പിന്നീട് |
| `discipler.step1_body` | New | About a verse, a doctrine or daily life. | किसी वचन, शिक्षा या रोज़ के जीवन पर। | ഒരു വചനം, ഉപദേശം, ദൈനംദിന ജീവിതം. |
| `discipler.step1_title` | New | Ask anything | कुछ भी पूछें | എന്തും ചോദിക്കൂ |
| `discipler.step2_body` | New | Every answer shows the passages behind it. | हर जवाब के पीछे के वचन दिखते हैं। | ഓരോ മറുപടിയും അതിന്റെ വചനങ്ങൾ കാണിക്കും. |
| `discipler.step2_title` | New | Answers point you to Scripture | जवाब वचन दिखाते हैं | മറുപടി തിരുവചനത്തിലേക്ക് |
| `discipler.step3_body` | New | Tap "Ask about this" while you read. | पढ़ते समय "इस पर पूछें" दबाएँ। | വായിക്കുമ്പോൾ "ഇതിനെപ്പറ്റി ചോദിക്കൂ" തൊടൂ. |
| `discipler.step3_title` | New | Continue from any lesson | किसी भी पाठ से पूछें | ഏത് പാഠത്തിൽ നിന്നും |
| `discipler.title` | New | Ask your Bible questions | बाइबल के सवाल पूछें | ബൈബിൾ ചോദ്യങ്ങൾ ചോദിക്കാം |
| `fellowships.eyebrow` | New | Fellowships | संगति | കൂട്ടായ്മകൾ |
| `fellowships.join` | New | Join | जुड़ें | ചേരൂ |
| `fellowships.join_failed` | New | Could not join. Try again. | जुड़ नहीं सके। फिर कोशिश करें। | ചേരാനായില്ല. വീണ്ടും ശ്രമിക്കൂ. |
| `fellowships.member_one` | New | {n} member | {n} सदस्य | {n} അംഗം |
| `fellowships.members` | New | {n} members | {n} सदस्य | {n} അംഗങ്ങൾ |
| `fellowships.members_open` | New | {n} members · Open | {n} सदस्य · खुला | {n} അംഗങ്ങൾ · തുറന്നത് |
| `fellowships.official` | New | Official | आधिकारिक | ഔദ്യോഗികം |
| `fellowships.primary` | New | Join {name} | {name} से जुड़ें | {name} ചേരൂ |
| `fellowships.secondary` | New | Find or create a group | समूह खोजें या बनाएँ | ഗ്രൂപ്പ് കണ്ടെത്തൂ / തുടങ്ങൂ |
| `fellowships.step1_body` | New | Start with the open Disciplefy fellowship in your language, or your church's group. | अपनी भाषा की खुली Disciplefy संगति, या कलीसिया का समूह। | നിങ്ങളുടെ ഭാഷയിലെ Disciplefy കൂട്ടായ്മ, അല്ലെങ്കിൽ സഭയുടേത്. |
| `fellowships.step1_title` | New | Join a fellowship | संगति से जुड़ें | കൂട്ടായ്മയിൽ ചേരൂ |
| `fellowships.step2_body` | New | Everyone reads the same lesson each week. | हर हफ़्ते सब एक ही पाठ पढ़ते हैं। | എല്ലാവരും ഓരോ ആഴ്ചയും ഒരേ പാഠം വായിക്കും. |
| `fellowships.step2_title` | New | Follow the same lesson | एक ही पाठ पढ़ें | ഒരേ പാഠം |
| `fellowships.step3_body` | New | Post what stood out and pray for each other. | जो छुआ वह लिखें, एक-दूसरे के लिए प्रार्थना करें। | തോന്നിയത് പങ്കിടൂ, പരസ്പരം പ്രാർത്ഥിക്കൂ. |
| `fellowships.step3_title` | New | Share, pray and meet | बाँटें, प्रार्थना करें, मिलें | പങ്കിടാം, പ്രാർത്ഥിക്കാം |
| `fellowships.studying` | New | Studying | पढ़ रहे हैं | പഠിക്കുന്നത് |
| `fellowships.title` | New | Study together with your church or friends | कलीसिया या मित्रों के साथ पढ़ें | സഭയോടോ സുഹൃത്തുക്കളോടോ ഒപ്പം പഠിക്കാം |
| `generate.chip1` | New | Romans 8 | रोमियों 8 | റോമർ 8 |
| `generate.chip2` | New | Forgiveness | क्षमा | ക്ഷമ |
| `generate.chip3` | New | Psalm 23 | भजन संहिता 23 | സങ്കീർത്തനങ്ങൾ 23 |
| `generate.eyebrow` | New | Study anything | कुछ भी पढ़ें | എന്തും പഠിക്കാം |
| `generate.primary` | New | Start a study | अध्ययन शुरू करें | പഠനം തുടങ്ങൂ |
| `generate.secondary` | New | See an example | उदाहरण देखें | ഉദാഹരണം കാണൂ |
| `generate.step1_body` | New | A passage, a word, or something you are facing. | कोई अंश, शब्द, या आपकी स्थिति। | ഒരു ഭാഗം, ഒരു വാക്ക്, ഒരു സാഹചര്യം. |
| `generate.step1_title` | New | Type a verse or topic | वचन या विषय लिखें | വചനമോ വിഷയമോ |
| `generate.step2_body` | New | 3 minutes, or about 8 for the full study. | 3 मिनट, या पूरी गाइड के लिए लगभग 8। | 3 മിനിറ്റ്, പൂർണ്ണ പഠനത്തിന് ഏകദേശം 8. |
| `generate.step2_title` | New | Choose quick or full guide | छोटी या पूरी गाइड चुनें | വേഗ വായനയോ പൂർണ ഗൈഡോ |
| `generate.step3_body` | New | Keep guides to come back to later. | गाइड बाद के लिए रखें। | ഗൈഡുകൾ പിന്നീട് നോക്കാൻ സൂക്ഷിക്കാം. |
| `generate.step3_title` | New | Read, reflect, save | पढ़ें, सोचें, सहेजें | വായന, ധ്യാനം, സേവ് |
| `generate.title` | New | Study any passage or question on your mind | अपने मन में आए किसी भी वचन या सवाल का अध्ययन करें | മനസ്സിലുള്ള ഏത് വചനവും ചോദ്യവും പഠിക്കാം |
| `memory.eyebrow` | New | Memory verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |
| `memory.primary` | New | Practise this verse · 1 min | इस वचन का अभ्यास करें · 1 मिनट | ഈ വചനം പരിശീലിക്കൂ · 1 മി |
| `memory.saved` | New | Saved to your memory verses | याद वचनों में सहेजा गया | മനഃപാഠ വാക്യങ്ങളിൽ സേവ് ചെയ്തു |
| `memory.secondary` | New | Choose my own verse | अपना वचन चुनें | സ്വന്തം വചനം തിരഞ്ഞെടുക്കൂ |
| `memory.step1_body` | New | Pick one, or start with the suggestion below. | खुद चुनें, या नीचे वाले से शुरू करें। | സ്വയം എടുക്കാം, അല്ലെങ്കിൽ താഴെയുള്ളത്. |
| `memory.step1_title` | New | Save a verse | वचन सहेजें | വചനം ചേർക്കൂ |
| `memory.step2_body` | New | Fill the gaps, then type it from memory. | खाली जगह भरें, फिर याद से लिखें। | വിട്ടഭാഗം നിറയ്ക്കൂ, പിന്നെ ഓർമ്മയിൽ നിന്ന്. |
| `memory.step2_title` | New | Practise for one minute | एक मिनट अभ्यास करें | ഒരു മിനിറ്റ് പരിശീലിക്കൂ |
| `memory.step3_body` | New | Reviews get further apart as it sticks. | याद होने पर दोहराना कम होता है। | ഉറയ്ക്കുമ്പോൾ ഇടവേള കൂടും. |
| `memory.step3_title` | New | We bring it back | हम फिर याद दिलाएँगे | വീണ്ടും ഓർമ്മിപ്പിക്കും |
| `memory.title` | New | Hide God's word in your heart, a minute a day | रोज़ एक मिनट, परमेश्वर के वचन को अपने हृदय में रखें | ദിവസവും ഒരു മിനിറ്റ്, ദൈവവചനം ഹൃദയത്തിൽ സൂക്ഷിക്കൂ |
| `paths.eyebrow` | New | Learning paths | सीखने के रास्ते | പഠന പാതകൾ |
| `paths.primary` | New | Browse paths | रास्ते देखें | പാതകൾ കാണൂ |
| `paths.secondary` | New | Maybe later | बाद में | പിന്നീടാകാം |
| `paths.step1_body` | New | Foundations, Gospels, prayer, hard times and more. | नींव, सुसमाचार, प्रार्थना, कठिन समय और भी। | അടിസ്ഥാനം, സുവിശേഷം, പ്രാർത്ഥന എന്നിവയും മറ്റും. |
| `paths.step1_title` | New | Pick a path | रास्ता चुनें | പാത എടുക്കൂ |
| `paths.step2_body` | New | Quick read or full guide, about 3–5 minutes. | छोटी या पूरी गाइड, लगभग 3–5 मिनट। | വേഗ വായനയോ പൂർണ ഗൈഡോ, 3–5 മിനിറ്റ്. |
| `paths.step2_title` | New | One short lesson a day | रोज़ एक छोटा पाठ | ദിവസം ഒരു ചെറിയ പാഠം |
| `paths.step3_body` | New | See each step and pick up where you left off. | हर कदम देखें, वहीं से आगे बढ़ें। | നിർത്തിയിടത്തുനിന്ന് തുടരാം. |
| `paths.step3_title` | New | Track your progress | प्रगति देखें | പുരോഗതി കാണാം |
| `paths.title` | New | Grow step by step, one path at a time | एक-एक रास्ते से, कदम दर कदम बढ़ें | ഓരോ പാതയിലൂടെ പടിപടിയായി വളരാം |
| `start_with` | New | Start with | यहाँ से शुरू करें | ആദ്യം ഇത് |

## memory_screens (62)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `add_verse_subtitle` | New | Pick a passage or type your own | कोई अंश चुनें या खुद टाइप करें | ഒരു ഭാഗം തിരഞ്ഞെടുക്കുക അല്ലെങ്കിൽ സ്വയം ടൈപ്പ് ചെയ്യുക |
| `all_caught_up` | New | All caught up | सब पूरा हो गया | എല്ലാം പൂർത്തിയായി |
| `all_modes_unlocked` | New | All modes unlocked | सभी मोड खुले हैं | എല്ലാ മോഡുകളും തുറന്നിരിക്കുന്നു |
| `champions_subtitle` | New | Memory verse leaderboard | याद वचन लीडरबोर्ड | മനഃപാഠ വാക്യ ലീഡർബോർഡ് |
| `choose_book` | New | Choose a book | पुस्तक चुनें | പുസ്തകം തിരഞ്ഞെടുക്കുക |
| `choose_unlocked_modes` | New | Choose an unlocked mode | कोई अनलॉक मोड चुनें | അൺലോക്ക് ചെയ്ത ഒരു മോഡ് തിരഞ്ഞെടുക്കുക |
| `coming_up` | New | Coming up | आगामी | വരാനിരിക്കുന്നവ |
| `count_of_total` | New | {count} of {total} | {total} में से {count} | {total}-ൽ {count} |
| `daily_limit_reached` | New | Daily limit reached | दैनिक सीमा पूरी हुई | ദിവസ പരിധി എത്തി |
| `due_in_days` | New | In {count} days | {count} दिन में | {count} ദിവസത്തിനുള്ളിൽ |
| `due_today` | New | Due today | आज दोहराना है | ഇന്ന് ആവർത്തിക്കണം |
| `due_today_count` | New | {count} due today | आज {count} दोहराने हैं | ഇന്ന് {count} എണ്ണം ആവർത്തിക്കണം |
| `due_tomorrow` | New | Tomorrow | कल | നാളെ |
| `ease_factor` | New | Ease {value} | सरलता {value} | എളുപ്പം {value} |
| `how_it_works` | New | How it works | यह कैसे काम करता है | എങ്ങനെ പ്രവർത്തിക്കുന്നു |
| `mastered_count` | New | {count} mastered | {count} कंठस्थ | {count} മനഃപാഠം |
| `missed` | New | Missed: {words} | छूटे: {words} | വിട്ടുപോയത്: {words} |
| `mode_locked_upgrade` | New | Upgrade required | अपग्रेड आवश्यक | അപ്‌ഗ്രേഡ് ആവശ്യമാണ് |
| `modes_unlocked_today` | New | {count} of {limit} modes unlocked today | आज {limit} में से {count} मोड खुले | ഇന്ന് {limit}-ൽ {count} മോഡുകൾ തുറന്നു |
| `new_verse` | New | New | नया | പുതിയത് |
| `next_review_in_days` | New | Next review in {count} days | अगला दोहराव {count} दिन में | അടുത്ത ആവർത്തനം {count} ദിവസത്തിനുള്ളിൽ |
| `next_review_today` | New | Next review today | अगला दोहराव आज | അടുത്ത ആവർത്തനം ഇന്ന് |
| `next_review_tomorrow` | New | Next review tomorrow | अगला दोहराव कल | അടുത്ത ആവർത്തനം നാളെ |
| `no` | New | No | नहीं | ഇല്ല |
| `nothing_due` | New | Nothing due right now | अभी कुछ बाकी नहीं है | ഇപ്പോൾ ഒന്നും ബാക്കിയില്ല |
| `offline_body` | New | Memory Verses need an internet connection. Connect and come back. | याद वचनों के लिए इंटरनेट कनेक्शन चाहिए। कनेक्ट करके वापस आएँ। | മനഃപാഠ വാക്യങ്ങൾക്ക് ഇന്റർനെറ്റ് കണക്ഷൻ ആവശ്യമാണ്. കണക്റ്റ് ചെയ്ത് തിരികെ വരൂ. |
| `offline_title` | New | You're offline | आप ऑफ़लाइन हैं | നിങ്ങൾ ഓഫ്‌ലൈനാണ് |
| `overdue_days` | New | {count} days overdue | {count} दिन से बाकी | {count} ദിവസം വൈകി |
| `overdue_one_day` | New | 1 day overdue | 1 दिन से बाकी | 1 ദിവസം വൈകി |
| `practice_modes` | New | Practice modes | अभ्यास मोड | പരിശീലന മോഡുകൾ |
| `practices_count` | New | {count} practices | {count} अभ्यास | {count} പരിശീലനങ്ങൾ |
| `quality_good` | New | Good recall | अच्छा स्मरण | നല്ല ഓർമ്മ |
| `quality_needs_work` | New | Needs work | और अभ्यास चाहिए | കൂടുതൽ പരിശീലനം വേണം |
| `quality_ok` | New | Fair recall | ठीक स्मरण | ശരാശരി ഓർമ്മ |
| `quality_perfect` | New | Perfect recall | उत्कृष्ट स्मरण | മികച്ച ഓർമ്മ |
| `quality_try_again` | New | Try again | फिर से प्रयास करें | വീണ്ടും ശ്രമിക്കൂ |
| `stat_answer_shown` | New | answer shown | उत्तर दिखाया | ഉത്തരം കാണിച്ചു |
| `stat_day_streak` | New | day streak | दिन लगातार | ദിവസ തുടർച്ച |
| `stat_days` | New | days | दिन | ദിവസം |
| `stat_hint` | New | hint | संकेत | സൂചന |
| `stat_hints` | New | hints | संकेत | സൂചനകൾ |
| `stat_mastered` | New | mastered | कंठस्थ | മനഃപാഠം |
| `stat_perfect` | New | perfect | उत्कृष्ट | മികച്ചത് |
| `stat_reviews` | New | reviews | दोहराव | ആവർത്തനങ്ങൾ |
| `stat_time` | New | time | समय | സമയം |
| `stat_verse` | New | verse | वचन | വാക്യം |
| `stat_verses` | New | verses | वचन | വാക്യങ്ങൾ |
| `stats_subtitle` | New | Your memory practice | आपका याद करने का अभ्यास | നിങ്ങളുടെ മനഃപാഠ പരിശീലനം |
| `streak_line` | New | Current streak {current} · Longest {longest} | मौजूदा स्ट्रीक {current} · सबसे लंबी {longest} | നിലവിലെ തുടർച്ച {current} · ഏറ്റവും നീണ്ടത് {longest} |
| `tap_to_see_plans` | New | Tap to see plans | प्लान देखने के लिए टैप करें | പ്ലാനുകൾ കാണാൻ ടാപ്പ് ചെയ്യുക |
| `tile_custom` | New | Custom | अपना | സ്വന്തം |
| `tile_custom_hint` | New | Any reference | कोई भी संदर्भ | ഏത് റഫറൻസും |
| `tile_daily` | New | Daily verse | दैनिक वचन | ദിനവാക്യം |
| `tile_daily_hint` | New | Today's verse | आज का वचन | ഇന്നത്തെ വാക്യം |
| `tile_suggested` | New | Suggested | सुझाए गए | നിർദ്ദേശിച്ചവ |
| `tile_suggested_hint` | New | Curated verses | चुने हुए वचन | തിരഞ്ഞെടുത്ത വാക്യങ്ങൾ |
| `top_ten` | New | Top 10 | शीर्ष 10 | ആദ്യ 10 |
| `upgrade` | New | Upgrade | अपग्रेड | അപ്‌ഗ്രേഡ് |
| `verse_count_one` | New | {count} verse | {count} वचन | {count} വാക്യം |
| `verses_count` | New | {count} verses | {count} वचन | {count} വാക്യങ്ങൾ |
| `yes` | New | Yes | हाँ | ഉവ്വ് |
| `your_rank` | New | Your rank | आपकी रैंक | നിങ്ങളുടെ റാങ്ക് |

## community_pages (59)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `about` | New | About | परिचय | വിവരങ്ങൾ |
| `by_discipler` | New | By Discipler | Discipler द्वारा | Discipler മുഖേന |
| `calendar_body` | New | To create a Google Meet link for this meeting, we need brief access to your Google Calendar.  Google will open to confirm. It only takes a moment. | इस मीटिंग का Google Meet लिंक बनाने के लिए हमें थोड़ी देर के लिए आपके Google Calendar की अनुमति चाहिए।  पुष्टि के लिए Google खुलेगा। इसमें बस एक पल लगेगा। | ഈ മീറ്റിംഗിന് Google Meet ലിങ്ക് ഉണ്ടാക്കാൻ നിങ്ങളുടെ Google Calendar-ലേക്ക് അൽപനേരത്തെ അനുമതി വേണം.  സ്ഥിരീകരിക്കാൻ Google തുറക്കും. ഒരു നിമിഷം മാത്രം. |
| `calendar_failed_body` | New | We couldn't get access to your Google Calendar. The meeting will be created without a Google Meet link.  You can share your own link with members after creating it. | हमें आपके Google Calendar की अनुमति नहीं मिली। मीटिंग बिना Google Meet लिंक के बनेगी।  मीटिंग बनाने के बाद आप सदस्यों के साथ अपना लिंक साझा कर सकते हैं। | നിങ്ങളുടെ Google Calendar-ലേക്ക് അനുമതി ലഭിച്ചില്ല. Google Meet ലിങ്ക് ഇല്ലാതെ മീറ്റിംഗ് സൃഷ്ടിക്കും.  സൃഷ്ടിച്ച ശേഷം നിങ്ങളുടെ സ്വന്തം ലിങ്ക് അംഗങ്ങളുമായി പങ്കിടാം. |
| `calendar_failed_title` | New | Couldn't connect Google Calendar | Google Calendar कनेक्ट नहीं हो सका | Google Calendar ബന്ധിപ്പിക്കാനായില്ല |
| `calendar_skip` | New | Skip, no Meet link | छोड़ें, Meet लिंक नहीं | ഒഴിവാക്കുക, Meet ലിങ്ക് വേണ്ട |
| `calendar_title` | New | Connect Google Calendar | Google Calendar कनेक्ट करें | Google Calendar ബന്ധിപ്പിക്കുക |
| `cancel_body` | New | Cancel "{title}"? Everyone invited will get a cancellation email. | "{title}" रद्द करें? सभी आमंत्रित लोगों को रद्द होने का ईमेल मिलेगा। | "{title}" റദ്ദാക്കണോ? ക്ഷണിക്കപ്പെട്ട എല്ലാവർക്കും റദ്ദാക്കൽ ഇമെയിൽ ലഭിക്കും. |
| `cancel_meeting` | New | Cancel meeting | मीटिंग रद्द करें | മീറ്റിംഗ് റദ്ദാക്കുക |
| `continue` | New | Continue | जारी रखें | തുടരുക |
| `create_anyway` | New | Create anyway | फिर भी बनाएं | എങ്കിലും സൃഷ്ടിക്കുക |
| `daily` | New | Daily | रोज़ | ദിവസേന |
| `date_time` | New | Date and time | तारीख और समय | തീയതിയും സമയവും |
| `description_label` | New | Description (optional) | विवरण (वैकल्पिक) | വിവരണം (ഐച്ഛികം) |
| `discussion` | New | Discussion | चर्चा | ചർച്ച |
| `discussion_empty` | New | No discussion yet. Be the first to share! | अभी कोई चर्चा नहीं। सबसे पहले आप साझा करें! | ഇതുവരെ ചർച്ചയില്ല. ആദ്യം പങ്കിടുന്നത് നിങ്ങളാകട്ടെ! |
| `discussion_subtitle` | New | Share your reflections on this lesson | इस पाठ पर अपने विचार साझा करें | ഈ പാഠത്തെക്കുറിച്ചുള്ള നിങ്ങളുടെ ചിന്തകൾ പങ്കിടുക |
| `duration` | New | Duration | अवधि | ദൈർഘ്യം |
| `hours` | New | {count} hr | {count} घंटा | {count} മണിക്കൂർ |
| `hours_minutes` | New | {hours} hr {minutes} min | {hours} घंटा {minutes} मिनट | {hours} മണിക്കൂർ {minutes} മിനിറ്റ് |
| `in_person` | New | In person | आमने-सामने | നേരിട്ട് |
| `join` | New | Join | जुड़ें | ചേരുക |
| `keep` | New | Keep | रहने दें | നിലനിർത്തുക |
| `later` | New | Later | बाद में | പിന്നീട് |
| `load_error` | New | Couldn't load meetings | मीटिंग लोड नहीं हो सकीं | മീറ്റിംഗുകൾ ലോഡ് ചെയ്യാനായില്ല |
| `location_hint` | New | e.g. Community Hall, Room 3 | जैसे सामुदायिक हॉल, कमरा 3 | ഉദാ. കമ്മ്യൂണിറ്റി ഹാൾ, മുറി 3 |
| `location_label` | New | Location | स्थान | സ്ഥലം |
| `location_required` | New | Please enter a location | कृपया स्थान दर्ज करें | ദയവായി സ്ഥലം നൽകുക |
| `meeting_type` | New | Meeting type | मीटिंग का प्रकार | മീറ്റിംഗ് തരം |
| `member_one` | New | 1 member | 1 सदस्य | 1 അംഗം |
| `members` | New | {count} members | {count} सदस्य | {count} അംഗങ്ങൾ |
| `milestone` | New | Milestone | पड़ाव | നാഴികക്കല്ല് |
| `minutes` | New | {count} min | {count} मिनट | {count} മിനിറ്റ് |
| `monthly` | New | Monthly | मासिक | മാസംതോറും |
| `next_week` | New | Next week | अगले सप्ताह | അടുത്ത ആഴ്ച |
| `no_link` | New | No link yet | अभी कोई लिंक नहीं | ഇതുവരെ ലിങ്ക് ഇല്ല |
| `one_time` | New | One-time | एक बार | ഒറ്റത്തവണ |
| `online` | New | Online | ऑनलाइन | ഓൺലൈൻ |
| `open_guide` | New | Open study guide | अध्ययन गाइड खोलें | പഠന ഗൈഡ് തുറക്കുക |
| `reflection_hint` | New | Share your reflection… | अपना विचार साझा करें… | നിങ്ങളുടെ ചിന്ത പങ്കിടുക… |
| `repeat` | New | Repeat | दोहराएं | ആവർത്തിക്കുക |
| `reply_hint` | New | Add a reply… | जवाब लिखें… | മറുപടി ചേർക്കുക… |
| `schedule_title` | New | Schedule a meeting | मीटिंग शेड्यूल करें | മീറ്റിംഗ് ഷെഡ്യൂൾ ചെയ്യുക |
| `send` | New | Send | भेजें | അയയ്ക്കുക |
| `share_message_hint` | New | What's on your heart? | आपके मन में क्या है? | നിങ്ങളുടെ മനസ്സിൽ എന്താണ്? |
| `share_message_label` | New | Add a message (optional) | संदेश जोड़ें (वैकल्पिक) | സന്ദേശം ചേർക്കുക (ഐച്ഛികം) |
| `share_none` | New | You don't belong to any fellowship yet. | आप अभी किसी संगति में नहीं हैं। | നിങ്ങൾ ഇതുവരെ ഒരു കൂട്ടായ്മയിലും ഇല്ല. |
| `share_select` | New | Select a fellowship | एक संगति चुनें | ഒരു കൂട്ടായ്മ തിരഞ്ഞെടുക്കുക |
| `share_title` | New | Share guide | गाइड साझा करें | ഗൈഡ് പങ്കിടുക |
| `share_to` | New | Share to fellowship | संगति में साझा करें | കൂട്ടായ്മയിലേക്ക് പങ്കിടുക |
| `share_to_many` | New | Share to {count} fellowships | {count} संगतियों में साझा करें | {count} കൂട്ടായ്മകളിലേക്ക് പങ്കിടുക |
| `share_to_one` | New | Share to 1 fellowship | 1 संगति में साझा करें | 1 കൂട്ടായ്മയിലേക്ക് പങ്കിടുക |
| `submit` | New | Schedule & send invites | शेड्यूल करें और न्योता भेजें | ഷെഡ്യൂൾ ചെയ്ത് ക്ഷണം അയയ്ക്കുക |
| `this_week` | New | This week | इस सप्ताह | ഈ ആഴ്ച |
| `title_hint` | New | e.g. Weekly Prayer Session | जैसे साप्ताहिक प्रार्थना सभा | ഉദാ. പ്രതിവാര പ്രാർത്ഥന |
| `title_label` | New | Meeting title | मीटिंग का शीर्षक | മീറ്റിംഗിന്റെ പേര് |
| `title_required` | New | Title is required | शीर्षक ज़रूरी है | പേര് ആവശ്യമാണ് |
| `weekly` | New | Weekly | साप्ताहिक | ആഴ്ചതോറും |
| `you_are_mentor` | New | You're the mentor | आप मेंटर हैं | നിങ്ങളാണ് മെന്റർ |

## notifications (59)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `settings.about_info` | Changed | • Notifications are sent based on your timezone • You can customize which notifications you receive • Tap on a notification to view the content directly • You can disable notifications anytime | • नोटिफिकेशन आपके टाइमज़ोन के आधार पर भेजे जाते हैं • आप चुन सकते हैं कि कौन से नोटिफिकेशन प्राप्त करने हैं • सामग्री सीधे देखने के लिए नोटिफिकेशन पर टैप करें • आप किसी भी समय नोटिफिकेशन अक्षम कर सकते हैं | • അറിയിപ്പുകൾ നിങ്ങളുടെ സമയമേഖല അനുസരിച്ച് അയയ്‌ക്കുന്നു • ഏതൊക്കെ അറിയിപ്പുകൾ സ്വീകരിക്കണമെന്ന് തിരഞ്ഞെടുക്കാം • ഉള്ളടക്കം നേരിട്ട് കാണാൻ അറിയിപ്പിൽ ടാപ്പ് ചെയ്യുക • ഏതു സമയവും അറിയിപ്പുകൾ പ്രവർ‍ത്തിപ്പിക്കാത്താക്കാം |
| `settings.achievement_description` | New | When you unlock a new achievement | जब आप कोई नई उपलब्धि प्राप्त करें | പുതിയ നേട്ടം കൈവരിക്കുമ്പോൾ |
| `settings.achievement_title` | New | Achievements | उपलब्धियाँ | നേട്ടങ്ങൾ |
| `settings.community_section_title` | New | Community | समुदाय | കൂട്ടായ്മ |
| `settings.continue_learning_description` | New | A nudge to pick up a study you started | आपके शुरू किए गए अध्ययन को आगे बढ़ाने की याद | നിങ്ങൾ തുടങ്ങിയ പഠനം തുടരാനുള്ള ഓർമ്മപ്പെടുത്തൽ |
| `settings.continue_learning_title` | New | Continue learning | अध्ययन जारी रखें | പഠനം തുടരുക |
| `settings.daily_section_title` | New | Daily | दैनिक | ദിവസേന |
| `settings.daily_verse_description` | Changed | Every morning at 8:00 AM | हर सुबह 8:00 बजे | എല്ലാ ദിവസവും രാവിലെ 8:00-ന് |
| `settings.daily_verse_title` | Changed | Daily verse | दैनिक वचन | ഇന്നത്തെ വചനം |
| `settings.discipler_activity_description` | New | A summary of what Discipler did in groups you mentor | आपके मार्गदर्शन वाले समूहों में Discipler की गतिविधि का सारांश | നിങ്ങൾ നയിക്കുന്ന ഗ്രൂപ്പുകളിലെ Discipler പ്രവർത്തനത്തിന്റെ സംഗ്രഹം |
| `settings.discipler_activity_title` | New | Discipler activity | Discipler गतिविधि | Discipler പ്രവർത്തനം |
| `settings.discipler_reply_description` | New | When Discipler answers a question in your fellowship | जब Discipler आपके समूह में किसी प्रश्न का उत्तर दे | നിങ്ങളുടെ കൂട്ടായ്മയിലെ ചോദ്യത്തിന് Discipler ഉത്തരം നൽകുമ്പോൾ |
| `settings.discipler_reply_title` | New | Discipler replies | Discipler के उत्तर | Discipler ന്റെ മറുപടികൾ |
| `settings.discipler_section_title` | New | Discipler | Discipler | Discipler |
| `settings.enable_button` | Changed | Enable notifications | नोटिफिकेशन सक्षम करें | അറിയിപ്പുകൾ പ്രവർ‍ത്തിപ്പിക്കുക |
| `settings.fellowship_comment_description` | New | When someone comments on a post you follow | जब कोई आपकी अनुसरण की गई पोस्ट पर टिप्पणी करे | നിങ്ങൾ പിന്തുടരുന്ന പോസ്റ്റിൽ ആരെങ്കിലും അഭിപ്രായം എഴുതുമ്പോൾ |
| `settings.fellowship_comment_title` | New | Comments | टिप्पणियाँ | അഭിപ്രായങ്ങൾ |
| `settings.fellowship_daily_post_description` | New | The study Discipler posts to your fellowship each day | Discipler हर दिन आपके समूह में जो अध्ययन पोस्ट करता है | Discipler ദിവസവും നിങ്ങളുടെ കൂട്ടായ്മയിൽ പോസ്റ്റ് ചെയ്യുന്ന പഠനം |
| `settings.fellowship_daily_post_title` | New | Daily study post | दैनिक अध्ययन पोस्ट | ദൈനംദിന പഠന പോസ്റ്റ് |
| `settings.fellowship_member_joined_description` | New | When someone joins a fellowship you mentor | जब कोई आपकी संगति में शामिल हो | നിങ്ങൾ നയിക്കുന്ന കൂട്ടായ്മയിൽ ആരെങ്കിലും ചേരുമ്പോൾ |
| `settings.fellowship_member_joined_title` | New | New members | नए सदस्य | പുതിയ അംഗങ്ങൾ |
| `settings.fellowship_mention_description` | New | When someone tags you in a post or comment | जब कोई आपको किसी पोस्ट या टिप्पणी में टैग करे | ആരെങ്കിലും ഒരു പോസ്റ്റിലോ അഭിപ്രായത്തിലോ നിങ്ങളെ ടാഗ് ചെയ്യുമ്പോൾ |
| `settings.fellowship_mention_title` | New | Mentions | उल्लेख | പരാമർശങ്ങൾ |
| `settings.fellowship_new_post_description` | New | When a member shares a post in your fellowship | जब कोई सदस्य आपके समूह में पोस्ट साझा करे | ഒരു അംഗം നിങ്ങളുടെ കൂട്ടായ്മയിൽ പോസ്റ്റ് പങ്കിടുമ്പോൾ |
| `settings.fellowship_new_post_title` | New | New posts | नई पोस्ट | പുതിയ പോസ്റ്റുകൾ |
| `settings.fellowship_reaction_description` | New | When someone reacts to your post | जब कोई आपकी पोस्ट पर प्रतिक्रिया दे | ആരെങ്കിലും നിങ്ങളുടെ പോസ്റ്റിനോട് പ്രതികരിക്കുമ്പോൾ |
| `settings.fellowship_reaction_title` | New | Reactions | प्रतिक्रियाएँ | പ്രതികരണങ്ങൾ |
| `settings.meeting_cancelled_description` | New | When a scheduled meeting is called off | जब कोई निर्धारित सभा रद्द हो | നിശ്ചയിച്ച മീറ്റിംഗ് റദ്ദാക്കുമ്പോൾ |
| `settings.meeting_cancelled_title` | New | Meeting cancellations | सभा रद्द | മീറ്റിംഗ് റദ്ദാക്കൽ |
| `settings.meeting_invite_description` | New | When you are invited to a meeting | जब आपको किसी सभा में आमंत्रित किया जाए | നിങ്ങളെ ഒരു മീറ്റിംഗിലേക്ക് ക്ഷണിക്കുമ്പോൾ |
| `settings.meeting_invite_title` | New | Meeting invites | सभा के निमंत्रण | മീറ്റിംഗ് ക്ഷണങ്ങൾ |
| `settings.meeting_new_description` | New | When a meeting is scheduled in your fellowship | जब आपके समूह में कोई सभा निर्धारित हो | നിങ്ങളുടെ കൂട്ടായ്മയിൽ മീറ്റിംഗ് നിശ്ചയിക്കുമ്പോൾ |
| `settings.meeting_new_title` | New | New meetings | नई सभाएँ | പുതിയ മീറ്റിംഗുകൾ |
| `settings.meeting_reminder_description` | New | Shortly before a meeting starts | सभा शुरू होने से कुछ समय पहले | മീറ്റിംഗ് തുടങ്ങുന്നതിന് തൊട്ടുമുൻപ് |
| `settings.meeting_reminder_title` | New | Meeting reminders | सभा की याद | മീറ്റിംഗ് ഓർമ്മപ്പെടുത്തൽ |
| `settings.meetings_section_title` | New | Meetings | सभाएँ | മീറ്റിംഗുകൾ |
| `settings.memory_verse_overdue_title` | Changed | Overdue verses alert | अतिदेय वचन अलर्ट | കാലഹരണപ്പെട്ട വചന അറിയിപ്പ് |
| `settings.memory_verse_reminder_time_label` | Changed | Reminder time | रिमाइंडर समय | ഓർമ്മപ്പെടുത്തൽ സമയം |
| `settings.memory_verse_reminder_title` | Changed | Daily review reminder | दैनिक समीक्षा रिमाइंडर | ദൈനിക അവലോകന ഓർമ്മപ്പെടുത്തൽ |
| `settings.memory_verse_section_title` | Changed | Memory verse | याद वचन | മനഃപാഠ വാക്യം |
| `settings.mentor_promoted_description` | New | When you are made a mentor of a fellowship | जब आपको किसी समूह का मेंटर बनाया जाए | നിങ്ങളെ ഒരു കൂട്ടായ്മയുടെ മെന്ററാക്കുമ്പോൾ |
| `settings.mentor_promoted_title` | New | Made a mentor | मेंटर बनाए जाने पर | മെന്റർ ആക്കുമ്പോൾ |
| `settings.permission_title` | Changed | Notification permission | नोटिफिकेशन अनुमति | അറിയിപ്പ് അനുമതി |
| `settings.preferences_title` | Changed | Notification Preferences | नोटिफिकेशन प्राथमिकताएं | അറിയിപ്പ് മുൻഗണനകൾ |
| `settings.preferences_updated` | Changed | ✓ Preferences updated | ✓ प्राथमिकताएं अपडेट हो गईं | ✓ മുൻഗണനകൾ അപ്ഡേറ്റ് ചെയ്തു |
| `settings.recommended_topics_description` | Changed | Study suggestions at 9:00 AM | सुबह 9:00 बजे अध्ययन सुझाव | രാവിലെ 9:00-ന് പഠന നിർദ്ദേശങ്ങൾ |
| `settings.recommended_topics_title` | Changed | Recommended topics | अनुशंसित विषय | ശുപാർശ ചെയ്യുന്ന വിഷയങ്ങൾ |
| `settings.reminder_time_label` | Changed | Reminder time | रिमाइंडर समय | ഓർമ്മപ്പെടുത്തൽ സമയം |
| `settings.set_reminder_time` | Changed | Set reminder time | रिमाइंडर समय सेट करें | ഓർമ്മപ്പെടുത്തൽ സമയം സജ്ജമാക്കുക |
| `settings.streak_lost_description` | Changed | Encouragement after a break | रुकावट के बाद प्रोत्साहन | ഇടവേളയ്ക്ക് ശേഷം പ്രോത്സാഹനം |
| `settings.streak_lost_title` | Changed | Fresh start | नई शुरुआत | പുതിയ തുടക്കം |
| `settings.streak_milestone_description` | Changed | 7, 30, 100 and 365 days | 7, 30, 100 और 365 दिन | 7, 30, 100, 365 ദിവസങ്ങൾ |
| `settings.streak_milestone_title` | Changed | Milestones | पड़ाव | നാഴികക്കല്ലുകൾ |
| `settings.streak_reminder_description` | Changed | If you haven't read today's verse | अगर आज का वचन नहीं पढ़ा | ഇന്നത്തെ വചനം വായിച്ചില്ലെങ്കിൽ |
| `settings.streak_reminder_title` | Changed | Streak reminder | स्ट्रीक रिमाइंडर | തുടർച്ച ഓർമ്മപ്പെടുത്തൽ |
| `settings.streak_section_title` | New | Streak | स्ट्रीक | തുടർച്ച |
| `settings.study_section_title` | New | Study | अध्ययन | പഠനം |
| `settings.subtitle` | New | Reminders that help you keep going | रिमाइंडर जो आपको आगे बढ़ते रहने में मदद करते हैं | തുടരാൻ സഹായിക്കുന്ന ഓർമ്മപ്പെടുത്തലുകൾ |
| `settings.title` | Changed | Notifications | नोटिफिकेशन सेटिंग | അറിയിപ്പ് സെറ്റിങ്സ് |

## voice_buddy (59)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `conversation.end_feedback` | Changed | Additional feedback (optional) | अतिरिक्त प्रतिक्रिया (वैकल्पिक) | അധിക അഭിപ്രായം (നിർബന്ധമില്ല) |
| `description` | Changed | Your Bible companion — by voice or text | आपका बाइबल साथी — आवाज़ या लिखकर | നിങ്ങളുടെ ബൈബിൾ സഹായി — ശബ്ദത്തിലോ എഴുത്തിലോ |
| `language_sheet.default_subtitle` | New | Uses your app language ({language}) | आपकी ऐप भाषा ({language}) का उपयोग करता है | നിങ്ങളുടെ ആപ്പ് ഭാഷ ({language}) ഉപയോഗിക്കുന്നു |
| `language_sheet.title` | New | Speak with Discipler in | Discipler से इस भाषा में बात करें | Discipler-നോട് സംസാരിക്കേണ്ട ഭാഷ |
| `limit_dialog.maybe_later` | New | Maybe later | शायद बाद में | പിന്നീടാകാം |
| `limit_dialog.message_one` | New | You've used your {limit} voice conversation for this month. | आपने इस महीने की अपनी {limit} वॉइस बातचीत का उपयोग कर लिया है। | ഈ മാസത്തെ നിങ്ങളുടെ {limit} വോയ്സ് സംഭാഷണം ഉപയോഗിച്ചുകഴിഞ്ഞു. |
| `limit_dialog.message_other` | New | You've used all {limit} voice conversations for this month. | आपने इस महीने की सभी {limit} वॉइस बातचीत का उपयोग कर लिया है। | ഈ മാസത്തെ എല്ലാ {limit} വോയ്സ് സംഭാഷണങ്ങളും ഉപയോഗിച്ചുകഴിഞ്ഞു. |
| `limit_dialog.this_month` | New | This month | इस महीने | ഈ മാസം |
| `limit_dialog.upgrade_heading` | New | Upgrade to get more conversations: | और बातचीत पाने के लिए अपग्रेड करें: | കൂടുതൽ സംഭാഷണങ്ങൾക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക: |
| `limit_dialog.used` | New | {used} of {limit} used | {limit} में से {used} उपयोग की गईं | {limit}-ൽ {used} ഉപയോഗിച്ചു |
| `limit_dialog.view_plans` | New | View plans | प्लान देखें | പ്ലാനുകൾ കാണുക |
| `mic_permission.allow` | New | Allow | अनुमति दें | അനുമതി നൽകുക |
| `mic_permission.blocked_message` | New | Microphone access is turned off. Turn it on in Settings to speak, or type your message instead. | माइक्रोफ़ोन की अनुमति बंद है। बोलने के लिए इसे सेटिंग्स में चालू करें, या अपना संदेश टाइप करें। | മൈക്രോഫോൺ അനുമതി ഓഫാണ്. സംസാരിക്കാൻ ക്രമീകരണങ്ങളിൽ അത് ഓണാക്കുക, അല്ലെങ്കിൽ സന്ദേശം ടൈപ്പ് ചെയ്യുക. |
| `mic_permission.message` | New | Allow microphone access to speak with Discipler. You can type your message instead. | शिक्षागुरु से बोलकर बात करने के लिए माइक्रोफ़ोन की अनुमति दें। आप संदेश टाइप भी कर सकते हैं। | Discipler-നോട് സംസാരിക്കാൻ മൈക്രോഫോൺ അനുമതി നൽകുക. പകരം സന്ദേശം ടൈപ്പ് ചെയ്യാം. |
| `mic_permission.open_settings` | New | Open Settings | सेटिंग्स खोलें | ക്രമീകരണങ്ങൾ തുറക്കുക |
| `mic_permission.title` | New | Microphone access needed | माइक्रोफ़ोन की अनुमति चाहिए | മൈക്രോഫോൺ അനുമതി വേണം |
| `mic_permission.type_instead` | New | Type instead | टाइप करें | ടൈപ്പ് ചെയ്യുക |
| `quota_exceeded.message` | Changed | You've used all your voice conversations for this month. Upgrade to Premium for unlimited conversations. | इस महीने आपकी सभी वॉयस बातचीत समाप्त हो गई हैं। असीमित बातचीत के लिए प्रीमियम अपग्रेड करें। | ഈ മാസത്തെ നിങ്ങളുടെ എല്ലാ വോയ്സ് സംഭാഷണങ്ങളും ഉപയോഗിച്ചു. പരിധിയില്ലാത്ത സംഭാഷണങ്ങൾക്ക് പ്രീമിയം അപ്‌ഗ്രേഡ് ചെയ്യുക. |
| `quota_exceeded.upgrade_button` | Changed | Upgrade to Premium | प्रीमियम अपग्रेड करें | പ്രീമിയം അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `session.change_language` | New | Change language | भाषा बदलें | ഭാഷ മാറ്റുക |
| `session.headline` | New | Ask Discipler anything | शिक्षागुरु से कुछ भी पूछें | Discipler-നോട് എന്തും ചോദിക്കൂ |
| `session.keep_talking` | New | Keep talking | बात जारी रखें | സംസാരം തുടരുക |
| `session.quota_left` | New | {remaining} of {limit} left this month | इस महीने {limit} में से {remaining} शेष | ഈ മാസം {limit}-ൽ {remaining} ശേഷിക്കുന്നു |
| `session.rate_stars` | New | Rate {count} of 5 | 5 में से {count} रेटिंग दें | 5-ൽ {count} റേറ്റിംഗ് നൽകുക |
| `session.send` | New | Send | भेजें | അയയ്ക്കുക |
| `session.speaking_language` | New | Speaking {language} | {language} में बातचीत | {language}-ൽ സംസാരിക്കുന്നു |
| `session.start_talking` | New | Start talking | बोलना शुरू करें | സംസാരിച്ചു തുടങ്ങുക |
| `session.status_listening` | New | Listening | सुन रहा है | കേൾക്കുന്നു |
| `session.status_ready` | New | Ready | तैयार | തയ്യാർ |
| `session.status_speaking` | New | Speaking | बोल रहा है | സംസാരിക്കുന്നു |
| `session.status_thinking` | New | Thinking | सोच रहा है | ചിന്തിക്കുന്നു |
| `session.suggestion_1` | New | Why did Jesus speak in parables? | यीशु दृष्टांतों में क्यों बोलते थे? | യേശു ഉപമകളിലൂടെ സംസാരിച്ചത് എന്തുകൊണ്ട്? |
| `session.suggestion_2` | New | How do I forgive someone who hurt me? | जिसने मुझे चोट पहुँचाई, उसे मैं कैसे क्षमा करूँ? | എന്നെ വേദനിപ്പിച്ച ഒരാളോട് ഞാൻ എങ്ങനെ ക്ഷമിക്കും? |
| `session.suggestion_3` | New | What does Romans 8:28 really mean? | रोमियों 8:28 का असली अर्थ क्या है? | റോമർ 8:28 യഥാർത്ഥത്തിൽ എന്താണ് അർത്ഥമാക്കുന്നത്? |
| `session.try_asking` | New | Try asking | यह पूछकर देखें | ഇങ്ങനെ ചോദിച്ചു നോക്കൂ |
| `session.type` | New | Type | टाइप करें | ടൈപ്പ് ചെയ്യുക |
| `session.typing_mode` | New | Switch to typing | टाइपिंग पर जाएँ | ടൈപ്പിങ്ങിലേക്ക് മാറുക |
| `session.voice_mode` | New | Switch to voice | आवाज़ पर जाएँ | ശബ്ദത്തിലേക്ക് മാറുക |
| `session.you` | New | You | आप | നിങ്ങൾ |
| `session.you_asked` | New | You asked | आपने पूछा | നിങ്ങൾ ചോദിച്ചത് |
| `settings.ai_context` | Changed | Study Memory | अध्ययन याद रखें | പഠനം ഓർത്തുവയ്ക്കുക |
| `settings.auto_detect` | Changed | Auto-detect language | भाषा अपने आप पहचानें | ഭാഷ സ്വയം കണ്ടെത്തുക |
| `settings.auto_detect_subtitle` | Changed | Detect the language you speak | आपकी बोली भाषा पहचानें | നിങ്ങൾ സംസാരിക്കുന്ന ഭാഷ തിരിച്ചറിയുക |
| `settings.auto_play` | Changed | Auto-play responses | जवाब अपने आप चलाएं | മറുപടികൾ സ്വയം പ്ലേ ചെയ്യുക |
| `settings.cite_scripture` | Changed | Cite Scripture references | बाइबल संदर्भ | തിരുവെഴുത്ത് റഫറൻസുകൾ |
| `settings.cite_scripture_subtitle` | Changed | Include Bible verse citations in responses | जवाब में बाइबल आयत शामिल करें | പ്രതികരണങ്ങളിൽ ബൈബിൾ വാക്യങ്ങൾ ഉൾപ്പെടുത്തുക |
| `settings.continuous_mode_subtitle` | Changed | Keep listening after response | जवाब के बाद सुनना जारी रखें | പ്രതികരണത്തിന് ശേഷം കേൾക്കുന്നത് തുടരുക |
| `settings.interaction` | Changed | Interaction | बातचीत | സംഭാഷണം |
| `settings.pitch` | Changed | Pitch | सुर | പിച്ച് |
| `settings.quota_alerts` | Changed | Quota alerts | सीमा की सूचना | പരിധി അറിയിപ്പുകൾ |
| `settings.save` | Changed | Save | सहेजें | സേവ് ചെയ്യുക |
| `settings.show_transcription` | Changed | Show transcription | लिखित रूप दिखाएं | എഴുത്തുരൂപം കാണിക്കുക |
| `settings.speaking_rate` | Changed | Speaking rate | बोलने की गति | സംസാര വേഗത |
| `settings.title` | Changed | Voice settings | वॉयस सेटिंग्स | വോയ്സ് സെറ്റിംഗ്സ് |
| `settings.unsaved_message` | Changed | You have unsaved changes. Would you like to save them before leaving? | आपके बदलाव सहेजे नहीं गए हैं। क्या आप जाने से पहले सहेजना चाहते हैं? | നിങ്ങൾക്ക് സേവ് ചെയ്യാത്ത മാറ്റങ്ങൾ ഉണ്ട്. പോകുന്നതിന് മുമ്പ് സേവ് ചെയ്യണോ? |
| `settings.unsaved_title` | Changed | Unsaved Changes | बिना सहेजे बदलाव | സേവ് ചെയ്യാത്ത മാറ്റങ്ങൾ |
| `settings.use_study_context` | Changed | Use study context | अध्ययन का संदर्भ इस्तेमाल करें | പഠന സന്ദർഭം ഉപയോഗിക്കുക |
| `settings.use_study_context_subtitle` | Changed | Include your current study for relevant answers | प्रासंगिक उत्तरों के लिए आपका अभी का अध्ययन शामिल करें | പ്രസക്തമായ ഉത്തരങ്ങൾക്ക് നിങ്ങളുടെ നിലവിലെ പഠനം ഉൾപ്പെടുത്തുക |
| `settings.voice_output` | Changed | Voice Output | आवाज़ में जवाब | ശബ്ദത്തിൽ മറുപടി |

## onboarding (41)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `get_started` | New | Get Started | शुरू करें | ആരംഭിക്കുക |
| `language_default` | New | Default | डिफ़ॉल्ट | ഡിഫോൾട്ട് |
| `language_eyebrow` | New | Language | भाषा | ഭാഷ |
| `language_save_failed` | New | Couldn't save your language. Please try again. | आपकी भाषा सहेजी नहीं जा सकी। कृपया फिर से कोशिश करें। | നിങ്ങളുടെ ഭാഷ സേവ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `language_saved_locally` | Changed | Language preference saved locally. Will sync when online. | भाषा सहेजी गई। ऑनलाइन होने पर सिंक होगी। | ഭാഷാ പ്രാപുല്യം സ്ഥാനീയമായി സംരക്ഷിച്ചു. ഓൺലൈൻ ആയാല്‍ സിങ്ക് ചെയ്യും. |
| `preview_again` | New | Again | फिर से | വീണ്ടും |
| `preview_answer` | New | Parables invite the listener in. Jesus used everyday pictures so open hearts would understand (Matthew 13:13). | दृष्टांत सुनने वाले को भीतर बुलाते हैं। यीशु ने रोज़मर्रा के चित्रों का उपयोग किया ताकि खुले हृदय समझ सकें (मत्ती 13:13)। | ഉപമകൾ കേൾവിക്കാരനെ ഉള്ളിലേക്കു ക്ഷണിക്കുന്നു. തുറന്ന ഹൃദയങ്ങൾ ഗ്രഹിക്കേണ്ടതിന് യേശു ദൈനംദിന ചിത്രങ്ങൾ ഉപയോഗിച്ചു (മത്തായി 13:13). |
| `preview_blank_end` | New | sin against you. | पाप न करूं। | നിന്റെ വചനത്തെ എന്റെ ഹൃദയത്തിൽ സംഗ്രഹിക്കുന്നു. |
| `preview_blank_start` | New | I have hidden your word in my heart | मैं ने तेरे वचन को अपने हृदय में रख छोड़ा है, | ഞാൻ നിന്നോടു |
| `preview_context` | New | Context | संदर्भ | പശ്ചാത്തലം |
| `preview_context_body` | New | Paul writes to Roman believers facing suffering. | पौलुस दुःख सह रहे रोमी विश्वासियों को लिखता है। | കഷ്ടത നേരിടുന്ന റോമിലെ വിശ്വാസികൾക്കു പൗലൊസ് എഴുതുന്നു. |
| `preview_easy` | New | Easy | आसान | എളുപ്പം |
| `preview_good` | New | Good | अच्छा | നല്ലത് |
| `preview_interpretation` | New | Interpretation | व्याख्या | വ്യാഖ്യാനം |
| `preview_listening` | New | listening | सुन रहा है | കേൾക്കുന്നു |
| `preview_question` | New | Why did Jesus speak in parables? | यीशु दृष्टांतों में क्यों बोलते थे? | യേശു ഉപമകളിലൂടെ സംസാരിച്ചത് എന്തുകൊണ്ട്? |
| `preview_review_meta` | New | Review · 3 due | दोहराव · 3 बाकी | ആവർത്തനം · 3 ബാക്കി |
| `preview_scripture_meta` | New | Scripture · Deep dive · 12 min | वचन · गहरी पढ़ाई · 12 मिनट | തിരുവെഴുത്ത് · ആഴത്തിലുള്ള പഠനം · 12 മിനിറ്റ് |
| `preview_study_now` | New | Study now | अभी पढ़ें | ഇപ്പോൾ പഠിക്കൂ |
| `preview_summary` | New | Summary | सारांश | സംഗ്രഹം |
| `preview_summary_body` | New | God works all things together for good for those who love Him. | जो परमेश्वर से प्रेम रखते हैं, उनके लिए वह सब बातों से भलाई उत्पन्न करता है। | ദൈവത്തെ സ്നേഹിക്കുന്നവർക്കു സകലവും നന്മയ്ക്കായി കൂടി വ്യാപരിക്കുന്നു. |
| `preview_topic` | New | Forgiveness | क्षमा | ക്ഷമ |
| `preview_topic_meta` | New | Topic · Standard · 8 min | विषय · सामान्य · 8 मिनट | വിഷയം · സാധാരണ · 8 മിനിറ്റ് |
| `preview_verse_of_day` | New | Verse of the day | आज का वचन | ഇന്നത്തെ വചനം |
| `skip_intro` | New | Skip | छोड़ें | ഒഴിവാക്കുക |
| `slide1_description` | New | Receive daily verses with instant study guides. Tap any verse to dive deeper with personalized insights, context, and practical applications. | हर दिन वचन और तुरंत अध्ययन गाइड पाएं। किसी भी वचन पर टैप करें और व्यक्तिगत अंतर्दृष्टि, संदर्भ और व्यावहारिक प्रयोग के साथ गहराई में जाएं। | ദിവസവും വചനങ്ങളും ഉടനടി പഠന ഗൈഡുകളും നേടൂ. ഏതു വചനത്തിലും ടാപ്പ് ചെയ്ത് വ്യക്തിഗത ഉൾക്കാഴ്ചകൾ, പശ്ചാത്തലം, പ്രായോഗിക പാഠങ്ങൾ എന്നിവയിലേക്ക് ആഴത്തിൽ ഇറങ്ങൂ. |
| `slide1_eyebrow` | New | Daily verse | दैनिक वचन | ദിനവചനം |
| `slide1_title` | New | Start each day with God's Word | हर दिन की शुरुआत परमेश्वर के वचन से करें | ഓരോ ദിവസവും ദൈവവചനത്തോടെ ആരംഭിക്കൂ |
| `slide1_verse` | New | Your word is a lamp for my feet, a light on my path. | तेरा वचन मेरे पांव के लिये दीपक, और मेरे मार्ग के लिये उजियाला है। | നിന്റെ വചനം എന്റെ കാലിന്നു ദീപവും എന്റെ പാതയ്ക്കു പ്രകാശവും ആകുന്നു. |
| `slide2_description` | New | Enter any scripture or topic to create comprehensive study guides with context, interpretation, reflection questions, and prayer points. | कोई भी वचन या विषय दर्ज करें और संदर्भ, व्याख्या, मनन के प्रश्न और प्रार्थना बिंदुओं के साथ पूरी अध्ययन गाइड बनाएं। | ഏതു വേദഭാഗമോ വിഷയമോ നൽകി പശ്ചാത്തലം, വ്യാഖ്യാനം, ധ്യാന ചോദ്യങ്ങൾ, പ്രാർത്ഥനാ വിഷയങ്ങൾ എന്നിവയുള്ള സമഗ്ര പഠന സഹായികൾ തയ്യാറാക്കൂ. |
| `slide2_eyebrow` | New | Study guides | अध्ययन गाइड | പഠന ഗൈഡുകൾ |
| `slide2_title` | New | Personalized insights for your journey | आपकी यात्रा के लिए व्यक्तिगत अंतर्दृष्टि | നിങ്ങളുടെ യാത്രയ്ക്കായി വ്യക്തിഗത ഉൾക്കാഴ്ചകൾ |
| `slide2_verse` | New | All Scripture is God-breathed and is useful for teaching... | सम्पूर्ण पवित्रशास्त्र परमेश्वर की प्रेरणा से रचा गया है और उपदेश के लिये लाभदायक है... | എല്ലാ തിരുവെഴുത്തും ദൈവശ്വാസീയമാകയാൽ ഉപദേശത്തിന്നു പ്രയോജനമുള്ളതു... |
| `slide3_description` | New | Have natural voice conversations about Scripture. Ask questions, get answers, and deepen your understanding through guided dialogue. | बाइबल के बारे में सहज आवाज़ में बातचीत करें। प्रश्न पूछें, उत्तर पाएं और मार्गदर्शित संवाद से अपनी समझ बढ़ाएं। | തിരുവെഴുത്തിനെക്കുറിച്ച് സ്വാഭാവികമായി ശബ്ദത്തിൽ സംസാരിക്കൂ. ചോദ്യങ്ങൾ ചോദിക്കൂ, ഉത്തരങ്ങൾ നേടൂ, മാർഗനിർദേശമുള്ള സംഭാഷണത്തിലൂടെ ഗ്രാഹ്യം ആഴപ്പെടുത്തൂ. |
| `slide3_eyebrow` | New | Discipler | Discipler | Discipler |
| `slide3_title` | New | Talk with your Bible companion | अपने बाइबल साथी से बात करें | നിങ്ങളുടെ ബൈബിൾ സഹായിയോട് സംസാരിക്കൂ |
| `slide3_verse` | New | Call to me and I will answer you... | मुझ से प्रार्थना कर और मैं तेरी सुनकर तुझे उत्तर दूंगा... | എന്നോടു വിളിച്ചപേക്ഷിക്ക; ഞാൻ നിനക്കു ഉത്തരം അരുളും... |
| `slide4_description` | New | Memorize Scripture with scientifically-proven spaced repetition. Review verses at optimal intervals to commit them to long-term memory. | आज़माए हुए तरीके से वचन याद करें: सही अंतराल पर दोहराएं ताकि वचन लंबे समय तक याद रहें। | തെളിയിക്കപ്പെട്ട രീതിയിൽ വചനം മനഃപാഠമാക്കൂ. ശരിയായ ഇടവേളകളിൽ ആവർത്തിച്ച് ദീർഘകാലം ഓർമ്മയിൽ സൂക്ഷിക്കൂ. |
| `slide4_eyebrow` | New | Memory verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |
| `slide4_title` | New | Hide God's Word in your heart | परमेश्वर के वचन को अपने हृदय में रखें | ദൈവവചനം ഹൃദയത്തിൽ സൂക്ഷിക്കൂ |
| `slide4_verse` | New | I have hidden your word in my heart that I might not sin against you. | मैं ने तेरे वचन को अपने हृदय में रख छोड़ा है, कि तेरे विरुद्ध पाप न करूं। | ഞാൻ നിന്നോടു പാപം ചെയ്യാതിരിപ്പാൻ നിന്റെ വചനത്തെ എന്റെ ഹൃദയത്തിൽ സംഗ്രഹിക്കുന്നു. |

## memory (35)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `addOptions.custom` | Changed | Add Custom Verse | अपनी आयत जोड़ें | സ്വന്തം വാക്യം ചേർക്കുക |
| `addOptions.customDesc` | Changed | Enter any Bible verse manually | कोई भी बाइबिल आयत खुद दर्ज करें | ഏതെങ്കിലും ബൈബിൾ വാക്യം സ്വയം നൽകുക |
| `addOptions.fromDaily` | Changed | Add from Daily Verse | दैनिक वचन से जोड़ें | ഇന്നത്തെ വചനത്തിൽ നിന്ന് ചേർക്കുക |
| `addOptions.fromDailyDesc` | Changed | Add today's verse to your memory deck | आज का वचन याद वचनों में जोड़ें | ഇന്നത്തെ വചനം മനഃപാഠ വാക്യങ്ങളിലേക്ക് ചേർക്കുക |
| `addOptions.title` | Changed | Add Memory Verse | याद वचन जोड़ें | മനഃപാഠ വാക്യം ചേർക്കുക |
| `addVerse.to` | Changed | To (optional) | तक (वैकल्पिक) | വരെ (നിർബന്ധമില്ല) |
| `add_verse` | New | Add a verse | वचन जोड़ें | വചനം ചേർക്കൂ |
| `champions` | New | Champions | चैंपियन | ചാമ്പ്യന്മാർ |
| `dailyVerseNotLoaded` | Changed | Daily verse not loaded yet. Please wait or go to the home screen first. | दैनिक वचन अभी तक लोड नहीं हुआ है। कृपया प्रतीक्षा करें या पहले होम स्क्रीन पर जाएं। | ഇന്നത്തെ വചനം ഇതുവരെ ലോഡ് ചെയ്തിട്ടില്ല. ദയവായി കാത്തിരിക്കുക അല്ലെങ്കിൽ ആദ്യം ഹോം സ്ക്രീനിലേക്ക് പോകുക. |
| `delete.confirmation` | Changed | Are you sure you want to remove this verse from your memory deck? This action cannot be undone. | क्या आप वाकई इस वचन को अपने याद वचनों से हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती। | നിങ്ങളുടെ മനഃപാഠ വാക്യങ്ങളിൽ നിന്ന് ഈ വാക്യം നീക്കം ചെയ്യാൻ ആഗ്രഹിക്കുന്നുണ്ടോ? ഈ പ്രവർത്തനം പഴയപടിയാക്കാൻ കഴിയില്ല. |
| `delete.success` | Changed | Verse removed from memory deck | वचन याद वचनों से हटा दिया गया | വാക്യം മനഃപാഠ വാക്യങ്ങളിൽ നിന്ന് നീക്കം ചെയ്തു |
| `due` | New | Due | दोहराना है | ബാക്കി |
| `flipCard.day_one` | New | 1 day | 1 दिन | 1 ദിവസം |
| `flipCard.review_one` | New | 1 review | 1 समीक्षा | 1 അവലോകനം |
| `footnote` | New | Saved verses come back for a short review when they are due. | सहेजे वचन समय पर दोहराने के लिए लौटते हैं। | സേവ് ചെയ്ത വാക്യങ്ങൾ സമയത്ത് തിരികെ വരും. |
| `fullyMastered` | New | Fully Mastered | पूर्ण महारत | പൂർണ്ണ പ്രാവീണ്യം |
| `header_line` | New | {streak}-day streak · {count} verses | लगातार {streak} दिन · {count} वचन | {streak} ദിവസം · {count} വാക്യം |
| `header_line_one` | New | {streak}-day streak · {count} verse | लगातार {streak} दिन · {count} वचन | {streak} ദിവസം · {count} വാക്യം |
| `heatMap.dayStreak` | Changed | {count} day streak | लगातार {count} दिन | {count} ദിവസ തുടർച്ച |
| `heatMap.longestStreak` | Changed | Longest streak: {days} days | सबसे लंबी स्ट्रीक: {days} दिन | ഏറ്റവും നീണ്ട തുടർച്ച: {days} ദിവസം |
| `heatMap.longestStreakOne` | New | Longest streak: 1 day | सबसे लंबी स्ट्रीक: 1 दिन | ഏറ്റവും നീണ്ട തുടർച്ച: 1 ദിവസം |
| `optionsMenu.championsSubtitle` | Changed | View top memorizers | सबसे ज़्यादा याद करने वालों को देखें | മികച്ച മനഃപാഠക്കാരെ കാണുക |
| `perfectRecalls` | New | Perfect | पूर्ण स्मरण | മികച്ച സ്മരണ |
| `ratingSheet.perfect.label` | Changed | Perfect! | बिल्कुल सही! | കൃത്യം! |
| `reset.itemBadges` | Changed | Memory badges and challenge progress will be removed | याद वचन बैज और चुनौती की प्रगति हटा दी जाएगी | മനഃപാഠ ബാഡ്ജുകളും വെല്ലുവിളി പുരോഗതിയും നീക്കംചെയ്യും |
| `reset.itemProgress` | Changed | All practice history and mastery will be deleted | सारा अभ्यास इतिहास और महारत हटा दी जाएगी | എല്ലാ പരിശീലന ചരിത്രവും പുരോഗതിയും ഇല്ലാതാക്കും |
| `reset.itemStreak` | Changed | Your memory streak will reset to zero | याद वचनों की स्ट्रीक शून्य हो जाएगी | മനഃപാഠ വാക്യ തുടർച്ച പൂജ്യമാകും |
| `reset.itemVerses` | Changed | Every verse in your deck will be deleted | आपकी सूची का हर वचन हटा दिया जाएगा | നിങ്ങളുടെ ശേഖരത്തിലെ എല്ലാ വചനങ്ങളും ഇല്ലാതാക്കും |
| `reset.success` | Changed | All memory verses deleted | सभी याद वचन हटा दिए गए | എല്ലാ മനഃപാഠ വാക്യങ്ങളും ഇല്ലാതാക്കി |
| `reset.title` | Changed | Delete all memory verses? | सभी याद वचन हटाएं? | എല്ലാ മനഃപാഠ വാക്യങ്ങളും ഇല്ലാതാക്കണോ? |
| `reviewMilestone` | New | Review Milestone | समीक्षा मील का पत्थर | അവലോകന നാഴികക്കല്ല് |
| `save_todays_verse` | New | Save today's verse | आज का वचन सहेजें | ഇന്നത്തെ വചനം ചേർക്കൂ |
| `statistics` | New | Statistics | आँकड़े | കണക്കുകൾ |
| `suggested.alreadyAdded` | Changed | Already in your deck | आपके संग्रह में है | ഇതിനകം ശേഖരത്തിലുണ്ട് |
| `title` | Changed | Memory Verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |

## payments_feedback (35)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `add_screenshot` | New | Add | जोड़ें | ചേർക്കുക |
| `amount` | New | Amount | राशि | തുക |
| `date` | New | Date | तारीख | തീയതി |
| `description` | New | Description | विवरण | വിവരണം |
| `description_hint` | New | Please describe the issue in detail (minimum 10 characters) | कृपया समस्या का पूरा विवरण दें (कम से कम 10 अक्षर) | പ്രശ്നം വിശദമായി വിവരിക്കുക (കുറഞ്ഞത് 10 അക്ഷരങ്ങൾ) |
| `description_too_short` | New | Please enter at least 10 characters | कृपया कम से कम 10 अक्षर लिखें | കുറഞ്ഞത് 10 അക്ഷരങ്ങൾ നൽകുക |
| `generating_pdf` | New | Generating PDF... | PDF बन रहा है... | PDF തയ്യാറാക്കുന്നു... |
| `invoice_downloaded` | New | Invoice downloaded: {file} | इनवॉइस डाउनलोड हो गया: {file} | ഇൻവോയ്‌സ് ഡൗൺലോഡ് ചെയ്തു: {file} |
| `invoice_saved_to` | New | Invoice saved to: {file} | इनवॉइस यहाँ सहेजा गया: {file} | ഇൻവോയ്‌സ് ഇവിടെ സേവ് ചെയ്തു: {file} |
| `issue_duplicate_charge` | New | Duplicate Charge | दो बार शुल्क कटा | ഇരട്ടി ചാർജ് ഈടാക്കി |
| `issue_other` | New | Other Issue | अन्य समस्या | മറ്റ് പ്രശ്നം |
| `issue_payment_failed` | New | Payment Failed | भुगतान विफल | പേയ്‌മെന്റ് പരാജയപ്പെട്ടു |
| `issue_refund_request` | New | Refund Request | रिफ़ंड अनुरोध | റീഫണ്ട് അഭ്യർത്ഥന |
| `issue_tokens_not_credited` | New | Credits Not Added | क्रेडिट नहीं जुड़े | ക്രെഡിറ്റുകൾ ചേർന്നില്ല |
| `issue_type` | New | Issue type | समस्या का प्रकार | പ്രശ്നത്തിന്റെ തരം |
| `issue_wrong_amount` | New | Wrong Amount Charged | गलत राशि काटी गई | തെറ്റായ തുക ഈടാക്കി |
| `ok` | New | OK | ठीक है | ശരി |
| `open_payment_page_failed` | New | Could not open payment page. Please try again. | भुगतान पेज नहीं खुल सका। कृपया फिर से कोशिश करें। | പേയ്‌മെന്റ് പേജ് തുറക്കാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `open_payment_url_failed` | New | Unable to open payment URL: {url} | भुगतान URL नहीं खुल सका: {url} | പേയ്‌മെന്റ് URL തുറക്കാനായില്ല: {url} |
| `payment_awaiting_approval` | New | Payment is awaiting approval. You'll be notified when it's ready. | भुगतान स्वीकृति की प्रतीक्षा में है। तैयार होने पर आपको सूचित किया जाएगा। | പേയ്‌മെന്റ് അംഗീകാരത്തിനായി കാത്തിരിക്കുന്നു. തയ്യാറാകുമ്പോൾ നിങ്ങളെ അറിയിക്കും. |
| `payment_id` | New | Payment ID | भुगतान ID | പേയ്‌മെന്റ് ID |
| `plan_activated` | New | Subscription activated! You now have {plan} access. | सब्सक्रिप्शन सक्रिय हो गया! अब आपके पास {plan} एक्सेस है। | സബ്‌സ്‌ക്രിപ്‌ഷൻ സജീവമായി! ഇപ്പോൾ നിങ്ങൾക്ക് {plan} ആക്‌സസ് ഉണ്ട്. |
| `purchase_received` | New | Purchase received! Activating subscription... | खरीदारी मिल गई! सब्सक्रिप्शन सक्रिय हो रहा है... | വാങ്ങൽ ലഭിച്ചു! സബ്‌സ്‌ക്രിപ്‌ഷൻ സജീവമാക്കുന്നു... |
| `report_body` | New | Describe the issue with your purchase. Our team will review and respond within 24-48 hours. | अपनी खरीदारी की समस्या बताएँ। हमारी टीम 24-48 घंटों में समीक्षा करके जवाब देगी। | നിങ്ങളുടെ വാങ്ങലിലെ പ്രശ്നം വിവരിക്കുക. ഞങ്ങളുടെ ടീം 24-48 മണിക്കൂറിനുള്ളിൽ പരിശോധിച്ച് മറുപടി നൽകും. |
| `report_eyebrow` | New | Purchase support | खरीदारी सहायता | വാങ്ങൽ സഹായം |
| `report_title` | New | Report Issue | समस्या बताएँ | പ്രശ്നം റിപ്പോർട്ട് ചെയ്യുക |
| `save_preference_failed` | New | Failed to save preference. Please try again. | पसंद सहेजी नहीं जा सकी। कृपया फिर से कोशिश करें। | മുൻഗണന സേവ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `screenshots` | New | Screenshots (optional) | स्क्रीनशॉट (वैकल्पिक) | സ്ക്രീൻഷോട്ടുകൾ (നിർബന്ധമില്ല) |
| `store_open_failed_android` | New | Could not open Google Play. Search "Disciplefy" in Google Play > Subscriptions. | Google Play नहीं खुल सका। Google Play > Subscriptions में "Disciplefy" खोजें। | Google Play തുറക്കാനായില്ല. Google Play > Subscriptions-ൽ "Disciplefy" തിരയുക. |
| `store_open_failed_ios` | New | Could not open App Store. Go to Settings > Apple ID > Subscriptions. | App Store नहीं खुल सका। Settings > Apple ID > Subscriptions पर जाएँ। | App Store തുറക്കാനായില്ല. Settings > Apple ID > Subscriptions-ലേക്ക് പോകുക. |
| `submit` | New | Submit Report | रिपोर्ट भेजें | റിപ്പോർട്ട് അയയ്ക്കുക |
| `subscription_created` | New | Subscription created! Opening payment page... | सब्सक्रिप्शन बन गया! भुगतान पेज खुल रहा है... | സബ്‌സ്‌ക്രിപ്‌ഷൻ സൃഷ്ടിച്ചു! പേയ്‌മെന്റ് പേജ് തുറക്കുന്നു... |
| `tokens` | New | Credits | क्रेडिट | ക്രെഡിറ്റുകൾ |
| `transaction_details` | New | Transaction details | लेन-देन का विवरण | ഇടപാട് വിവരങ്ങൾ |
| `upload_web_only` | New | Image upload is only supported on web | तस्वीर अपलोड केवल वेब पर उपलब्ध है | ചിത്രം അപ്‌ലോഡ് വെബിൽ മാത്രമേ ലഭ്യമാകൂ |

## study_guide (35)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `actions.pdf_saved_to` | New | Saved to Download/Disciplefy | Download/Disciplefy में सहेजा गया | Download/Disciplefy-ൽ സേവ് ചെയ്തു |
| `actions.save_study` | Changed | Save Study | सहेजें | സേവ് ചെയ്യൂ |
| `actions.saved` | Changed | Saved | सहेजा गया | സേവ് ആയി |
| `error.default_message` | Changed | We couldn't generate your study guide. Please try again. | हम आपकी अध्ययन गाइड नहीं बना सके। कृपया फिर से कोशिश करें। | പഠന ഗൈഡ് ഉണ്ടാക്കാൻ കഴിഞ്ഞില്ല. വീണ്ടും ശ്രമിക്കൂ. |
| `error.title_alt` | Changed | We couldn't generate a study guide | अध्ययन गाइड नहीं बना सके | പഠന ഗൈഡ് ഉണ്ടാക്കാൻ കഴിഞ്ഞില്ല |
| `error.view_saved` | Changed | View Saved Guides | सहेजी गई गाइड देखें | സേവ് ചെയ്ത ഗൈഡുകൾ കാണുക |
| `fellowship.card_title` | Changed | Share with Your Fellowship | अपनी संगति के साथ साझा करें | നിങ്ങളുടെ കൂട്ടായ്മയുമായി പങ്കിടുക |
| `fellowship.share_title` | Changed | Share with Fellowship | संगति में साझा करें | കൂട്ടായ്മയിൽ പങ്കിടുക |
| `fellowship.walkthrough_desc` | Changed | Write a reflection, prayer, or insight and share it with your fellowship group. | अपनी प्रार्थना, विचार या अंतर्दृष्टि लिखें और अपनी संगति के साथ साझा करें। | ഒരു ധ്യാനം, പ്രാർത്ഥന, അല്ലെങ്കിൽ ഉൾക്കാഴ്ച എഴുതി നിങ്ങളുടെ കൂട്ടായ്മ ഗ്രൂപ്പുമായി പങ്കിടൂ. |
| `link_unavailable` | New | This study guide isn't available. It may have been removed. | यह अध्ययन गाइड उपलब्ध नहीं है। इसे हटाया जा सकता है। | ഈ പഠന ഗൈഡ് ലഭ്യമല്ല. ഇത് നീക്കം ചെയ്തിരിക്കാം. |
| `menu.complete` | New | Mark as complete | पूरा हुआ चिह्नित करें | പൂർത്തിയായി എന്ന് അടയാളപ്പെടുത്തൂ |
| `menu.completed` | New | Completed | पूरा हुआ | പൂർത്തിയായി |
| `menu.download_pdf` | New | Download PDF | PDF डाउनलोड करें | PDF ഡൗൺലോഡ് ചെയ്യൂ |
| `menu.more` | New | More options | और विकल्प | കൂടുതൽ |
| `menu.save` | New | Save study | अध्ययन सहेजें | പഠനം സേവ് ചെയ്യൂ |
| `menu.saved` | New | Saved | सहेजा गया | സേവ് ചെയ്തു |
| `menu.share` | New | Share | साझा करें | പങ്കിടൂ |
| `menu.share_fellowship` | New | Share to fellowship | संगति में साझा करें | കൂട്ടായ്മയിൽ പങ്കിടൂ |
| `menu.text_size` | New | Text size | अक्षर का आकार | അക്ഷര വലിപ്പം |
| `messages.auth_required_message` | Changed | Please sign in to save this study guide to your library | इसे सहेजने के लिए साइन इन करें | ഇത് സേവ് ചെയ്യാൻ സൈൻ ഇൻ ചെയ്യൂ |
| `messages.save_error` | Changed | Failed to save study guide | गाइड सहेजी नहीं जा सकी | ഗൈഡ് സേവ് ആയില്ല |
| `messages.save_success` | Changed | Study guide saved successfully | गाइड सहेजी गई | ഗൈഡ് സേവ് ആയി |
| `page_title` | Changed | Study Guide | अध्ययन गाइड | പഠന ഗൈഡ് |
| `share_read_more` | New | Read the full study guide: | पूरी अध्ययन गाइड पढ़ें: | പൂർണ്ണ പഠന ഗൈഡ് വായിക്കുക: |
| `streaming.loading` | Changed | Loading study guide... | अध्ययन गाइड लोड हो रही है... | പഠന ഗൈഡ് ലോഡ് ചെയ്യുന്നു... |
| `streaming.sections` | Changed | {count}/{total} sections | {count}/{total} भाग | {count}/{total} ഭാഗങ്ങൾ |
| `text_size.done` | New | Done | हो गया | പൂർത്തിയായി |
| `text_size.eyebrow` | New | READING | पढ़ना | വായന |
| `text_size.preview` | New | The Lord is my shepherd; I shall not want. | यहोवा मेरा चरवाहा है; मुझे कुछ घटी न होगी। | യഹോവ എന്റെ ഇടയനാകുന്നു; എനിക്കു മുട്ടുണ്ടാകയില്ല. |
| `text_size.reset` | New | Reset to default | डिफ़ॉल्ट पर लौटें | ഡിഫോൾട്ടിലേക്ക് മാറ്റൂ |
| `walkthrough.chat.title` | Changed | Follow-Up Chat | आगे के सवाल | തുടർചോദ്യങ്ങൾ |
| `walkthrough.menu.desc` | Changed | Change text size, share, save, or download a PDF of your study guide. | अक्षर का आकार बदलें, शेयर करें, सहेजें या अपनी अध्ययन गाइड का PDF डाउनलोड करें। | അക്ഷര വലുപ്പം മാറ്റൂ, ഷെയർ ചെയ്യൂ, സേവ് ചെയ്യൂ, അല്ലെങ്കിൽ PDF ഡൗൺലോഡ് ചെയ്യൂ. |
| `walkthrough.notes.desc` | Changed | Write your thoughts, prayers, and insights. Notes are saved automatically. | अपने विचार, प्रार्थनाएं और अंतर्दृष्टि लिखें। नोट्स अपने आप सहेजे जाते हैं। | നിങ്ങളുടെ ചിന്തകൾ, പ്രാർത്ഥനകൾ, ഉൾക്കാഴ്ചകൾ എഴുതൂ. കുറിപ്പുകൾ സ്വയം സേവ് ആകും. |
| `walkthrough.tts.desc` | Changed | Tap to hear your study guide read aloud. Great for hands-free devotional time. | अपनी अध्ययन गाइड को ज़ोर से पढ़वाने के लिए टैप करें। सुनते हुए भक्ति के लिए बढ़िया। | നിങ്ങളുടെ പഠന ഗൈഡ് ഉച്ചത്തിൽ വായിക്കാൻ ടാപ്പ് ചെയ്യൂ. കേട്ടുകൊണ്ടുള്ള ഭക്തിക്ക് അനുയോജ്യം. |
| `walkthrough.tts.title` | Changed | Listen to Your Study | अध्ययन सुनें | പഠനം കേൾക്കൂ |

## downloads (29)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_available_offline` | New | All {total} guides available offline | सभी {total} गाइड ऑफ़लाइन उपलब्ध हैं | എല്ലാ {total} ഗൈഡുകളും ഓഫ്‌ലൈനിൽ ലഭ്യമാണ് |
| `available_offline` | New | Available offline | ऑफ़लाइन उपलब्ध | ഓഫ്‌ലൈനിൽ ലഭ്യമാണ് |
| `deselect_all` | New | Deselect all | चयन हटाएँ | തിരഞ്ഞെടുപ്പ് മാറ്റുക |
| `download_count` | New | Download {count} guides | {count} गाइड डाउनलोड करें | {count} ഗൈഡുകൾ ഡൗൺലോഡ് ചെയ്യുക |
| `download_count_with_cost` | New | Download {count} guides ({cost} credits) | {count} गाइड डाउनलोड करें ({cost} क्रेडिट) | {count} ഗൈഡുകൾ ഡൗൺലോഡ് ചെയ്യുക ({cost} ക്രെഡിറ്റ്) |
| `download_for_offline` | New | Download for offline | ऑफ़लाइन के लिए डाउनलोड करें | ഓഫ്‌ലൈനിനായി ഡൗൺലോഡ് ചെയ്യുക |
| `download_more` | New | Download {count} more guides | {count} और गाइड डाउनलोड करें | {count} ഗൈഡുകൾ കൂടി ഡൗൺലോഡ് ചെയ്യുക |
| `download_one_more` | New | Download 1 more guide | 1 और गाइड डाउनलोड करें | 1 ഗൈഡ് കൂടി ഡൗൺലോഡ് ചെയ്യുക |
| `downloading_offline_guides` | New | Downloading offline guides | ऑफ़लाइन गाइड डाउनलोड हो रहे हैं | ഓഫ്‌ലൈൻ ഗൈഡുകൾ ഡൗൺലോഡ് ചെയ്യുന്നു |
| `downloading_progress` | New | Downloading {done} of {total} guides… | {total} में से {done} गाइड डाउनलोड हो रहे हैं… | {total}-ൽ {done} ഗൈഡുകൾ ഡൗൺലോഡ് ചെയ്യുന്നു… |
| `go_back` | New | Go Back | वापस जाएँ | തിരികെ പോകുക |
| `guides_selected` | New | {count} guides selected | {count} गाइड चुने गए | {count} ഗൈഡുകൾ തിരഞ്ഞെടുത്തു |
| `guides_with_cost` | New | {count} guides · {cost} credits | {count} गाइड · {cost} क्रेडिट | {count} ഗൈഡുകൾ · {cost} ക്രെഡിറ്റ് |
| `not_downloaded_offline` | New | This learning path hasn't been downloaded. Download it while online to access it offline. | यह सीखने का रास्ता डाउनलोड नहीं हुआ है। ऑफ़लाइन उपयोग के लिए इसे ऑनलाइन रहते हुए डाउनलोड करें। | ഈ പഠന പാത ഡൗൺലോഡ് ചെയ്തിട്ടില്ല. ഓഫ്‌ലൈനിൽ ഉപയോഗിക്കാൻ ഓൺലൈനായിരിക്കുമ്പോൾ ഡൗൺലോഡ് ചെയ്യുക. |
| `offline_guides` | New | Offline guides | ऑफ़लाइन गाइड | ഓഫ്‌ലൈൻ ഗൈഡുകൾ |
| `partly_downloaded` | New | {done} downloaded · {missing} not yet downloaded | {done} डाउनलोड हुए · {missing} अभी बाकी | {done} ഡൗൺലോഡ് ചെയ്തു · {missing} ബാക്കി |
| `pause` | New | Pause | रोकें | താൽക്കാലികമായി നിർത്തുക |
| `remove_all` | New | Remove all downloads | सभी डाउनलोड हटाएँ | എല്ലാ ഡൗൺലോഡുകളും നീക്കുക |
| `select_all` | New | Select all | सभी चुनें | എല്ലാം തിരഞ്ഞെടുക്കുക |
| `select_at_least_one` | New | Select at least one guide | कम से कम एक गाइड चुनें | കുറഞ്ഞത് ഒരു ഗൈഡ് തിരഞ്ഞെടുക്കുക |
| `select_guides` | New | Select guides to download | डाउनलोड करने के लिए गाइड चुनें | ഡൗൺലോഡ് ചെയ്യാൻ ഗൈഡുകൾ തിരഞ്ഞെടുക്കുക |
| `share_failed` | New | Could not open the share sheet. | शेयर नहीं खुल सका। | ഷെയർ ചെയ്യാൻ കഴിഞ്ഞില്ല. |
| `share_path` | New | Share this path | इस रास्ते को साझा करें | ഈ പാത പങ്കിടുക |
| `status_downloaded` | New | Downloaded | डाउनलोड हुआ | ഡൗൺലോഡ് ചെയ്തു |
| `status_downloading` | New | Downloading… | डाउनलोड हो रहा है… | ഡൗൺലോഡ് ചെയ്യുന്നു… |
| `status_failed` | New | Failed — tap to retry | विफल — पुनः प्रयास के लिए टैप करें | പരാജയപ്പെട്ടു — വീണ്ടും ശ്രമിക്കാൻ ടാപ്പ് ചെയ്യുക |
| `status_not_downloaded` | New | Not downloaded | डाउनलोड नहीं हुआ | ഡൗൺലോഡ് ചെയ്തിട്ടില്ല |
| `status_not_queued` | New | Not in queue | कतार में नहीं | ക്യൂവിൽ ഇല്ല |
| `status_waiting` | New | Waiting in queue | कतार में प्रतीक्षारत | ക്യൂവിൽ കാത്തിരിക്കുന്നു |

## account (28)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `benefit_groups` | New | Join groups and keep your progress | समूह से जुड़ें, प्रगति रखें | ഗ്രൂപ്പിൽ ചേരാം, പുരോഗതി സൂക്ഷിക്കാം |
| `benefit_moves` | New | Your progress on this phone moves over | इस फ़ोन की प्रगति साथ आएगी | ഈ ഫോണിലെ പുരോഗതി നിലനിൽക്കും |
| `benefit_paths` | New | Unlock every learning path | सभी रास्ते खोलें | എല്ലാ പാതകളും തുറക്കാം |
| `body` | New | So your progress and groups stay with you on any phone. | ताकि आपकी प्रगति हर फ़ोन पर साथ रहे। | ഏത് ഫോണിലും പുരോഗതി കൂടെയുണ്ടാകാൻ. |
| `check_email` | New | Check your email to confirm: {email} | पुष्टि के लिए ईमेल देखें: {email} | സ്ഥിരീകരിക്കാൻ ഇമെയിൽ നോക്കൂ: {email} |
| `continue_apple` | New | Continue with Apple | Apple से जारी रखें | Apple വഴി തുടരുക |
| `continue_email` | New | Continue with email | ईमेल से जारी रखें | ഇമെയിൽ വഴി തുടരുക |
| `continue_google` | New | Continue with Google | Google से जारी रखें | Google വഴി തുടരുക |
| `continue_guest` | New | Continue as guest | मेहमान के रूप में जारी रखें | അതിഥിയായി തുടരുക |
| `discipler_title` | New | Discipler needs an account | Discipler के लिए खाता चाहिए | Discipler-ന് അക്കൗണ്ട് വേണം |
| `dismiss` | New | Dismiss | हटाएँ | മാറ്റുക |
| `email_exists` | New | This email already has an account. Enter its password, or reset it. | इस ईमेल का खाता है। उसका पासवर्ड डालें या रीसेट करें। | ഈ ഇമെയിലിന് അക്കൗണ്ടുണ്ട്. പാസ്‌വേഡ് നൽകൂ, അല്ലെങ്കിൽ റീസെറ്റ് ചെയ്യൂ. |
| `generate_title` | New | Create an account to generate studies | अध्ययन बनाने के लिए खाता बनाएँ | പഠനം ഉണ്ടാക്കാൻ അക്കൗണ്ട് വേണം |
| `generic_title` | New | Create a free account | मुफ़्त खाता बनाएँ | സൗജന്യ അക്കൗണ്ട് തുടങ്ങൂ |
| `groups_title` | New | Groups need an account | समूह के लिए खाता चाहिए | ഗ്രൂപ്പിന് അക്കൗണ്ട് വേണം |
| `keep_cta` | New | Sign up to keep them | रखने के लिए साइन अप करें | സൂക്ഷിക്കാൻ സൈൻ അപ്പ് |
| `keep_days_safe` | New | Keep these {n} days safe | अपनी {n} दिन की स्ट्रीक बचाएँ | {n} ദിവസ തുടർച്ച കാക്കൂ |
| `lessons_count` | New | {n} lessons | {n} पाठ | {n} പാഠങ്ങൾ |
| `link_failed` | New | Couldn't sign up. Please try again. | साइन अप नहीं हुआ। फिर कोशिश करें। | സൈൻ അപ്പ് ആയില്ല. വീണ്ടും ശ്രമിക്കൂ. |
| `listen_title` | New | Listening needs an account | सुनने के लिए खाता चाहिए | കേൾക്കാൻ അക്കൗണ്ട് വേണം |
| `memory_verses_title` | New | Memory verses need an account | याद वचनों के लिए खाता चाहिए | മനഃപാഠ വാക്യങ്ങൾക്ക് അക്കൗണ്ട് വേണം |
| `merge_pending` | New | Signed in. Your progress moves over soon. | साइन इन हो गया। प्रगति जल्द आएगी। | സൈൻ ഇൻ ആയി. പുരോഗതി ഉടൻ എത്തും. |
| `next_paths` | New | Your next paths | आपके अगले रास्ते | അടുത്ത പാതകൾ |
| `not_now` | New | Not now | अभी नहीं | പിന്നീട് |
| `path_finished_title` | New | Sign up to keep your progress and start your next path | प्रगति रखें, अगला रास्ता शुरू करें — साइन अप करें | സൈൻ അപ്പ് ചെയ്ത് അടുത്ത പാത തുടങ്ങൂ |
| `save_progress_title` | New | Sign up to save your progress and continue | प्रगति सहेजने के लिए साइन अप करें | പുരോഗതി സൂക്ഷിക്കാൻ സൈൻ അപ്പ് |
| `second_path_title` | New | Your next path needs an account | अगले रास्ते के लिए खाता चाहिए | അടുത്ത പാതയ്ക്ക് അക്കൗണ്ട് വേണം |
| `sign_up_to_start` | New | Sign up to start | साइन अप करें | സൈൻ അപ്പ് |

## home (28)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_caught_up` | New | All caught up | सब पूरा हो गया | എല്ലാം പൂർത്തിയായി |
| `all_paths` | New | All paths | सभी रास्ते | എല്ലാ പാതകളും |
| `available_offline` | New | Available offline | ऑफ़लाइन उपलब्ध | ഓഫ്‌ലൈനിൽ ലഭ്യമാണ് |
| `browse_paths` | New | Browse learning paths | सीखने के रास्ते देखें | പഠന പാതകൾ കാണൂ |
| `browse_paths_hint` | New | Pick a path to start your journey | अपनी यात्रा शुरू करने के लिए एक रास्ता चुनें | യാത്ര തുടങ്ങാൻ ഒരു പാത തിരഞ്ഞെടുക്കൂ |
| `continue_learning` | New | Continue learning | सीखना जारी रखें | പഠനം തുടരൂ |
| `day_streak` | New | {count}-day streak | लगातार {count} दिन | {count} ദിവസ തുടർച്ച |
| `explore_learning_paths` | Changed | Explore Learning Paths | सीखने के रास्ते देखें | പഠന പാതകൾ കാണുക |
| `good_afternoon` | New | Good afternoon, {name} | शुभ दोपहर, {name} | ശുഭ മദ്ധ്യാഹ്നം, {name} |
| `good_evening` | New | Good evening, {name} | शुभ संध्या, {name} | ശുഭ സായാഹ്നം, {name} |
| `good_morning` | New | Good morning, {name} | सुप्रभात, {name} | സുപ്രഭാതം, {name} |
| `keep_it_alive` | New | Keep it alive | इसे बनाए रखें | തുടർന്നും നിലനിർത്തൂ |
| `meeting_live` | New | LIVE | लाइव | തത്സമയം |
| `meeting_now_ends` | New | Now · ends {time} | अभी · {time} पर समाप्त | ഇപ്പോൾ · {time}-ന് അവസാനിക്കും |
| `meeting_today` | New | Today | आज | ഇന്ന് |
| `meeting_today_at` | New | Today · {time} | आज · {time} | ഇന്ന് · {time} |
| `memory_verses` | Changed | Memory Verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |
| `no_streak_yet` | New | No streak yet | अभी कोई स्ट्रीक नहीं | ഇതുവരെ തുടർച്ച ഇല്ല |
| `nothing_due` | New | Nothing due today | आज कुछ बाकी नहीं | ഇന്ന് ഒന്നും ബാക്കിയില്ല |
| `personalize_prompt_description` | Changed | Help us understand your spiritual journey so we can suggest the right paths for you. | अपनी आध्यात्मिक यात्रा के बारे में बताएं ताकि हम आपके लिए सही रास्ता सुझा सकें। | നിങ്ങളുടെ ആത്മീയ യാത്രയെക്കുറിച്ച് പറയൂ, ഉചിതമായ പാതകൾ നിർദ്ദേശിക്കാം. |
| `ready_for_next_step` | New | You're ready for your next step | आप अगले कदम के लिए तैयार हैं | അടുത്ത ചുവടിനായി നിങ്ങൾ തയ്യാറാണ് |
| `review_more` | New | +{count} more | +{count} और | +{count} കൂടി |
| `start_here` | New | Start here · {count} lessons | यहाँ से शुरू करें · {count} पाठ | ഇവിടെ തുടങ്ങൂ · {count} പാഠങ്ങൾ |
| `start_streak_hint` | New | Read today's verse | आज का वचन पढ़ें | ഇന്നത്തെ വചനം വായിക്കൂ |
| `study_now` | New | Study now | अभी अध्ययन करें | ഇപ്പോൾ പഠിക്കൂ |
| `to_review` | New | {count} to review | {count} समीक्षा के लिए | {count} പുനരവലോകനത്തിന് |
| `topics_progress` | New | {done} of {total} lessons | {total} में से {done} पाठ | {total}-ൽ {done} പാഠങ്ങൾ |
| `topics_progress_next` | New | {done} of {total} · Next: {title} | {total} में से {done} · अगला: {title} | {total}-ൽ {done} · അടുത്തത്: {title} |

## community_fellowship (25)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `advance_failed` | New | Couldn't move to the next lesson. | अगले पाठ पर नहीं जा सके। | അടുത്ത പാഠത്തിലേക്ക് നീങ്ങാനായില്ല. |
| `assign_failed` | New | Couldn't assign the learning path. | सीखने का रास्ता सौंपा नहीं जा सका। | പഠന പാത നൽകാനായില്ല. |
| `comment_hint` | New | Add a comment… | टिप्पणी जोड़ें… | ഒരു കമന്റ് ചേർക്കുക… |
| `comments_empty` | New | No replies yet. Be the first! | अभी तक कोई उत्तर नहीं। पहले आप लिखें! | ഇതുവരെ മറുപടികളില്ല. ആദ്യം നിങ്ങൾ എഴുതൂ! |
| `comments_load_failed` | New | Couldn't load replies. | उत्तर लोड नहीं हो सके। | മറുപടികൾ ലോഡ് ചെയ്യാനായില്ല. |
| `group_progress` | New | Group progress | समूह की प्रगति | ഗ്രൂപ്പ് പുരോഗതി |
| `mention` | New | Mention someone | किसी का उल्लेख करें | ആരെയെങ്കിലും പരാമർശിക്കുക |
| `no_paths` | New | No learning paths available. | कोई सीखने का रास्ता उपलब्ध नहीं है। | പഠന പാതകളൊന്നും ലഭ്യമല്ല. |
| `now` | New | Now | अभी | ഇപ്പോൾ |
| `path_active` | New | Learning path active | सीखने का रास्ता सक्रिय | പഠന പാത സജീവം |
| `post_hint_general` | New | What's on your heart? | आपके मन में क्या है? | നിങ്ങളുടെ മനസ്സിൽ എന്താണ്? |
| `post_hint_praise` | New | Celebrate what God has done! Share your praise… | परमेश्वर ने जो किया है उसका उत्सव मनाएँ! अपनी स्तुति साझा करें… | ദൈവം ചെയ്തതിനെ ആഘോഷിക്കുക! നിങ്ങളുടെ സ്തുതി പങ്കിടുക… |
| `post_hint_prayer` | New | Share a prayer request with your fellowship… | अपनी संगति के साथ प्रार्थना निवेदन साझा करें… | നിങ്ങളുടെ കൂട്ടായ്മയുമായി ഒരു പ്രാർത്ഥനാ വിഷയം പങ്കിടുക… |
| `post_hint_question` | New | Ask a question about faith or Scripture… | विश्वास या बाइबल के बारे में सवाल पूछें… | വിശ്വാസത്തെക്കുറിച്ചോ തിരുവെഴുത്തിനെക്കുറിച്ചോ ഒരു ചോദ്യം ചോദിക്കുക… |
| `post_title` | New | Post | पोस्ट | പോസ്റ്റ് |
| `post_unavailable` | New | This post isn't available. It may have been removed. | यह पोस्ट उपलब्ध नहीं है। हो सकता है इसे हटा दिया गया हो। | ഈ പോസ്റ്റ് ലഭ്യമല്ല. ഇത് നീക്കം ചെയ്തിരിക്കാം. |
| `report_reason_short` | New | Please write at least 5 characters. | कृपया कम से कम 5 अक्षर लिखें। | കുറഞ്ഞത് 5 അക്ഷരങ്ങളെങ്കിലും എഴുതുക. |
| `reset_failed` | New | Couldn't reset progress. | प्रगति रीसेट नहीं हो सकी। | പുരോഗതി പുനഃസജ്ജമാക്കാനായില്ല. |
| `send` | New | Send | भेजें | അയയ്ക്കുക |
| `studying_together` | New | Studying together | साथ मिलकर अध्ययन | ഒരുമിച്ച് പഠിക്കുന്നു |
| `type_desc_general` | New | Share anything | कुछ भी साझा करें | എന്തും പങ്കിടുക |
| `type_desc_praise` | New | Praise God | परमेश्वर की स्तुति करें | ദൈവത്തെ സ്തുതിക്കുക |
| `type_desc_prayer` | New | Prayer request | प्रार्थना निवेदन | പ്രാർത്ഥനാ വിഷയം |
| `type_desc_question` | New | Ask anything | कुछ भी पूछें | എന്തും ചോദിക്കുക |
| `view_all_posts` | New | View all posts | सभी पोस्ट देखें | എല്ലാ പോസ്റ്റുകളും കാണുക |

## profile_setup (23)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `add_photo` | New | Add profile photo | प्रोफ़ाइल फ़ोटो जोड़ें | പ്രൊഫൈൽ ഫോട്ടോ ചേർക്കുക |
| `age_group` | New | Age group | आयु वर्ग | പ്രായ വിഭാഗം |
| `continue` | New | Continue | आगे बढ़ें | തുടരുക |
| `eyebrow` | New | Your profile | आपकी प्रोफ़ाइल | നിങ്ങളുടെ പ്രൊഫൈൽ |
| `first_name` | New | First name | पहला नाम | ആദ്യ പേര് |
| `first_name_required` | New | First name is required | पहला नाम आवश्यक है | ആദ്യ പേര് ആവശ്യമാണ് |
| `interest_bible_study` | New | Bible Study | बाइबल अध्ययन | ബൈബിൾ പഠനം |
| `interest_community` | New | Community | समुदाय | കൂട്ടായ്മ |
| `interest_evangelism` | New | Evangelism | सुसमाचार प्रचार | സുവിശേഷീകരണം |
| `interest_family` | New | Family | परिवार | കുടുംബം |
| `interest_leadership` | New | Leadership | नेतृत्व | നേതൃത്വം |
| `interest_missions` | New | Missions | मिशन | മിഷനുകൾ |
| `interest_prayer` | New | Prayer | प्रार्थना | പ്രാർത്ഥന |
| `interest_theology` | New | Theology | धर्मशास्त्र | ദൈവശാസ്ത്രം |
| `interest_worship` | New | Worship | आराधना | ആരാധന |
| `interest_youth_ministry` | New | Youth Ministry | युवा सेवकाई | യുവജന ശുശ്രൂഷ |
| `interests` | New | Interests | रुचियाँ | താൽപ്പര്യങ്ങൾ |
| `interests_hint` | New | Select topics you're interested in learning about (select at least one) | वे विषय चुनें जिनके बारे में आप सीखना चाहते हैं (कम से कम एक चुनें) | നിങ്ങൾ പഠിക്കാൻ ആഗ്രഹിക്കുന്ന വിഷയങ്ങൾ തിരഞ്ഞെടുക്കുക (കുറഞ്ഞത് ഒന്ന്) |
| `last_name` | New | Last name | अंतिम नाम | അവസാന പേര് |
| `last_name_required` | New | Last name is required | अंतिम नाम आवश्यक है | അവസാന പേര് ആവശ്യമാണ് |
| `name` | New | Name | नाम | പേര് |
| `subtitle` | New | Help us personalize your Bible study experience by sharing a bit about yourself. | अपने बारे में थोड़ा बताकर अपने बाइबल अध्ययन अनुभव को व्यक्तिगत बनाने में हमारी मदद करें। | നിങ്ങളെക്കുറിച്ച് അൽപ്പം പങ്കുവെച്ച് നിങ്ങളുടെ ബൈബിൾ പഠന അനുഭവം വ്യക്തിഗതമാക്കാൻ ഞങ്ങളെ സഹായിക്കൂ. |
| `title` | New | Tell us about yourself | हमें अपने बारे में बताएं | നിങ്ങളെക്കുറിച്ച് പറയൂ |

## first_run (21)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `back` | New | Back | पीछे | പിന്നോട്ട് |
| `continue` | New | Continue | आगे | തുടരുക |
| `english_bible` | New | Berean Standard Bible | Berean Standard Bible | Berean Standard Bible |
| `error` | New | Couldn't start the lesson. Check your connection and try again. | पाठ शुरू नहीं हुआ। इंटरनेट देखकर फिर कोशिश करें। | പാഠം തുടങ്ങാനായില്ല. കണക്ഷൻ നോക്കി വീണ്ടും ശ്രമിക്കൂ. |
| `error_has_path` | New | You already have a path. Continue it from Home. | आपका एक रास्ता पहले से है। होम से जारी रखें। | നിങ്ങൾക്ക് ഒരു പാതയുണ്ട്. ഹോമിൽ നിന്ന് തുടരൂ. |
| `go_home` | New | Go to Home | होम पर जाएँ | ഹോമിലേക്ക് |
| `goal_title` | New | What would you like to grow in? | आप किसमें बढ़ना चाहते हैं? | എന്തിൽ വളരണം? |
| `have_account` | New | Already have an account? | पहले से खाता है? | അക്കൗണ്ട് ഉണ്ടോ? |
| `log_in` | New | Log in | लॉग इन | ലോഗിൻ |
| `path_meta` | New | {title} · {n} lessons | {title} · {n} पाठ | {title} · {n} പാഠം |
| `pick_one` | New | Pick one. It sets your first learning path; switch any time. | एक चुनें। इससे पहला रास्ता तय होगा; कभी भी बदलें। | ഒന്ന് തിരഞ്ഞെടുക്കൂ. പിന്നീട് മാറ്റാം. |
| `pick_one_guest` | New | Pick one to start. Create a free account later to unlock all {n} paths. | एक चुनें। बाद में मुफ़्त खाता बनाकर सभी {n} रास्ते खोलें। | ഒന്ന് തിരഞ്ഞെടുക്കുക. പിന്നീട് സൗജന്യ അക്കൗണ്ട് ഉണ്ടാക്കി എല്ലാ {n} പാതകളും തുറക്കാം. |
| `pick_one_guest_plain` | New | Pick one to start. Create a free account later to unlock every path. | एक चुनें। बाद में मुफ़्त खाता बनाकर सभी रास्ते खोलें। | ഒന്ന് തിരഞ്ഞെടുക്കുക. പിന്നീട് സൗജന്യ അക്കൗണ്ട് ഉണ്ടാക്കി എല്ലാ പാതകളും തുറക്കാം. |
| `retry` | New | Try again | फिर कोशिश करें | വീണ്ടും ശ്രമിക്കൂ |
| `skip` | New | Skip | छोड़ें | ഒഴിവാക്കൂ |
| `start_lesson_one` | New | Start lesson 1 | पाठ 1 शुरू करें | പാഠം 1 തുടങ്ങാം |
| `step` | New | Step {n} of {total} | चरण {n}/{total} | ഘട്ടം {n}/{total} |
| `terms` | New | By continuing you agree to our Terms and Privacy Policy. | आगे बढ़कर आप हमारी शर्तें और गोपनीयता नीति मानते हैं। | തുടരുമ്പോൾ നിബന്ധനകളും സ്വകാര്യതാ നയവും അംഗീകരിക്കുന്നു. |
| `welcome_eyebrow` | New | Welcome | स्वागत है | സ്വാഗതം |
| `welcome_subtitle` | New | A daily verse and a short lesson, in your language. | आपकी भाषा में रोज़ एक वचन और छोटा पाठ। | നിങ്ങളുടെ ഭാഷയിൽ ദിവസവും ഒരു വചനവും ചെറിയ പാഠവും. |
| `welcome_title` | New | Grow in God's Word every day | हर दिन परमेश्वर के वचन में बढ़ें | ദിവസവും ദൈവവചനത്തിൽ വളരുക |

## phone_auth (21)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `country_code` | New | Country code | देश कोड | രാജ്യ കോഡ് |
| `eyebrow` | New | Sign in with phone | फ़ोन से साइन इन करें | ഫോൺ വഴി സൈൻ ഇൻ |
| `otp_digit` | New | Digit {n} of 6 | 6 में से अंक {n} | 6-ൽ {n}-ാം അക്കം |
| `otp_expires_in` | New | Code expires in {time} | कोड {time} में समाप्त होगा | കോഡ് {time}-ൽ കാലഹരണപ്പെടും |
| `otp_eyebrow` | New | Verify phone | फ़ोन सत्यापित करें | ഫോൺ സ്ഥിരീകരിക്കുക |
| `otp_help` | New | Didn't receive the code? Check your spam folder or try resending. | कोड नहीं मिला? अपना स्पैम फ़ोल्डर देखें या दोबारा भेजें। | കോഡ് ലഭിച്ചില്ലേ? സ്പാം ഫോൾഡർ പരിശോധിക്കുക അല്ലെങ്കിൽ വീണ്ടും അയയ്ക്കുക. |
| `otp_label` | New | Verification code | सत्यापन कोड | സ്ഥിരീകരണ കോഡ് |
| `otp_resend` | New | Resend code | कोड दोबारा भेजें | കോഡ് വീണ്ടും അയയ്ക്കുക |
| `otp_resend_in` | New | Resend in {time} | {time} में दोबारा भेजें | {time}-ൽ വീണ്ടും അയയ്ക്കാം |
| `otp_sent_to` | New | We sent a code to {phone} | हमने {phone} पर एक कोड भेजा है | {phone} എന്ന നമ്പറിലേക്ക് ഞങ്ങൾ ഒരു കോഡ് അയച്ചു |
| `otp_title` | New | Enter verification code | सत्यापन कोड दर्ज करें | സ്ഥിരീകരണ കോഡ് നൽകുക |
| `otp_verify` | New | Verify code | कोड सत्यापित करें | കോഡ് സ്ഥിരീകരിക്കുക |
| `phone_hint` | New | Enter phone number | फ़ोन नंबर दर्ज करें | ഫോൺ നമ്പർ നൽകുക |
| `phone_label` | New | Phone number | फ़ोन नंबर | ഫോൺ നമ്പർ |
| `phone_required` | New | Please enter your phone number | कृपया अपना फ़ोन नंबर दर्ज करें | ദയവായി നിങ്ങളുടെ ഫോൺ നമ്പർ നൽകുക |
| `phone_too_short` | New | Phone number is too short | फ़ोन नंबर बहुत छोटा है | ഫോൺ നമ്പർ വളരെ ചെറുതാണ് |
| `secure_body` | New | Your phone number will be used only for authentication and will not be shared with third parties. | आपका फ़ोन नंबर केवल प्रमाणीकरण के लिए उपयोग किया जाएगा और किसी तीसरे पक्ष के साथ साझा नहीं किया जाएगा। | നിങ്ങളുടെ ഫോൺ നമ്പർ പ്രാമാണീകരണത്തിന് മാത്രമേ ഉപയോഗിക്കൂ, മൂന്നാം കക്ഷികളുമായി പങ്കിടില്ല. |
| `secure_title` | New | Secure verification | सुरक्षित सत्यापन | സുരക്ഷിത സ്ഥിരീകരണം |
| `send_code` | New | Send verification code | सत्यापन कोड भेजें | സ്ഥിരീകരണ കോഡ് അയയ്ക്കുക |
| `subtitle` | New | We'll send you a verification code to confirm your number | आपका नंबर पुष्टि करने के लिए हम आपको एक सत्यापन कोड भेजेंगे | നിങ്ങളുടെ നമ്പർ സ്ഥിരീകരിക്കാൻ ഞങ്ങൾ ഒരു സ്ഥിരീകരണ കോഡ് അയയ്ക്കും |
| `title` | New | Enter your phone number | अपना फ़ोन नंबर दर्ज करें | നിങ്ങളുടെ ഫോൺ നമ്പർ നൽകുക |

## guide_feedback (19)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `already_saved` | New | This study guide is already saved. | यह अध्ययन गाइड पहले से सहेजी हुई है। | ഈ പഠന ഗൈഡ് ഇതിനകം സേവ് ചെയ്തിട്ടുണ്ട്. |
| `auth_expired` | New | Your session has expired. Please sign in again. | आपका सत्र समाप्त हो गया है। कृपया फिर से साइन इन करें। | നിങ്ങളുടെ സെഷൻ കാലഹരണപ്പെട്ടു. വീണ്ടും സൈൻ ഇൻ ചെയ്യുക. |
| `completed_while_away` | New | Your study guide finished while you were away! | आपके दूर रहते हुए आपकी अध्ययन गाइड तैयार हो गई! | നിങ്ങൾ മാറിനിന്നപ്പോൾ നിങ്ങളുടെ പഠന ഗൈഡ് തയ്യാറായി! |
| `fellowship_next_guide` | New | Your fellowship has moved to the next guide! | आपकी संगति अगली गाइड पर पहुँच गई! | നിങ്ങളുടെ കൂട്ടായ്മ അടുത്ത ഗൈഡിലേക്ക് നീങ്ങി! |
| `fellowship_path_complete` | New | Your fellowship has completed the entire study path! | आपकी संगति ने सीखने का रास्ता पूरा कर लिया! | നിങ്ങളുടെ കൂട്ടായ്മ മുഴുവൻ പഠന പാതയും പൂർത്തിയാക്കി! |
| `network_error` | New | Network error. Please check your connection. | नेटवर्क त्रुटि। कृपया अपना कनेक्शन जाँचें। | നെറ്റ്‌വർക്ക് പിശക്. നിങ്ങളുടെ കണക്ഷൻ പരിശോധിക്കുക. |
| `notes_saved` | New | Notes saved | नोट्स सहेजे गए | കുറിപ്പുകൾ സേവ് ചെയ്തു |
| `ok` | New | OK | ठीक है | ശരി |
| `reflection_failed` | New | Couldn't save your reflection. Please try again. | आपका चिंतन सहेजा नहीं जा सका। कृपया फिर से प्रयास करें। | നിങ്ങളുടെ ധ്യാനം സേവ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `reflection_not_loaded` | New | Couldn't save your reflection: the study guide hasn't loaded. | आपका चिंतन सहेजा नहीं जा सका: अध्ययन गाइड लोड नहीं हुई है। | നിങ്ങളുടെ ധ്യാനം സേവ് ചെയ്യാനായില്ല: പഠന ഗൈഡ് ലോഡ് ആയിട്ടില്ല. |
| `reflection_saved` | New | Reflection saved! Time spent: {minutes} min | चिंतन सहेजा गया! लगा समय: {minutes} मिनट | ധ്യാനം സേവ് ചെയ്തു! ചെലവഴിച്ച സമയം: {minutes} മിനിറ്റ് |
| `saved_notes_failed` | New | Study guide saved, but your notes could not be saved. | अध्ययन गाइड सहेजी गई, लेकिन आपके नोट्स सहेजे नहीं जा सके। | പഠന ഗൈഡ് സേവ് ചെയ്തു, പക്ഷേ നിങ്ങളുടെ കുറിപ്പുകൾ സേവ് ചെയ്യാനായില്ല. |
| `shared_to_fellowship` | New | Shared to your fellowship feed! | आपकी संगति फ़ीड में साझा किया गया! | നിങ്ങളുടെ കൂട്ടായ്മ ഫീഡിൽ പങ്കിട്ടു! |
| `tts_next_section` | New | Next section | अगला भाग | അടുത്ത ഭാഗം |
| `tts_play` | New | Play | चलाएँ | പ്ലേ ചെയ്യുക |
| `tts_prev_section` | New | Previous section | पिछला भाग | മുമ്പത്തെ ഭാഗം |
| `tts_progress` | New | Section playback progress | भाग की प्लेबैक प्रगति | ഭാഗത്തിന്റെ പ്ലേബാക്ക് പുരോഗതി |
| `tts_replay` | New | Replay | फिर से चलाएँ | വീണ്ടും പ്ലേ ചെയ്യുക |
| `verse_eyebrow` | New | Scripture | वचन | തിരുവചനം |

## home_today (19)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `choose_first_path` | New | Choose your first path | अपना पहला रास्ता चुनें | ആദ്യ പാത തിരഞ്ഞെടുക്കൂ |
| `choose_first_path_sub` | New | One short lesson a day. Switch any time. | रोज़ एक छोटा पाठ। कभी भी बदलें। | ദിവസം ഒരു ചെറിയ പാഠം. |
| `choose_next_path` | New | Choose your next path | अगला रास्ता चुनें | അടുത്ത പാത |
| `lesson_eyebrow` | New | TODAY · LESSON {n} | आज · पाठ {n} | ഇന്ന് · പാഠം {n} |
| `lesson_of` | New | Lesson {n} of {m} | पाठ {n} / {m} | പാഠം {n} / {m} |
| `lessons_days` | New | {lessons} lessons · {days} days | {lessons} पाठ · {days} दिन | {lessons} പാഠം · {days} ദിവസം |
| `loading_path` | New | Loading your path | रास्ता खुल रहा है | പാത തുറക്കുന്നു |
| `mode_quick` | New | Quick read · {min} min | छोटी · {min} मि | വേഗ വായന · {min} മി |
| `mode_standard` | New | Full guide · {min} min | पूरी गाइड · {min} मि | പൂർണ ഗൈഡ് · {min} മി |
| `path_finished` | New | You finished {path} | आपने {path} पूरा किया | {path} പൂർത്തിയാക്കി |
| `paths_unavailable` | New | Couldn't load paths | रास्ते नहीं खुले | പാതകൾ തുറന്നില്ല |
| `reflect` | New | Reflect on this verse | इस वचन पर मनन करें | ഈ വചനം ധ്യാനിക്കാം |
| `save_progress` | New | Save progress to your account | प्रगति खाते में सहेजें | പുരോഗതി സൂക്ഷിക്കൂ |
| `see_all_paths` | New | See all paths | सभी रास्ते देखें | എല്ലാ പാതകളും |
| `see_path` | New | See path | रास्ता देखें | പാത |
| `start_lesson` | New | Start lesson {n} | पाठ {n} शुरू करें | പാഠം {n} തുടങ്ങാം |
| `strip_semantics` | New | {done} of {total} lessons done | {total} में से {done} पाठ पूरे | {total}-ൽ {done} പാഠം കഴിഞ്ഞു |
| `to_go` | New | {k} to go | {k} बाकी | {k} ബാക്കി |
| `today_label` | New | Today | आज | ഇന്ന് |

## nfy (19)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `discipler.banner_cta` | New | Ask Discipler | Discipler से पूछें | ചോദിക്കൂ |
| `discipler.banner_sub` | New | Answers that point back to Scripture. | जवाब जो वचन की ओर ले जाते हैं। | തിരുവചനത്തിലേക്ക് നയിക്കുന്ന മറുപടികൾ. |
| `discipler.banner_title` | New | Ask a question about the Bible | बाइबल पर सवाल पूछें | ബൈബിളിനെപ്പറ്റി ചോദിക്കാം |
| `dismiss` | New | Dismiss | हटाएँ | ഒഴിവാക്കുക |
| `eyebrow` | New | New for you | आपके लिए नया | പുതിയത് |
| `fellowships.banner_cta` | New | Join Disciplefy | जुड़ें | ചേരൂ |
| `fellowships.banner_sub` | New | Study {path} with others. | दूसरों के साथ {path} पढ़ें। | {path} മറ്റുള്ളവരോടൊപ്പം പഠിക്കാം. |
| `fellowships.banner_sub_any` | New | Study the same lesson with others. | दूसरों के साथ एक ही पाठ पढ़ें। | ഒരേ പാഠം മറ്റുള്ളവരോടൊപ്പം പഠിക്കാം. |
| `fellowships.banner_title` | New | Join the Disciplefy fellowship | Disciplefy संगति से जुड़ें | Disciplefy കൂട്ടായ്മയിൽ ചേരാം |
| `generate.banner_cta` | New | Start a study | अध्ययन शुरू करें | പഠനം തുടങ്ങൂ |
| `generate.banner_sub` | New | A guide for whatever is on your mind. | मन की हर बात के लिए गाइड। | മനസ്സിലുള്ളതിനെല്ലാം ഒരു ഗൈഡ്. |
| `generate.banner_title` | New | Study any verse or question | कोई भी वचन या सवाल पढ़ें | ഏത് വചനവും ചോദ്യവും പഠിക്കാം |
| `memory.banner_cta` | New | Practise · 1 min | अभ्यास · 1 मि | പരിശീലനം · 1 മി |
| `memory.banner_sub` | New | Practise {ref} in one minute. | {ref} एक मिनट में दोहराएँ। | {ref} ഒരു മിനിറ്റിൽ പരിശീലിക്കാം. |
| `memory.banner_sub_any` | New | Practise today's verse in one minute. | आज का वचन एक मिनट में दोहराएँ। | ഇന്നത്തെ വചനം ഒരു മിനിറ്റിൽ പരിശീലിക്കാം. |
| `memory.banner_title` | New | Keep today's verse with you | आज का वचन याद रखें | ഇന്നത്തെ വചനം കൂടെ കരുതാം |
| `paths.banner_cta` | New | Browse paths | रास्ते देखें | പാതകൾ |
| `paths.banner_sub` | New | From the Gospels to prayer and hard times. | सुसमाचार से प्रार्थना और कठिन समय तक। | സുവിശേഷം മുതൽ പ്രാർത്ഥനയും പ്രയാസങ്ങളും വരെ. |
| `paths.banner_title` | New | Explore more learning paths | और रास्ते देखें | കൂടുതൽ പാതകൾ കാണാം |

## app_chrome (18)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `lock.connect_to_upgrade` | New | Connect to the internet to upgrade | अपग्रेड करने के लिए इंटरनेट से जुड़ें | അപ്‌ഗ്രേഡ് ചെയ്യാൻ ഇന്റർനെറ്റുമായി ബന്ധിപ്പിക്കൂ |
| `lock.not_available_offline` | New | Not available offline | ऑफ़लाइन उपलब्ध नहीं | ഓഫ്‌ലൈനിൽ ലഭ്യമല്ല |
| `lock.tap_to_upgrade` | New | Tap to upgrade | अपग्रेड के लिए टैप करें | അപ്‌ഗ്രേഡ് ചെയ്യാൻ ടാപ്പ് ചെയ്യൂ |
| `notify_prompt.eyebrow` | New | Notifications | सूचनाएं | അറിയിപ്പുകൾ |
| `offline.back_online` | New | Back online · Syncing | फिर से ऑनलाइन · सिंक हो रहा है | വീണ്ടും ഓൺലൈൻ · സിങ്ക് ചെയ്യുന്നു |
| `offline.offline` | New | You're offline · Showing saved content | आप ऑफ़लाइन हैं · सहेजी गई सामग्री दिख रही है | നിങ്ങൾ ഓഫ്‌ലൈനാണ് · സേവ് ചെയ്ത ഉള്ളടക്കം കാണിക്കുന്നു |
| `update.available_body` | New | A new version of the app is available with improvements and bug fixes. | ऐप का नया संस्करण सुधारों के साथ उपलब्ध है। | മെച്ചപ്പെടുത്തലുകളും പിശക് പരിഹാരങ്ങളുമായി ആപ്പിന്റെ പുതിയ പതിപ്പ് ലഭ്യമാണ്. |
| `update.available_title` | New | Update available | अपडेट उपलब्ध है | അപ്ഡേറ്റ് ലഭ്യമാണ് |
| `update.current_version` | New | Current version | मौजूदा संस्करण | നിലവിലെ പതിപ്പ് |
| `update.eyebrow` | New | App update | ऐप अपडेट | ആപ്പ് അപ്ഡേറ്റ് |
| `update.later` | New | Later | बाद में | പിന്നീട് |
| `update.latest_version` | New | Latest version | नवीनतम संस्करण | ഏറ്റവും പുതിയ പതിപ്പ് |
| `update.required_body` | New | A critical update is required to continue using the app. | ऐप का उपयोग जारी रखने के लिए एक ज़रूरी अपडेट चाहिए। | ആപ്പ് തുടർന്ന് ഉപയോഗിക്കാൻ ഒരു പ്രധാന അപ്ഡേറ്റ് ആവശ്യമാണ്. |
| `update.required_hint` | New | Please update from your app store to continue. | जारी रखने के लिए कृपया अपने ऐप स्टोर से अपडेट करें। | തുടരാൻ ദയവായി ആപ്പ് സ്റ്റോറിൽ നിന്ന് അപ്ഡേറ്റ് ചെയ്യൂ. |
| `update.required_title` | New | Update required | अपडेट ज़रूरी है | അപ്ഡേറ്റ് ആവശ്യമാണ് |
| `update.required_version` | New | Required version | ज़रूरी संस्करण | ആവശ്യമായ പതിപ്പ് |
| `update.update` | New | Update | अपडेट करें | അപ്ഡേറ്റ് |
| `update.update_now` | New | Update now | अभी अपडेट करें | ഇപ്പോൾ അപ്ഡേറ്റ് ചെയ്യൂ |

## community_post (18)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `copy_text` | New | Copy text | टेक्स्ट कॉपी करें | ടെക്സ്റ്റ് കോപ്പി ചെയ്യുക |
| `input_question` | New | Question | प्रश्न | ചോദ്യം |
| `input_scripture` | New | Scripture | वचन | വേദഭാഗം |
| `input_topic` | New | Topic | विषय | വിഷയം |
| `mode_study_guide` | New | {mode} study guide | {mode} अध्ययन गाइड | {mode} പഠന ഗൈഡ് |
| `on_topic` | New | On: {title} | विषय: {title} | വിഷയം: {title} |
| `open_guide` | New | Open study guide | अध्ययन गाइड खोलें | പഠന ഗൈഡ് തുറക്കുക |
| `reaction_amen` | New | Amen | आमीन | ആമേൻ |
| `reaction_fire` | New | Fire | जोश | ആവേശം |
| `reaction_helpful` | New | Helpful | उपयोगी | സഹായകരം |
| `reaction_love` | New | Love | प्रेम | സ്നേഹം |
| `reaction_praise` | New | Praise | स्तुति | സ്തുതി |
| `reaction_prayed` | New | I prayed | मैंने प्रार्थना की | ഞാൻ പ്രാർത്ഥിച്ചു |
| `time_days_ago` | New | {count} days ago | {count} दिन पहले | {count} ദിവസം മുമ്പ് |
| `time_hours_ago` | New | {count}h ago | {count} घंटे पहले | {count} മണിക്കൂർ മുമ്പ് |
| `time_just_now` | New | Just now | अभी | ഇപ്പോൾ |
| `time_minutes_ago` | New | {count}m ago | {count} मिनट पहले | {count} മിനിറ്റ് മുമ്പ് |
| `time_yesterday` | New | Yesterday | कल | ഇന്നലെ |

## community_shared (18)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `create_locked` | New | Create a fellowship (upgrade) | संगति बनाएँ (अपग्रेड) | കൂട്ടായ്മ സൃഷ്ടിക്കുക (അപ്‌ഗ്രേഡ്) |
| `daily_study` | New | Daily study | दैनिक अध्ययन | ദൈനംദിന പഠനം |
| `discover_tab` | New | Discover | खोजें | കണ്ടെത്തുക |
| `join_fellowship` | New | Join a fellowship | संगति से जुड़ें | കൂട്ടായ്മയിൽ ചേരുക |
| `join_with_code` | New | Join with invite code | आमंत्रण कोड से जुड़ें | ക്ഷണ കോഡ് ഉപയോഗിച്ച് ചേരുക |
| `lesson` | New | Lesson {number} | पाठ {number} | പാഠം {number} |
| `lesson_of` | New | Lesson {number} of {total} | पाठ {number} / {total} | പാഠം {number} / {total} |
| `load_error_body` | New | Unable to load. Please try again. | लोड नहीं हो सका। कृपया फिर से प्रयास करें। | ലോഡ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `mentor` | New | Mentor: {name} | मेंटर: {name} | മെന്റർ: {name} |
| `mentor_you` | New | {name} (you) | {name} (आप) | {name} (നിങ്ങൾ) |
| `more_options` | New | More options | और विकल्प | കൂടുതൽ ഓപ്ഷനുകൾ |
| `offline_body` | New | Community features require an internet connection. | समुदाय सुविधाओं के लिए इंटरनेट कनेक्शन चाहिए। | കമ്മ്യൂണിറ്റി സവിശേഷതകൾക്ക് ഇന്റർനെറ്റ് കണക്ഷൻ ആവശ്യമാണ്. |
| `offline_title` | New | You're offline | आप ऑफ़लाइन हैं | നിങ്ങൾ ഓഫ്‌ലൈനാണ് |
| `progress` | New | {current} of {total} | {total} में से {current} | {total}-ൽ {current} |
| `replies` | New | {count} replies | {count} उत्तर | {count} മറുപടികൾ |
| `reply_one` | New | 1 reply | 1 उत्तर | 1 മറുപടി |
| `search_hint` | New | Search fellowships… | संगतियाँ खोजें… | കൂട്ടായ്മകൾ തിരയുക… |
| `start_study` | New | Start study | अध्ययन शुरू करें | പഠനം തുടങ്ങുക |

## memory_recall_modes (18)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `first_letter.check` | New | Check | जाँचें | പരിശോധിക്കുക |
| `first_letter.hint` | New | Hint | संकेत | സൂചന |
| `first_letter.hints_used` | New | Hints used {used}/{total} | संकेत {used}/{total} | സൂചനകൾ {used}/{total} |
| `first_letter.tile_label` | New | Word {index}, starts with {letter}. Tap to reveal | शब्द {index}, {letter} से शुरू। देखने के लिए टैप करें | വാക്ക് {index}, {letter} എന്നതിൽ തുടങ്ങുന്നു. കാണാൻ ടാപ്പ് ചെയ്യുക |
| `flip_card.back` | New | Back | पीछे | പിൻവശം |
| `flip_card.flip` | New | Flip card | कार्ड पलटें | കാർഡ് മറിക്കുക |
| `flip_card.front` | New | Front | सामने | മുൻവശം |
| `flip_card.recite_hint` | New | Recite it, then tap to flip | इसे बोलें, फिर पलटने के लिए टैप करें | ഇത് ചൊല്ലിയ ശേഷം മറിക്കാൻ ടാപ്പ് ചെയ്യുക |
| `progressive.all` | New | All | सभी | എല്ലാം |
| `progressive.auto` | New | Auto | अपने आप | സ്വയം |
| `progressive.pause` | New | Pause | रोकें | നിർത്തുക |
| `progressive.phrases_progress` | New | {current} of {total} phrases | {total} में से {current} वाक्यांश | {total}-ൽ {current} വാക്യഭാഗങ്ങൾ |
| `progressive.words_progress` | New | {current} of {total} words | {total} में से {current} शब्द | {total}-ൽ {current} വാക്കുകൾ |
| `type_it_out.answer` | New | Answer | उत्तर | ഉത്തരം |
| `type_it_out.hinglish` | New | Hindi (Hinglish) | हिंदी (हिंग्लिश) | ഹിന്ദി (ഹിംഗ്ലിഷ്) |
| `type_it_out.manglish` | New | Malayalam (Manglish) | मलयालम (मंग्लिश) | മലയാളം (മംഗ്ലീഷ്) |
| `type_it_out.romanized_hint` | New | Type in romanized {lang} | रोमन अक्षरों में टाइप करें: {lang} | ഇംഗ്ലീഷ് അക്ഷരങ്ങളിൽ ടൈപ്പ് ചെയ്യുക: {lang} |
| `type_it_out.word_count` | New | {current} / {total} words | {current} / {total} शब्द | {current} / {total} വാക്കുകൾ |

## popups (18)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `achievement_cta` | New | Awesome | शानदार | അതിശയകരം |
| `achievement_eyebrow` | New | Achievement unlocked | उपलब्धि अनलॉक हुई | നേട്ടം അൺലോക്ക് ചെയ്തു |
| `add_notes` | New | Add notes | नोट्स जोड़ें | കുറിപ്പുകൾ ചേർക്കുക |
| `ask_discipler` | New | Ask Discipler | Discipler से पूछें | Discipler-നോട് ചോദിക്കുക |
| `available_on` | New | Available on | इन प्लान में उपलब्ध | ലഭ്യമായ പ്ലാനുകൾ |
| `continue_path` | New | Continue learning path | रास्ता जारी रखें | പഠന പാത തുടരുക |
| `credits_eyebrow` | New | Out of credits | क्रेडिट खत्म | ക്രെഡിറ്റുകൾ തീർന്നു |
| `done` | New | Done | हो गया | പൂർത്തിയായി |
| `guide_complete_eyebrow` | New | Guide complete | गाइड पूरी हुई | ഗൈഡ് പൂർത്തിയായി |
| `guide_complete_next` | New | What would you like to do next? | आगे आप क्या करना चाहेंगे? | അടുത്തതായി എന്തു ചെയ്യാൻ ആഗ്രഹിക്കുന്നു? |
| `guide_complete_next_path` | New | Ready to continue your learning path? | क्या आप अपना सीखने का रास्ता जारी रखने के लिए तैयार हैं? | നിങ്ങളുടെ പഠന പാത തുടരാൻ തയ്യാറാണോ? |
| `maybe_later` | New | Maybe later | बाद में | പിന്നീട് |
| `not_now` | New | Not now | अभी नहीं | ഇപ്പോൾ വേണ്ട |
| `share_fellowship` | New | Share to fellowship | संगति में साझा करें | കൂട്ടായ്മയിൽ പങ്കിടുക |
| `sign_in_eyebrow` | New | Your account | आपका खाता | നിങ്ങളുടെ അക്കൗണ്ട് |
| `upgrade_eyebrow` | New | Locked on your plan | आपके प्लान में लॉक है | നിങ്ങളുടെ പ്ലാനിൽ ലോക്ക് ചെയ്തിരിക്കുന്നു |
| `upgrade_now` | New | Upgrade now | अभी अपग्रेड करें | ഇപ്പോൾ അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `your_plan` | New | Your plan: {plan} | आपका प्लान: {plan} | നിങ്ങളുടെ പ്ലാൻ: {plan} |

## topics_hub (18)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_levels` | New | All | सभी | എല്ലാം |
| `based_on_goals` | New | Based on your goals | आपके लक्ष्यों के आधार पर | നിങ്ങളുടെ ലക്ഷ്യങ്ങൾ അനുസരിച്ച് |
| `continue_eyebrow` | New | Continue · Lesson {current} of {total} | जारी रखें · पाठ {current} / {total} | തുടരുക · പാഠം {current} / {total} |
| `for_you` | New | For you | आपके लिए | നിങ്ങൾക്കായി |
| `leaderboard_label` | New | Leaderboard | लीडरबोर्ड | ലീഡർബോർഡ് |
| `level_range` | New | {from} to {to} | {from} से {to} | {from} മുതൽ {to} വരെ |
| `next_topic` | New | Next: {title} | अगला: {title} | അടുത്തത്: {title} |
| `no_filter_results` | New | No paths match the selected filters | चुने गए फ़िल्टर से कोई रास्ता मेल नहीं खाता | തിരഞ്ഞെടുത്ത ഫിൽട്ടറുകൾക്ക് പൊരുത്തമുള്ള പാതകളില്ല |
| `no_search_results` | New | No paths found for "{query}" | "{query}" के लिए कोई रास्ता नहीं मिला | "{query}" എന്നതിന് പാതകളൊന്നും കണ്ടെത്തിയില്ല |
| `offline_message` | New | You're offline. Learning Paths require an internet connection. | आप ऑफ़लाइन हैं। सीखने के रास्तों के लिए इंटरनेट कनेक्शन ज़रूरी है। | നിങ്ങൾ ഓഫ്‌ലൈനാണ്. പഠന പാതകൾക്ക് ഇന്റർനെറ്റ് കണക്ഷൻ ആവശ്യമാണ്. |
| `paths_count` | New | {count} paths | {count} रास्ते | {count} പാതകൾ |
| `paths_count_one` | New | {count} path | {count} रास्ता | {count} പാത |
| `retry` | New | Retry | फिर कोशिश करें | വീണ്ടും ശ്രമിക്കുക |
| `search_paths` | New | Search {count} paths | {count} रास्ते खोजें | {count} പാതകളിൽ തിരയുക |
| `see_all` | New | See all | सभी देखें | എല്ലാം കാണൂ |
| `streak_label` | New | Study streak | अध्ययन स्ट्रीक | പഠന തുടർച്ച |
| `streak_value` | New | {count} days | {count} दिन | {count} ദിവസം |
| `streak_value_one` | New | {count} day | {count} दिन | {count} ദിവസം |

## community (17)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `guided_by_discipler` | New | Guided by Discipler | Discipler द्वारा | Discipler നയിക്കുന്നു |
| `join_action` | New | Join fellowship | संगति से जुड़ें | കൂട്ടായ്മയിൽ ചേരുക |
| `join_failed` | New | Couldn't join this group. Please try again. | ग्रुप में जुड़ नहीं सके। कृपया दोबारा कोशिश करें। | ഗ്രൂപ്പിൽ ചേരാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `join_prompt_body` | New | Join {name} to read this post and follow along. | यह पोस्ट पढ़ने और साथ चलने के लिए {name} में जुड़ें। | ഈ പോസ്റ്റ് വായിക്കാനും ഒപ്പം നടക്കാനും {name} ൽ ചേരുക. |
| `join_prompt_confirm` | New | Join | जुड़ें | ചേരുക |
| `join_prompt_title` | New | Join this group? | इस ग्रुप में जुड़ें? | ഈ ഗ്രൂപ്പിൽ ചേരണോ? |
| `join_to_view_body` | New | You are not a member yet. Public fellowships let you join and read along. | आप अभी सदस्य नहीं हैं। सार्वजनिक संगति में आप जुड़कर पढ़ सकते हैं। | നിങ്ങൾ ഇതുവരെ അംഗമല്ല. പൊതു കൂട്ടായ്മകളിൽ ചേർന്ന് വായിക്കാം. |
| `join_to_view_title` | New | Join to see this fellowship | इस संगति को देखने के लिए जुड़ें | ഈ കൂട്ടായ്മ കാണാൻ ചേരുക |
| `joined` | New | You joined {name} | आप {name} से जुड़े | {name}-ൽ ചേർന്നു |
| `let_discipler_answer` | New | Let Discipler answer | Discipler को उत्तर देने दें | Discipler ഉത്തരം നൽകട്ടെ |
| `let_discipler_answer_hint` | New | Turn off to leave this question to the group. Tagging @Discipler still gets a reply. | इसे बंद करें ताकि यह सवाल समूह के लिए रहे। @Discipler टैग करने पर उत्तर फिर भी मिलेगा। | ഈ ചോദ്യം ഗ്രൂപ്പിനു വിടാൻ ഇത് ഓഫ് ചെയ്യുക. @Discipler എന്ന് ടാഗ് ചെയ്താൽ മറുപടി ലഭിക്കും. |
| `link_not_a_member` | New | You're not part of this group. | आप इस ग्रुप का हिस्सा नहीं हैं। | നിങ്ങൾ ഈ ഗ്രൂപ്പിന്റെ ഭാഗമല്ല. |
| `link_unavailable` | New | This group isn't available. | यह ग्रुप उपलब्ध नहीं है। | ഈ ഗ്രൂപ്പ് ലഭ്യമല്ല. |
| `study_guide_label` | New | Study guide | अध्ययन गाइड | പഠന ഗൈഡ് |
| `this_group` | New | this group | इस ग्रुप | ഈ ഗ്രൂപ്പ് |
| `topic_study_label` | New | Topic study | विषय अध्ययन | വിഷയ പഠനം |
| `verse_study_label` | New | Verse study | वचन अध्ययन | വാക്യ പഠനം |

## gamification (16)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `achievements_count` | New | Achievements · {unlocked} of {total} | उपलब्धियाँ · {total} में से {unlocked} | നേട്ടങ്ങൾ · {total}-ൽ {unlocked} |
| `category_memory` | Changed | Memory | याद वचन | മനഃപാഠം |
| `category_saved` | Changed | Saved | सहेजे गए | സേവ് |
| `category_streak` | Changed | Streaks | स्ट्रीक | തുടർച്ചകൾ |
| `day_streak_label` | New | day streak | दिन लगातार | ദിവസ തുടർച്ച |
| `memory_verses` | Changed | Memory Verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |
| `progress_count` | New | {current} of {total} | {total} में से {current} | {total}-ൽ {current} |
| `saved_guides` | Changed | Saved Guides | सहेजी गई गाइड | സേവ് ചെയ്ത ഗൈഡുകൾ |
| `streaks` | Changed | Streaks | स्ट्रीक | തുടർച്ചകൾ |
| `studies_label` | New | studies | अध्ययन | പഠനങ്ങൾ |
| `study_streak` | Changed | Study Streak | अध्ययन स्ट्रीक | പഠന തുടർച്ച |
| `subtitle` | Changed | View streaks, levels, and achievements | स्ट्रीक, स्तर और उपलब्धियाँ देखें | തുടർച്ചകൾ, ലെവലുകൾ, നേട്ടങ്ങൾ കാണുക |
| `title` | Changed | My progress | मेरी प्रगति | എന്റെ പുരോഗതി |
| `verse_streak` | Changed | Verse Streak | वचन स्ट्रीक | വചന തുടർച്ച |
| `verses_label` | New | verses | पद | വാക്യങ്ങൾ |
| `xp_to_level` | New | {xp} XP to {level} | {level} तक {xp} XP | {level} വരെ {xp} XP |

## my_plan (16)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `free_trial_until` | New | Free trial until {date} | {date} तक मुफ़्त ट्रायल | {date} വരെ സൗജന്യ ട്രയൽ |
| `get_7_days_trial` | Changed | Get 7 days of unlimited Premium features | 7 दिन असीमित प्रीमियम सुविधाएं पाएं | 7 ദിവസത്തെ പരിധിയില്ലാത്ത പ്രീമിയം സവിശേഷതകൾ നേടുക |
| `get_tokens_daily` | Changed | Get 40 credits a day, Deep Dive studies and more | रोज़ 40 क्रेडिट, गहरी पढ़ाई और बहुत कुछ | ദിവസം 40 ക്രെഡിറ്റ്, ആഴത്തിലുള്ള പഠനങ്ങളും മറ്റും |
| `get_tokens_daily_for` | Changed | Get 40 credits a day for {price} | {price} में रोज़ 40 क्रेडिट | {price}-ന് ദിവസം 40 ക്രെഡിറ്റ് |
| `grace_period` | Changed | Grace Period | छूट अवधि | ഇളവ് കാലയളവ് |
| `grace_period_active` | Changed | Grace Period Active | छूट अवधि सक्रिय | ഇളവ് കാലയളവ് സജീവം |
| `grace_period_ends_soon` | Changed | Grace period ends soon! | छूट अवधि जल्द खत्म! | ഇളവ് കാലയളവ് ഉടൻ അവസാനിക്കും! |
| `no_features` | New | No features available | कोई सुविधा उपलब्ध नहीं | സവിശേഷതകൾ ലഭ്യമല്ല |
| `trial_active` | Changed | Trial active | ट्रायल सक्रिय | ട്രയൽ സജീവം |
| `trial_no_payment` | New | No payment method yet. Choose a plan before your trial ends. | अभी कोई भुगतान नहीं। ट्रायल खत्म होने से पहले प्लान चुनें। | ഇപ്പോൾ പണമടയ്ക്കേണ്ട. ട്രയൽ തീരും മുമ്പ് പ്ലാൻ തിരഞ്ഞെടുക്കുക. |
| `trial_pill` | New | Trial | ट्रायल | ട്രയൽ |
| `unlimited_tokens_for` | Changed | Unlimited credits for {price} | {price} में असीमित क्रेडिट | {price} പരിധിയില്ലാത്ത ക്രെഡിറ്റുകൾ |
| `upgrade_to_premium` | Changed | Upgrade to Premium | प्रीमियम में अपग्रेड करें | പ്രീമിയത്തിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `upgrade_to_standard` | Changed | Upgrade to Standard | स्टैंडर्ड में अपग्रेड करें | സ്റ്റാൻഡേർഡിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `view_payment_history` | Changed | View payment history | भुगतान इतिहास देखें | പേയ്‌മെന്റ് ചരിത്രം കാണുക |
| `view_plans` | New | View plans | प्लान देखें | പ്ലാനുകൾ കാണുക |

## app_status (14)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `error_eyebrow` | New | Error | त्रुटि | പിശക് |
| `error_no_email_app` | New | No email app found. Please write to {email} | कोई ईमेल ऐप नहीं मिला। कृपया {email} पर लिखें | ഇമെയിൽ ആപ്പ് കണ്ടെത്തിയില്ല. {email} എന്ന വിലാസത്തിൽ എഴുതുക |
| `error_report` | New | Report this issue | इस समस्या की रिपोर्ट करें | ഈ പ്രശ്നം റിപ്പോർട്ട് ചെയ്യുക |
| `error_try_later` | New | Please try again later. | कृपया बाद में फिर से कोशिश करें। | പിന്നീട് വീണ്ടും ശ്രമിക്കുക. |
| `locked_paths_body` | New | Unlock structured learning journeys designed to deepen your faith and biblical understanding. | विश्वास और बाइबल की समझ को गहरा करने के लिए बनाई गई व्यवस्थित सीखने की यात्राएँ अनलॉक करें। | വിശ്വാസവും ബൈബിൾ ധാരണയും ആഴപ്പെടുത്താൻ രൂപകൽപ്പന ചെയ്ത ക്രമീകൃത പഠനയാത്രകൾ അൺലോക്ക് ചെയ്യുക. |
| `maintenance_back_soon` | New | We'll be back online shortly. Thank you for your patience! | हम जल्द ही वापस ऑनलाइन होंगे। आपके धैर्य के लिए धन्यवाद! | ഞങ്ങൾ ഉടൻ തിരികെ ഓൺലൈനിൽ എത്തും. നിങ്ങളുടെ ക്ഷമയ്ക്ക് നന്ദി! |
| `maintenance_check` | New | Check Status | स्थिति जाँचें | നില പരിശോധിക്കുക |
| `maintenance_check_failed` | New | Couldn't check the status. Please try again. | स्थिति जाँची नहीं जा सकी। कृपया फिर से कोशिश करें। | നില പരിശോധിക്കാനായില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `maintenance_checking` | New | Checking... | जाँच हो रही है... | പരിശോധിക്കുന്നു... |
| `maintenance_eyebrow` | New | Scheduled maintenance | निर्धारित रखरखाव | നിശ്ചിത അറ്റകുറ്റപ്പണി |
| `maintenance_title` | New | Maintenance Mode | रखरखाव मोड | അറ്റകുറ്റപ്പണി മോഡ് |
| `purchase_validation_failed` | New | Purchase validation failed: {error} Please contact support if you were charged. | खरीद की पुष्टि नहीं हो सकी: {error} यदि आपसे शुल्क लिया गया है तो कृपया सहायता से संपर्क करें। | വാങ്ങൽ സ്ഥിരീകരിക്കാനായില്ല: {error} നിങ്ങളിൽ നിന്ന് തുക ഈടാക്കിയിട്ടുണ്ടെങ്കിൽ സപ്പോർട്ടിനെ ബന്ധപ്പെടുക. |
| `settings_open_failed` | New | Could not open settings. | सेटिंग्स नहीं खुल सकीं। | ക്രമീകരണങ്ങൾ തുറക്കാനായില്ല. |
| `subscription_activated` | New | Subscription activated successfully! | सदस्यता सफलतापूर्वक सक्रिय हो गई! | സബ്സ്ക്രിപ്ഷൻ വിജയകരമായി സജീവമാക്കി! |

## premium (12)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `ai_discipler_desc` | Changed | Voice assistant for interactive Bible study | बाइबल अध्ययन के लिए आवाज़ सहायक | ബൈബിൾ പഠനത്തിനുള്ള ശബ്ദ സഹായി |
| `basic` | Changed | Basic | साधारण | അടിസ്ഥാനം |
| `check_status` | Changed | Check subscription status | सब्सक्रिप्शन स्थिति जांचें | സബ്‌സ്‌ക്രിപ്‌ഷൻ നില പരിശോധിക്കുക |
| `complete_history_desc` | Changed | Access all your past study guides forever | अपनी सभी पिछली अध्ययन गाइड हमेशा के लिए एक्सेस करें | നിങ്ങളുടെ എല്ലാ പഠന ഗൈഡുകളും സംഭാഷണങ്ങളും ആക്‌സസ് ചെയ്യുക |
| `disciplefy_premium` | Changed | Disciplefy Premium | Disciplefy प्रीमियम | Disciplefy പ്രീമിയം |
| `followup_questions` | Changed | Follow-up questions | आगे के सवाल | തുടർചോദ്യങ്ങൾ |
| `payment_completed_hint` | Changed | Completed payment? Tap the refresh button ↑ to check your subscription status | भुगतान पूरा किया? अपनी सब्सक्रिप्शन स्थिति जांचने के लिए ↑ रीफ्रेश बटन दबाएं | പേയ്‌മെന്റ് പൂർത്തിയായെങ്കിൽ, താഴെയുള്ള ബട്ടൺ ടാപ്പ് ചെയ്യുക |
| `unlimited_followups` | Changed | Unlimited Follow-ups | असीमित सवाल | പരിധിയില്ലാത്ത തുടർചോദ്യങ്ങൾ |
| `unlimited_followups_desc` | Changed | Ask unlimited follow-up questions | जितने चाहें उतने सवाल पूछें | Discipler-നോട് നിങ്ങൾക്ക് ഇഷ്ടമുള്ളത്ര ചോദ്യങ്ങൾ ചോദിക്കുക |
| `unlimited_tokens_desc` | Changed | Generate study guides without daily limits | बिना दैनिक सीमा के अध्ययन गाइड बनाएं | ദൈനംദിന പരിധികളില്ലാതെ പഠന ഗൈഡുകൾ സൃഷ്ടിക്കുക |
| `upgrade_button` | Changed | Upgrade to Premium | प्रीमियम में अपग्रेड करें | പ്രീമിയത്തിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `upgrade_title` | Changed | Upgrade to Premium | प्रीमियम में अपग्रेड करें | പ്രീമിയത്തിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |

## pricing (12)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `free.feature1` | Changed | 15 study credits daily | हर दिन 15 अध्ययन क्रेडिट | ദിവസവും 15 പഠന ക്രെഡിറ്റുകൾ |
| `free.feature2` | Changed | Daily verse notifications | दैनिक वचन सूचनाएं | ഇന്നത്തെ വചന അറിയിപ്പുകൾ |
| `free.feature3` | Changed | Learning paths & Study topics | सीखने के रास्ते और अध्ययन विषय | പഠന പാതകളും പഠന വിഷയങ്ങളും |
| `plus.feature1` | Changed | 60 study credits daily | हर दिन 60 अध्ययन क्रेडिट | ദിവസവും 60 പഠന ക്രെഡിറ്റുകൾ |
| `plus.feature5` | Changed | Study guide history | अध्ययन गाइड इतिहास | പഠന ഗൈഡ് ചരിത്രം |
| `premium.feature1` | Changed | Unlimited study credits | असीमित अध्ययन क्रेडिट | പരിധിയില്ലാത്ത പഠന ക്രെഡിറ്റുകൾ |
| `premium.feature2` | Changed | Talk to Discipler | Discipler से बात करें | Discipler-നോട് സംസാരിക്കുക |
| `premium.feature4` | Changed | Unlimited follow-up questions | असीमित आगे के सवाल | പരിധിയില്ലാത്ത തുടർചോദ്യങ്ങൾ |
| `standard.feature1` | Changed | 40 study credits daily | हर दिन 40 अध्ययन क्रेडिट | ദിവസവും 40 പഠന ക്രെഡിറ്റുകൾ |
| `standard.feature2` | Changed | Discipler (3 chats/month) | Discipler (3 चैट/माह) | Discipler (3 ചാറ്റ്/മാസം) |
| `standard.feature5` | Changed | Study guide history | अध्ययन गाइड इतिहास | പഠന ഗൈഡ് ചരിത്രം |
| `unlimited_tokens` | Changed | Unlimited credits | असीमित क्रेडिट | പരിധിയില്ലാത്ത ക്രെഡിറ്റുകൾ |

## saved_guides (12)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `close_search` | New | Close search | खोज बंद करें | തിരയൽ അടയ്ക്കുക |
| `continue` | New | Continue | जारी रखें | തുടരുക |
| `continue_section` | New | Continue · Section {current} of {total} | जारी रखें · खंड {current} / {total} | തുടരുക · ഭാഗം {current} / {total} |
| `empty_message` | Changed | Generate and save study guides to access them here | उन्हें यहां एक्सेस करने के लिए अध्ययन गाइड बनाएं और सहेजें | അവ ഇവിടെ എടുക്കാൻ പഠന ഗൈഡുകൾ സൃഷ്ടിച്ച് സേവ് ചെയ്യുക |
| `library_title` | New | Your library | आपकी लाइब्रेरी | നിങ്ങളുടെ ലൈബ്രറി |
| `loading` | New | Loading guides… | गाइड लोड हो रही हैं… | ഗൈഡുകൾ ലോഡ് ചെയ്യുന്നു… |
| `no_results` | New | No guides match "{query}" | "{query}" से मेल खाती कोई गाइड नहीं | "{query}" എന്നതുമായി പൊരുത്തപ്പെടുന്ന ഗൈഡുകളില്ല |
| `remove` | New | Remove from saved | सहेजे गए से हटाएं | സംരക്ഷിച്ചതിൽ നിന്ന് നീക്കുക |
| `save` | New | Save guide | गाइड सहेजें | ഗൈഡ് സേവ് ചെയ്യൂ |
| `search` | New | Search | खोजें | തിരയുക |
| `search_hint` | New | Search your guides | अपनी गाइड खोजें | നിങ്ങളുടെ ഗൈഡുകൾ തിരയുക |
| `yesterday` | New | Yesterday | कल | ഇന്നലെ |

## common (11)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `actions.cancel` | Changed | Cancel | रद्द करें | റദ്ദാക്കൂ |
| `actions.delete` | Changed | Delete | हटाएं | ഇല്ലാതാക്കൂ |
| `actions.edit` | Changed | Edit | बदलें | തിരുത്തൂ |
| `actions.open_settings` | New | Open Settings | सेटिंग्स खोलें | ക്രമീകരണങ്ങൾ തുറക്കുക |
| `actions.save` | Changed | Save | सहेजें | സേവ് ചെയ്യൂ |
| `actions.show_less` | New | Show less | कम दिखाएँ | കുറച്ച് കാണിക്കുക |
| `actions.show_more` | New | Show more | और देखें | കൂടുതൽ കാണിക്കുക |
| `exit.confirm` | New | Exit | बंद करें | അടയ്ക്കൂ |
| `exit.message` | New | Are you sure you want to exit Disciplefy? | क्या आप वाकई Disciplefy बंद करना चाहते हैं? | Disciplefy അടയ്ക്കാൻ ഉറപ്പാണോ? |
| `exit.title` | New | Exit App | ऐप बंद करें | ആപ്പ് അടയ്ക്കണോ |
| `messages.error_try_again` | New | Something went wrong. Please try again. | कुछ गड़बड़ हुई। कृपया दोबारा कोशिश करें। | എന്തോ കുഴപ്പം സംഭവിച്ചു. വീണ്ടും ശ്രമിക്കൂ. |

## generate_simple (11)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_depths` | New | All 5 | सभी 5 | എല്ലാം 5 |
| `choose_depth` | New | Choose depth | गहराई चुनें | ആഴം |
| `eyebrow` | New | GENERATE A STUDY | अध्ययन बनाएँ | പഠനം തയ്യാറാക്കാം |
| `generate` | New | Generate study | अध्ययन बनाएँ | പഠനം തയ്യാറാക്കുക |
| `hint` | New | e.g., John 3:16, Forgiveness, or a question | जैसे यूहन्ना 3:16, क्षमा, या कोई प्रश्न | ഉദാ: യോഹന്നാൻ 3:16, ക്ഷമ, ഒരു ചോദ്യം |
| `title` | New | What shall we study today? | आज क्या पढ़ें? | ഇന്ന് എന്ത് പഠിക്കാം? |
| `type_question` | New | Question | प्रश्न | ചോദ്യം |
| `type_scripture` | New | Scripture | वचन | വചനം |
| `type_topic` | New | Topic | विषय | വിഷയം |
| `using_credits` | New | Using {n} credits | {n} क्रेडिट लगेंगे | {n} ക്രെഡിറ്റ് ചെലവാകും |
| `verse_of_day` | New | VERSE OF THE DAY | आज का वचन | ഇന്നത്തെ വചനം |

## generate_study (11)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_modes` | New | All {count} | सभी {count} | എല്ലാം {count} |
| `button_generate_short` | New | Generate study | अध्ययन बनाएं | പഠനം ഉണ്ടാക്കൂ |
| `choose_depth` | New | Choose depth | गहराई चुनें | ആഴം തിരഞ്ഞെടുക്കൂ |
| `continue_reading` | New | Continue reading | पढ़ना जारी रखें | വായന തുടരൂ |
| `eyebrow` | New | Generate a study | अध्ययन बनाएं | പഠനം തയ്യാറാക്കൂ |
| `headline` | New | What shall we study today? | आज हम क्या पढ़ें? | ഇന്ന് നമ്മൾ എന്ത് പഠിക്കാം? |
| `scripture_mode` | Changed | Scripture Reference | वचन | തിരുവെഴുത്ത് റഫറൻസ് |
| `scripture_tab` | New | Scripture | वचन | തിരുവെഴുത്ത് |
| `see_all` | New | See all | सभी देखें | എല്ലാം കാണൂ |
| `sermon_outline_notice` | New | Sermon Outline is built in 4 passes, so it takes longer than other modes — usually 60–90 seconds. Please wait. | उपदेश रूपरेखा 4 चरणों में बनती है, इसलिए ज़्यादा समय लगता है — आमतौर पर 60–90 सेकंड। कृपया प्रतीक्षा करें। | പ്രഭാഷണ രൂപരേഖ 4 ഘട്ടങ്ങളായി തയ്യാറാക്കുന്നതിനാൽ കൂടുതൽ സമയമെടുക്കും — സാധാരണയായി 60–90 സെക്കൻഡ്. ദയവായി കാത്തിരിക്കുക. |
| `view_saved` | Changed | View Saved Guides | सहेजी गई गाइड देखें | സേവ് ചെയ്ത ഗൈഡുകൾ കാണൂ |

## practice (11)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `choose_modes` | New | Choose up to {limit} modes to practice today | आज अभ्यास के लिए {limit} मोड तक चुनें | ഇന്ന് പരിശീലിക്കാൻ {limit} മോഡുകൾ വരെ തിരഞ്ഞെടുക്കുക |
| `choose_one_mode` | New | Choose a mode to practice today | आज अभ्यास के लिए एक मोड चुनें | ഇന്ന് പരിശീലിക്കാൻ ഒരു മോഡ് തിരഞ്ഞെടുക്കുക |
| `complete` | Changed | Practice complete | अभ्यास पूर्ण | പരിശീലനം പൂർത്തിയായി |
| `modes_progress` | New | {count} / {limit} modes | {count} / {limit} मोड | {count} / {limit} മോഡുകൾ |
| `show_answer` | Changed | Show answer | उत्तर दिखाएं | ഉത്തരം കാണിക്കുക |
| `step_read` | New | Read | पढ़ें | വായിക്കുക |
| `step_results` | New | Results | नतीजे | ഫലങ്ങൾ |
| `step_speak` | New | Speak | बोलें | പറയുക |
| `unlock_more_modes` | New | You can unlock {count} more modes today | आप आज {count} और मोड अनलॉक कर सकते हैं | ഇന്ന് {count} മോഡുകൾ കൂടി അൺലോക്ക് ചെയ്യാം |
| `unlock_one_more` | New | You can unlock 1 more mode today | आप आज 1 और मोड अनलॉक कर सकते हैं | ഇന്ന് ഒരു മോഡ് കൂടി അൺലോക്ക് ചെയ്യാം |
| `unlocked_modes_today` | New | Unlocked Modes Today | आज अनलॉक हुए मोड | ഇന്ന് അൺലോക്ക് ചെയ്ത മോഡുകൾ |

## practice_unlock_limit (11)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_modes` | New | All modes unlocked | सभी मोड अनलॉक | എല്ലാ രീതികളും അൺലോക്ക് |
| `maybe_later` | New | Maybe Later | बाद में | പിന്നീട് |
| `message_one` | New | You've unlocked {count} practice mode for "{verse}" today. | आपने आज "{verse}" के लिए {count} अभ्यास मोड अनलॉक किया है। | "{verse}" എന്ന വചനത്തിന് ഇന്ന് {count} പരിശീലന രീതി അൺലോക്ക് ചെയ്തു. |
| `message_other` | New | You've unlocked {count} practice modes for "{verse}" today. | आपने आज "{verse}" के लिए {count} अभ्यास मोड अनलॉक किए हैं। | "{verse}" എന്ന വചനത്തിന് ഇന്ന് {count} പരിശീലന രീതികൾ അൺലോക്ക് ചെയ്തു. |
| `modes_per_day_one` | New | {count} mode per verse per day | हर वचन के लिए रोज़ {count} मोड | ഓരോ വചനത്തിനും ദിവസം {count} രീതി |
| `modes_per_day_other` | New | {count} modes per verse per day | हर वचन के लिए रोज़ {count} मोड | ഓരോ വചനത്തിനും ദിവസം {count} രീതികൾ |
| `still_practice` | New | You can still practice unlimited times with your unlocked modes today! | आज अनलॉक किए गए मोड से आप जितनी बार चाहें अभ्यास कर सकते हैं! | അൺലോക്ക് ചെയ്ത രീതികളിൽ ഇന്ന് എത്ര തവണ വേണമെങ്കിലും പരിശീലിക്കാം! |
| `title` | New | Daily Unlock Limit Reached | आज की अनलॉक सीमा पूरी | ഇന്നത്തെ അൺലോക്ക് പരിധി കഴിഞ്ഞു |
| `unlocked_today` | New | Modes Unlocked Today: | आज अनलॉक किए गए मोड: | ഇന്ന് അൺലോക്ക് ചെയ്ത രീതികൾ: |
| `upgrade_prompt` | New | Upgrade to unlock more modes per verse per day: | हर वचन के लिए रोज़ ज़्यादा मोड अनलॉक करने के लिए अपग्रेड करें: | ഓരോ വചനത്തിനും ദിവസവും കൂടുതൽ രീതികൾ അൺലോക്ക് ചെയ്യാൻ അപ്‌ഗ്രേഡ് ചെയ്യൂ: |
| `view_plans` | New | View Plans | प्लान देखें | പ്ലാനുകൾ കാണുക |

## study_topics (11)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `adjust_filters` | Changed | Try adjusting your filters or search terms | फ़िल्टर या खोज बदलकर देखें | നിങ്ങളുടെ ഫിൽട്ടറുകളോ തിരയൽ പദങ്ങളോ ക്രമീകരിക്കാൻ ശ്രമിക്കുക |
| `content_language` | Changed | Content language | सामग्री भाषा | ഉള്ളടക്ക ഭാഷ |
| `content_language_default` | Changed | Same as app language | ऐप जैसी भाषा | ആപ്പിന്റെ അതേ ഭാഷ |
| `content_language_default_description` | Changed | Currently | अभी | ഇപ്പോൾ |
| `content_language_description` | Changed | Study guides, learning paths and daily verses. Menus and buttons stay in the app language. | अध्ययन गाइड, रास्ते और दैनिक वचन। मेनू और बटन ऐप की भाषा में ही रहते हैं। | പഠന ഗൈഡുകൾ, പഠന പാതകൾ, ദിനവചനം. മെനുകളും ബട്ടണുകളും ആപ്പ് ഭാഷയിൽ തന്നെ തുടരും. |
| `reset_item_badges` | Changed | Study and streak badges will be removed | अध्ययन और स्ट्रीक बैज हटा दिए जाएंगे | പഠന, തുടർച്ച ബാഡ്ജുകൾ നീക്കും |
| `reset_item_paths` | Changed | All learning path enrollments will be removed | सभी रास्तों से नामांकन हट जाएगा | എല്ലാ പാതകളിൽ നിന്നുമുള്ള ചേരൽ നീക്കും |
| `reset_item_topics` | Changed | All completed lessons will be marked incomplete | सभी पूरे पाठ फिर से अधूरे हो जाएंगे | പൂർത്തിയാക്കിയ എല്ലാ പാഠങ്ങളും വീണ്ടും പൂർത്തിയാകാത്തതാകും |
| `reset_progress` | Changed | Reset Progress | प्रगति रीसेट करें | പുരോഗതി റീസെറ്റ് ചെയ്യുക |
| `reset_progress_title` | Changed | Reset learning progress? | रास्ते की प्रगति रीसेट करें? | പാതയിലെ പുരോഗതി റീസെറ്റ് ചെയ്യണോ? |
| `reset_success` | Changed | Learning progress reset | रास्ते की प्रगति रीसेट हो गई | പാതയിലെ പുരോഗതി റീസെറ്റ് ചെയ്തു |

## credits (10)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `exact_cost_note` | New | You see the exact cost before each study. | हर अध्ययन से पहले सही कीमत दिखती है। | ഓരോ പഠനത്തിനും മുമ്പ് കൃത്യമായ ചെലവ് കാണാം. |
| `follow_up` | New | Follow-up | आगे के सवाल | തുടർചോദ്യം |
| `get` | New | Get credits | क्रेडिट लें | ക്രെഡിറ്റ് നേടൂ |
| `maybe_later` | New | Maybe later | बाद में | പിന്നീട് |
| `out_body` | New | Come back tomorrow when your credits refresh, or get more now. | कल क्रेडिट फिर मिलेंगे, या अभी और लें। | നാളെ വീണ്ടും ലഭിക്കും, അല്ലെങ്കിൽ ഇപ്പോൾ വാങ്ങാം. |
| `out_eyebrow` | New | Out of credits | क्रेडिट खत्म | ക്രെഡിറ്റ് തീർന്നു |
| `out_need` | New | You need {need} credits — {have} left today. | {need} क्रेडिट चाहिए — आज {have} बचे हैं। | {need} വേണം — ഇന്ന് {have} ബാക്കി. |
| `out_title` | New | Out of study credits | अध्ययन क्रेडिट खत्म | പഠന ക്രെഡിറ്റ് തീർന്നു |
| `study_costs` | New | What a study costs | एक अध्ययन की लागत | ഒരു പഠനത്തിന് |
| `view_saved` | New | View saved guides | सहेजी गई गाइड देखें | സേവ് ചെയ്ത ഗൈഡുകൾ കാണൂ |

## follow_up_chat (10)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `cancel` | Changed | Cancel | रद्द करें | റദ്ദാക്കൂ |
| `greeting` | New | Ask me anything about this study. I'll answer from Scripture. | इस अध्ययन के बारे में कुछ भी पूछें। मैं बाइबल से जवाब दूँगा। | ഈ പഠനത്തെക്കുറിച്ച് എന്തും ചോദിക്കൂ. തിരുവെഴുത്തിൽ നിന്ന് ഞാൻ മറുപടി പറയാം. |
| `limit_reached` | Changed | Follow-up Limit Reached | सीमा पूरी हो गई | പരിധി കഴിഞ്ഞു |
| `prompt_apply` | New | How can I apply this to my life? | मैं इसे अपने जीवन में कैसे लागू करूँ? | ഇത് എന്റെ ജീവിതത്തിൽ എങ്ങനെ പ്രയോഗിക്കാം? |
| `prompt_explain` | New | Explain this passage in simple words | इस अंश को आसान शब्दों में समझाइए | ഈ ഭാഗം ലളിതമായി വിശദീകരിക്കൂ |
| `prompt_verses` | New | Which other verses teach this? | और कौन-से वचन यही सिखाते हैं? | ഇതേ കാര്യം പഠിപ്പിക്കുന്ന മറ്റു വാക്യങ്ങൾ ഏതെല്ലാം? |
| `send` | New | Send | भेजें | അയയ്ക്കുക |
| `speech_not_available` | Changed | Speech recognition is not available on this device | इस डिवाइस पर बोलकर लिखना नहीं चलता | ഈ ഉപകരണത്തിൽ സംസാരം തിരിച്ചറിയൽ ലഭ്യമല്ല |
| `title` | Changed | Follow-up Questions | आगे के सवाल | തുടർചോദ്യങ്ങൾ |
| `upgrade_plan` | Changed | Upgrade Plan | प्लान अपग्रेड करें | പ്ലാൻ അപ്‌ഗ്രേഡ് ചെയ്യൂ |

## learning_paths (10)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `continue_lesson` | New | Continue · Lesson {n} | जारी रखें · पाठ {n} | തുടരുക · പാഠം {n} |
| `lessons_days` | New | {n} lessons · {d} days | {n} पाठ · {d} दिन | {n} പാഠം · {d} ദിവസം |
| `loading_topics` | Changed | Loading lessons... | पाठ लोड हो रहे हैं... | പാഠങ്ങൾ ലോഡ് ചെയ്യുന്നു... |
| `next_topic` | Changed | Next lesson | अगला पाठ | അടുത്ത പാഠം |
| `offline_title` | New | You're offline | आप ऑफ़लाइन हैं | നിങ്ങൾ ഓഫ്‌ലൈനാണ് |
| `path_completed` | Changed | Path Completed! | रास्ता पूरा हुआ! | പാത പൂർത്തിയായി! |
| `review_lesson` | New | Review · Lesson 1 | दोहराएँ · पाठ 1 | വീണ്ടും · പാഠം 1 |
| `start_lesson` | New | Start lesson {n} | पाठ {n} शुरू करें | പാഠം {n} തുടങ്ങാം |
| `topics` | Changed | Lessons | पाठ | പാഠം |
| `topics_completed` | Changed | {completed} of {total} done | {total} में से {completed} पूर्ण | {total}-ൽ {completed} പൂർത്തിയായി |

## lesson (10)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `back_home` | New | Back to Home | होम पर जाएँ | ഹോമിലേക്ക് |
| `complete_title` | New | Lesson {n} complete | पाठ {n} पूरा | പാഠം {n} പൂർത്തിയായി |
| `continue_to` | New | Continue to lesson {n} | पाठ {n} पर जाएँ | പാഠം {n} തുടരാം |
| `eyebrow` | New | Lesson {n} of {total} | पाठ {n}/{total} | പാഠം {n}/{total} |
| `full_guide` | New | Full guide · {min} min | पूरी गाइड · {min} मिनट | പൂർണ ഗൈഡ് {min} മി |
| `full_guide_link` | New | Want the full study? Read the full guide | पूरा अध्ययन? पूरी गाइड पढ़ें | മുഴുവൻ പഠനം വേണോ? പൂർണ്ണ ഗൈഡ് വായിക്കൂ |
| `mark_complete` | New | Mark complete · Lesson {n} of {total} | पूरा करें · पाठ {n}/{total} | പൂർത്തിയായി · പാഠം {n}/{total} |
| `path_finished` | New | You finished {path} | आपने {path} पूरा किया | {path} പൂർത്തിയാക്കി |
| `quick_read` | New | Quick read · {min} min | छोटी · {min} मिनट | വേഗ വായന {min} മി |
| `up_next` | New | Up next | आगे | അടുത്തത് |

## login (10)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `chip_daily_verse` | New | Daily verse | दैनिक वचन | ദിനവചനം |
| `chip_discipler` | New | Talk to Discipler | Discipler से बात करें | Discipler-നോട് സംസാരിക്കുക |
| `chip_memory_verses` | New | Memory verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |
| `chip_study_guides` | New | Study guides | अध्ययन गाइड | പഠന ഗൈഡുകൾ |
| `feature_daily_verse` | Changed | Daily Verse & Insights | दैनिक वचन और अंतर्दृष्टि | ഇന്നത്തെ വചനവും ഉൾക്കാഴ്ചകളും |
| `feature_daily_verse_subtitle` | Changed | Start each day with inspiring scripture and instant study guides | प्रेरणा देने वाले वचन और झटपट अध्ययन गाइड के साथ हर दिन शुरू करें | പ്രചോദനാത്മക വചനങ്ങളും പെട്ടെന്നുള്ള പഠന ഗൈഡുകളും ഉപയോഗിച്ച് ഓരോ ദിവസവും ആരംഭിക്കുക |
| `feature_memory_verse` | Changed | Memory Verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |
| `feature_memory_verse_subtitle` | Changed | Memorize Scripture with spaced repetition | सही अंतराल पर दोहराकर वचन याद करें | ഇടവേളകളിൽ ആവർത്തിച്ച് വചനങ്ങൾ മനഃപാഠമാക്കുക |
| `feature_voice_discipler` | Changed | Talk to Discipler | Discipler से बात करें | Discipler-നോട് സംസാരിക്കുക |
| `languages_line` | New | English · Hindi · Malayalam | अंग्रेज़ी · हिन्दी · मलयालम | ഇംഗ്ലീഷ് · ഹിന്ദി · മലയാളം |

## practice_mode (10)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `audio` | Changed | Audio | ऑडियो | ഓഡിയോ |
| `audio_desc` | Changed | Say it aloud from memory | याद से ज़ोर से बोलें | ഓർമ്മയിൽ നിന്ന് ഉറക്കെ പറയുക |
| `cloze_desc` | Changed | Complete the missing words | छूटे शब्द भरें | വിട്ട വാക്കുകൾ പൂരിപ്പിക്കുക |
| `first_letter_desc` | Changed | Recall from first letters | पहले अक्षरों से याद करें | ആദ്യ അക്ഷരങ്ങളിൽ നിന്ന് ഓർക്കുക |
| `flip_card` | Changed | Flip Card | कार्ड पलटें | കാർഡ് മറിക്കൂ |
| `flip_card_desc` | Changed | Tap to reveal the verse | वचन देखने के लिए टैप करें | വചനം കാണാൻ ടാപ്പ് ചെയ്യുക |
| `progressive_desc` | Changed | Uncover it word by word | शब्द दर शब्द खोलें | വാക്ക് വാക്കായി തുറക്കുക |
| `type_it_out_desc` | Changed | Type the whole verse | पूरा वचन टाइप करें | മുഴുവൻ വചനവും ടൈപ്പ് ചെയ്യുക |
| `word_bank_desc` | Changed | Build it from a word bank | शब्द-सूची से वचन बनाएँ | വാക്കുകളിൽ നിന്ന് വചനം ഉണ്ടാക്കുക |
| `word_scramble_desc` | Changed | Put phrases in order | वाक्यांश क्रम से लगाएँ | വാക്യാംശങ്ങൾ ക്രമത്തിലാക്കുക |

## memory_stats_page (9)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `load_failed` | Changed | Failed to load statistics | आंकड़े लोड करने में विफल | കണക്കുകൾ ലോഡ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു |
| `no_data` | Changed | No statistics available yet | अभी तक कोई आंकड़े उपलब्ध नहीं | ഇതുവരെ കണക്കുകൾ ലഭ്യമല്ല |
| `perfect_recalls` | Changed | Perfect Recalls | बिल्कुल सही याद | പരിപൂർണ്ണ ഓർമ്മകൾ |
| `practice_days` | Changed | Practice Days | अभ्यास के दिन | പരിശീലന ദിവസങ്ങൾ |
| `short_days` | New | practice days | अभ्यास दिन | പരിശീലന ദിനം |
| `short_perfect` | New | perfect | सटीक | പൂർണ്ണം |
| `short_reviews` | New | reviews | समीक्षाएँ | അവലോകനം |
| `short_verses` | New | verses | वचन | വചനങ്ങൾ |
| `title` | Changed | Memory Statistics | याद करने के आंकड़े | മനഃപാഠ കണക്കുകൾ |

## reflection_journal (9)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `count` | New | {count} reflections | {count} मनन | {count} ധ്യാനങ്ങൾ |
| `delete_failed` | Changed | Failed to delete. Please try again. | हटाने में विफल। कृपया पुनः प्रयास करें। | ഇല്ലാതാക്കുന്നത് പരാജയപ്പെട്ടു. വീണ്ടും ശ്രമിക്കുക. |
| `empty_message` | Changed | Complete a study guide in Reflect Mode to see your reflections here. | अपने विचार यहां देखने के लिए चिंतन मोड में पढ़ाई पूरी करें। | നിങ്ങളുടെ ചിന്തനങ്ങൾ ഇവിടെ കാണാൻ ചിന്തന മോഡിൽ ഒരു പഠന ഗൈഡ് പൂർത്തിയാക്കുക. |
| `load_study_failed` | New | Couldn't open this study. Please try again. | यह अध्ययन नहीं खुल सका। कृपया फिर से प्रयास करें। | ഈ പഠനം തുറക്കാൻ കഴിഞ്ഞില്ല. വീണ്ടും ശ്രമിക്കുക. |
| `minutes` | New | {minutes} min | {minutes} मिनट | {minutes} മിനിറ്റ് |
| `start_study` | Changed | Start a study | पढ़ाई शुरू करें | പഠനം ആരംഭിക്കുക |
| `title` | Changed | Reflection journal | सोच की डायरी | ചിന്തന ഡയറി |
| `today` | New | Today | आज | ഇന്ന് |
| `yesterday` | New | Yesterday | कल | ഇന്നലെ |

## streak_milestone (9)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `continue` | New | Continue | आगे बढ़ें | തുടരുക |
| `eyebrow` | New | Streak milestone | स्ट्रीक उपलब्धि | തുടർച്ചയുടെ നാഴികക്കല്ല് |
| `message_10` | New | You're building a great habit! Keep going! | आप एक अच्छी आदत बना रहे हैं! जारी रखें! | നിങ്ങൾ ഒരു നല്ല ശീലം വളർത്തുന്നു! തുടരുക! |
| `message_100` | New | Incredible persistence! You're a memorization champion! | अद्भुत दृढ़ता! आप याद करने के चैंपियन हैं! | അവിശ്വസനീയമായ സ്ഥിരോത്സാഹം! നിങ്ങൾ മനഃപാഠ ചാമ്പ്യനാണ്! |
| `message_30` | New | A month of dedication! Your commitment is inspiring! | एक महीने का समर्पण! आपकी प्रतिबद्धता प्रेरणादायक है! | ഒരു മാസത്തെ സമർപ്പണം! നിങ്ങളുടെ പ്രതിബദ്ധത പ്രചോദനമാണ്! |
| `message_365` | New | An entire year of faithfulness! You're amazing! | पूरे एक साल की विश्वासयोग्यता! आप अद्भुत हैं! | ഒരു വർഷം മുഴുവൻ വിശ്വസ്തത! നിങ്ങൾ അത്ഭുതമാണ്! |
| `message_default` | New | Your dedication is inspiring! | आपका समर्पण प्रेरणादायक है! | നിങ്ങളുടെ സമർപ്പണം പ്രചോദനമാണ്! |
| `title_days` | New | {count}-Day Streak! | लगातार {count} दिन! | {count} ദിവസം തുടർച്ചയായി! |
| `title_year` | New | Full Year Streak! | पूरा साल लगातार! | ഒരു വർഷം തുടർച്ചയായി! |

## study_ui (9)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `dismiss` | New | Not now | अभी नहीं | ഇപ്പോൾ വേണ്ട |
| `generation_interrupted` | New | Generation stopped part-way. What was ready is shown below. | गाइड बनाना बीच में रुक गया। जो तैयार हुआ वह नीचे दिखाया गया है। | ഗൈഡ് തയ്യാറാക്കൽ ഇടയ്ക്ക് നിന്നുപോയി. തയ്യാറായ ഭാഗം താഴെ കാണാം. |
| `generation_timeout` | New | Study generation is taking longer than expected. Please try again. | अध्ययन गाइड बनने में उम्मीद से ज़्यादा समय लग रहा है। कृपया फिर से कोशिश करें। | പഠന ഗൈഡ് തയ്യാറാക്കാൻ പ്രതീക്ഷിച്ചതിലും കൂടുതൽ സമയമെടുക്കുന്നു. വീണ്ടും ശ്രമിക്കുക. |
| `offline_generate` | New | Connect to the internet to generate a study guide | अध्ययन गाइड बनाने के लिए इंटरनेट से जुड़ें | പഠന ഗൈഡ് തയ്യാറാക്കാൻ ഇന്റർനെറ്റുമായി ബന്ധിപ്പിക്കുക |
| `screenshot.body` | New | You took a screenshot. Want to share it? | आपने स्क्रीनशॉट लिया है। क्या इसे साझा करना चाहेंगे? | നിങ്ങൾ ഒരു സ്ക്രീൻഷോട്ട് എടുത്തു. ഇത് പങ്കിടണോ? |
| `screenshot.eyebrow` | New | Screenshot | स्क्रीनशॉट | സ്ക്രീൻഷോട്ട് |
| `screenshot.share_fellowship` | New | Share to Fellowship | संगति में साझा करें | കൂട്ടായ്മയിൽ പങ്കിടുക |
| `screenshot.title` | New | Share your study guide | अपनी अध्ययन गाइड साझा करें | നിങ്ങളുടെ പഠന ഗൈഡ് പങ്കിടുക |
| `tokens_per_guide` | New | {count} credits | {count} क्रेडिट | {count} ക്രെഡിറ്റ് |

## community_lessons (8)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `advance_hint` | New | Moves everyone to lesson {number} | सभी को पाठ {number} पर ले जाता है | എല്ലാവരെയും പാഠം {number}-ലേക്ക് നീക്കുന്നു |
| `caught_up` | New | {count} of {total} caught up | {total} में से {count} साथ चल रहे हैं | {total}-ൽ {count} പേർ ഒപ്പമുണ്ട് |
| `group_done` | New | {done} of {total} done | {total} में से {done} पूरे | {total}-ൽ {done} പൂർത്തിയായി |
| `group_finished` | New | Finished all {total} lessons together | सभी {total} पाठ साथ में पूरे किए | എല്ലാ {total} പാഠങ്ങളും ഒരുമിച്ച് പൂർത്തിയാക്കി |
| `status_done` | New | Completed | पूरा हुआ | പൂർത്തിയായി |
| `status_locked` | New | Locked | लॉक है | ലോക്ക് ചെയ്തു |
| `status_upcoming` | New | Upcoming | आगामी | വരാനിരിക്കുന്നത് |
| `xp_earned` | New | +{xp} XP earned | +{xp} XP अर्जित | +{xp} XP നേടി |

## streak_protection (8)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `at_risk` | New | Your {count}-day streak is at risk! | आपकी {count} दिन की स्ट्रीक खतरे में है! | {count} ദിവസത്തെ തുടർച്ച അപകടത്തിലാണ്! |
| `available` | New | Available freeze days | उपलब्ध फ्रीज़ दिन | ലഭ്യമായ ഫ്രീസ് ദിനങ്ങൾ |
| `cancel` | New | Cancel | रद्द करें | റദ്ദാക്കുക |
| `earn_more` | New | Earn 1 freeze day for every 7 consecutive days of practice (max 5). | लगातार 7 दिन अभ्यास करने पर 1 फ्रीज़ दिन पाएं (अधिकतम 5)। | തുടർച്ചയായ ഓരോ 7 ദിവസത്തെ പരിശീലനത്തിനും 1 ഫ്രീസ് ദിനം നേടുക (പരമാവധി 5). |
| `explanation` | New | Use a freeze day to protect your streak on a day you couldn't practice. | जिस दिन आप अभ्यास नहीं कर पाए, उस दिन अपनी स्ट्रीक बचाने के लिए एक फ्रीज़ दिन का उपयोग करें। | പരിശീലിക്കാൻ കഴിയാത്ത ദിവസം തുടർച്ച സംരക്ഷിക്കാൻ ഒരു ഫ്രീസ് ദിനം ഉപയോഗിക്കുക. |
| `eyebrow` | New | Freeze day | फ्रीज़ दिन | ഫ്രീസ് ദിനം |
| `title` | New | Protect Your Streak | स्ट्रीक बचाएं | തുടർച്ച സംരക്ഷിക്കൂ |
| `use` | New | Use Freeze Day | फ्रीज़ दिन उपयोग करें | ഫ്രീസ് ദിനം ഉപയോഗിക്കുക |

## study_mode (8)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `deep.short_name` | New | Deep Dive | गहरी पढ़ाई | ആഴത്തിൽ |
| `lectio.short_name` | New | Lectio | लेक्टियो | ലെക്‌ഷ്യോ |
| `minutes` | New | {count} min | {count} मिनट | {count} മിനിറ്റ് |
| `quick.name` | Changed | Quick Read | छोटी पढ़ाई | വേഗ വായന |
| `quick.short_name` | New | Quick Read | छोटी पढ़ाई | വേഗ വായന |
| `sermon.short_name` | New | Sermon | उपदेश | പ്രഭാഷണം |
| `standard.name` | Changed | Standard Study | सामान्य पढ़ाई | സാധാരണ പഠനം |
| `standard.short_name` | New | Standard | सामान्य | സാധാരണ |

## auth_notices (7)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `otp_code_sent` | New | Verification code sent! | सत्यापन कोड भेज दिया गया! | സ്ഥിരീകരണ കോഡ് അയച്ചു! |
| `otp_incomplete` | New | Please enter the complete 6-digit code | कृपया पूरा 6-अंकों का कोड दर्ज करें | ദയവായി 6 അക്ക കോഡ് പൂർണ്ണമായി നൽകുക |
| `profile_image_failed` | New | Failed to select image. Please try again. | फ़ोटो चुनी नहीं जा सकी। कृपया फिर से प्रयास करें। | ചിത്രം തിരഞ്ഞെടുക്കാനായില്ല. ദയവായി വീണ്ടും ശ്രമിക്കുക. |
| `profile_image_web_only` | New | Image upload is currently only supported on web | फ़ोटो अपलोड अभी केवल वेब पर उपलब्ध है | ചിത്രം അപ്‌ലോഡ് ചെയ്യുന്നത് ഇപ്പോൾ വെബിൽ മാത്രമേ ലഭ്യമാകൂ |
| `profile_select_age_group` | New | Please select your age group | कृपया अपना आयु वर्ग चुनें | ദയവായി നിങ്ങളുടെ പ്രായവിഭാഗം തിരഞ്ഞെടുക്കുക |
| `profile_select_interest` | New | Please select at least one interest | कृपया कम से कम एक रुचि चुनें | ദയവായി കുറഞ്ഞത് ഒരു താൽപ്പര്യമെങ്കിലും തിരഞ്ഞെടുക്കുക |
| `sign_in_cancelled` | New | Sign-in was cancelled. | साइन-इन रद्द कर दिया गया। | സൈൻ-ഇൻ റദ്ദാക്കി. |

## feedback (7)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `category.bug_report` | Changed | Bug Report | गड़बड़ी की रिपोर्ट | പിശക് റിപ്പോർട്ട് |
| `category.feature_request` | Changed | Feature Request | नई सुविधा का सुझाव | പുതിയ സവിശേഷതയ്ക്കുള്ള അഭ്യർത്ഥന |
| `category.memory_verse` | Changed | Memory Verse | याद वचन | മനഃപാഠ വാക്യം |
| `not_yet` | New | Not yet | अभी नहीं | ഇതുവരെ ഇല്ല |
| `submit_error` | Changed | Failed to prepare feedback submission. Please try again. | फीडबैक भेजा नहीं जा सका। कृपया पुनः प्रयास करें। | ഫീഡ്ബാക്ക് സമർപ്പിക്കൽ തയ്യാറാക്കുന്നതിൽ പരാജയപ്പെട്ടു. ദയവായി വീണ്ടും ശ്രമിക്കുക. |
| `topic` | New | Topic | विषय | വിഷയം |
| `yes` | New | Yes | हाँ | അതെ |

## practice_tier_locked (7)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_modes_plus` | New | All {count} practice modes + {limit} | सभी {count} अभ्यास मोड + {limit} | എല്ലാ {count} പരിശീലന രീതികളും + {limit} |
| `all_modes_unlimited` | New | All {count} practice modes + unlimited practice | सभी {count} अभ्यास मोड + असीमित अभ्यास | എല്ലാ {count} പരിശീലന രീതികളും + പരിധിയില്ലാത്ത പരിശീലനം |
| `maybe_later` | New | Maybe Later | बाद में | പിന്നീട് |
| `plan_includes` | New | Your {plan} Plan Includes: | आपके {plan} प्लान में शामिल: | നിങ്ങളുടെ {plan} പ്ലാനിൽ ഉള്ളത്: |
| `title` | New | Upgrade Required | अपग्रेड ज़रूरी है | അപ്‌ഗ്രേഡ് ആവശ്യമാണ് |
| `unlock_with` | New | Unlock advanced practice modes with: | उन्नत अभ्यास मोड इनके साथ अनलॉक करें: | വിപുലമായ പരിശീലന രീതികൾ ഇവയിലൂടെ അൺലോക്ക് ചെയ്യൂ: |
| `upgrade_now` | New | Upgrade Now | अभी अपग्रेड करें | അപ്‌ഗ്രേഡ് ചെയ്യൂ |

## goal (6)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `fresh_start` | New | Forgiveness and a fresh start | क्षमा और नई शुरुआत | ക്ഷമയും പുതിയ തുടക്കവും |
| `hope_hard_times` | New | Hope in hard times | कठिन समय में आशा | പ്രയാസത്തിൽ പ്രത്യാശ |
| `new_to_faith` | New | I'm new to faith | मैं विश्वास में नया हूँ | പുതിയ വിശ്വാസി |
| `read_gospel` | New | Reading a Gospel | एक सुसमाचार पढ़ना | സുവിശേഷ വായന |
| `understand_gospel` | New | Understanding the gospel | सुसमाचार को समझना | സുവിശേഷം മനസ്സിലാക്കുക |
| `walk_with_god` | New | Walking with God daily | हर दिन परमेश्वर के साथ चलना | ദൈവത്തോടൊപ്പം നടക്കുക |

## memory_add_feedback (6)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `added` | New | Added to Memory Verses! Start reviewing to memorize this verse. | याद वचनों में जोड़ा गया! इसे याद करने के लिए दोहराना शुरू करें। | മനഃപാഠ വാക്യങ്ങളിൽ ചേർത്തു! ഈ വചനം മനഃപാഠമാക്കാൻ ആവർത്തിക്കാൻ തുടങ്ങുക. |
| `already_exists` | New | Verse already in your memory deck | यह वचन पहले से आपके याद वचनों में है | ഈ വചനം ഇതിനകം മനഃപാഠ വാക്യങ്ങളിലുണ്ട് |
| `limit_reached` | New | You have reached your memory verse limit. Upgrade your plan to add more. | आप अपनी याद वचन सीमा तक पहुँच गए हैं। और जोड़ने के लिए अपना प्लान अपग्रेड करें। | നിങ്ങളുടെ മനഃപാഠ വാക്യ പരിധി എത്തി. കൂടുതൽ ചേർക്കാൻ പ്ലാൻ അപ്‌ഗ്രേഡ് ചെയ്യുക. |
| `queued` | New | You are offline. The verse will be added when you are back online. | आप ऑफ़लाइन हैं। ऑनलाइन होते ही वचन जोड़ दिया जाएगा। | നിങ്ങൾ ഓഫ്‌ലൈനാണ്. ഓൺലൈനിൽ വരുമ്പോൾ വചനം ചേർക്കും. |
| `review` | New | Review | दोहराएं | ആവർത്തിക്കുക |
| `review_now` | New | Review Now | अभी दोहराएं | ഇപ്പോൾ ആവർത്തിക്കുക |

## plan (6)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `billed_via` | New | Billed via {provider} | {provider} से बिलिंग | {provider} വഴി ബില്ലിംഗ് |
| `left_today` | New | {n} left today | आज {n} बचे | ഇന്ന് {n} ബാക്കി |
| `renews_on` | New | Renews {date} | {date} को नवीनीकरण | {date}-ന് പുതുക്കൽ |
| `resets_at` | New | Resets at {time} | {time} पर फिर से | {time}-ന് പുതുക്കും |
| `trial_until` | New | Free trial until {date} | {date} तक मुफ़्त ट्रायल | {date} വരെ ട്രയൽ |
| `view_plans` | New | View plans | प्लान देखें | പ്ലാനുകൾ |

## all_paths (5)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all` | New | All | सभी | എല്ലാം |
| `count` | New | {n} paths | {n} रास्ते | {n} പാതകൾ |
| `current` | New | Current | वर्तमान | ഇപ്പോൾ |
| `lesson_of` | New | Lesson {n} of {total} | पाठ {n}/{total} | പാഠം {n}/{total} |
| `title` | New | All paths | सभी रास्ते | പാതകൾ |

## daily_verse (5)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `add_to_memory` | Changed | Add to Memory Verses | याद वचनों में जोड़ें | മനഃപാഠ വാക്യങ്ങളിലേക്ക് ചേർക്കുക |
| `already_in_memory` | Changed | Already in Memory Verses | पहले से याद वचनों में है | ഇതിനകം മനഃപാഠ വാക്യങ്ങളിലുണ്ട് |
| `cached` | Changed | Cached | पहले से सहेजा | കാഷ് ചെയ്തത് |
| `loading` | Changed | Loading Verse of the Day... | आज का वचन लोड हो रहा है... | ഇന്നത്തെ വചനം ലോഡ് ചെയ്യുന്നു... |
| `of_the_day` | Changed | Verse of the Day | आज का वचन | ഇന്നത്തെ വചനം |

## email_auth (5)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `new_password_hint` | New | At least 8 characters | कम से कम 8 अक्षर | കുറഞ്ഞത് 8 അക്ഷരങ്ങൾ |
| `sign_in_eyebrow` | New | Welcome back | फिर से स्वागत है | വീണ്ടും സ്വാഗതം |
| `sign_in_title` | New | Sign in | साइन इन | സൈൻ ഇൻ |
| `sign_up_eyebrow` | New | Join Disciplefy | Disciplefy से जुड़ें | Disciplefy-യിൽ ചേരൂ |
| `sign_up_title` | New | Create account | खाता बनाएं | അക്കൗണ്ട് സൃഷ്ടിക്കൂ |

## memory_practice (5)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `check` | New | Check | जाँचें | പരിശോധിക്കുക |
| `close_expected` | New | Close! Expected: {word} | लगभग सही! अपेक्षित: {word} | ഏതാണ്ട് ശരി! പ്രതീക്ഷിച്ചത്: {word} |
| `expected_said` | New | Expected: {expected} You said: {said} | अपेक्षित: {expected} आपने कहा: {said} | പ്രതീക്ഷിച്ചത്: {expected} നിങ്ങൾ പറഞ്ഞത്: {said} |
| `hint` | New | Hint | संकेत | സൂചന |
| `hint_count` | New | Hint · {count} | संकेत · {count} | സൂചന · {count} |

## progressive_reveal (5)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `auto_reveal` | Changed | Auto Reveal | अपने आप दिखाएं | സ്വയം വെളിപ്പെടുത്തൽ |
| `auto_reveal_label` | Changed | Auto Reveal | अपने आप दिखाएं | സ്വയം വെളിപ്പെടുത്തൽ |
| `phrase_by_phrase_label` | Changed | Phrase by phrase | वाक्यांश-दर-वाक्यांश | വാക്യാംശം-വാക്യാംശമായി |
| `reveal_next` | Changed | Reveal next | अगला शब्द प्रकट करें | അടുത്ത വാക്ക് വെളിപ്പെടുത്തുക |
| `word_by_word_label` | Changed | Word by word | शब्द-दर-शब्द | വാക്ക്-വാക്കായി |

## topics (5)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `browse_all` | New | Browse all paths | सभी रास्ते देखें | എല്ലാ പാതകളും |
| `continue` | New | Continue | जारी रखें | തുടരുക |
| `see_all` | New | See all | सभी देखें | എല്ലാം കാണൂ |
| `start_a_path` | New | Start a path | रास्ता शुरू करें | പാത തുടങ്ങാം |
| `title` | New | Topics | विषय | വിഷയം |

## learning_path (4)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `always_use_recommended` | Changed | Always use recommended mode for learning paths | रास्तों के लिए हमेशा सुझाया गया मोड | പാതയ്ക്ക് എപ്പോഴും ശുപാർശ ചെയ്ത മോഡ് ഉപയോഗിക്കുക |
| `always_use_recommended_subtitle` | Changed | Skip this selection for all path lessons | रास्ते के सभी पाठों के लिए यह चयन छोड़ें | പാതയിലെ എല്ലാ പാഠങ്ങൾക്കും ഈ തിരഞ്ഞെടുപ്പ് ഒഴിവാക്കുക |
| `completed_in_recommended` | Changed | ✨ Completed in recommended mode | ✨ अनुशंसित मोड में पूर्ण | ✨ ശുപാർശ ചെയ്ത മോഡിൽ പൂർത്തിയായി |
| `recommended_mode_badge` | Changed | RECOMMENDED FOR THIS PATH | इस रास्ते के लिए सुझाया गया | ഈ പാതയ്ക്ക് ശുപാർശ ചെയ്യുന്നത് |

## mode_selection (4)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `always_use_recommended` | Changed | Always use recommended | हमेशा सुझाया गया मोड | എപ്പോഴും ശുപാർശ ചെയ്ത മോഡ് |
| `recommended_badge` | Changed | RECOMMENDED | अनुशंसित | ശുപാർശ ചെയ്യുന്നത് |
| `remember_choice` | Changed | Remember my choice | मेरी पसंद याद रखें | എന്റെ തിരഞ്ഞെടുപ്പ് ഓർക്കുക |
| `time_question` | New | How much time do you have? | आपके पास कितना समय है? | നിങ്ങൾക്ക് എത്ര സമയമുണ്ട്? |

## password_reset (4)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `back_to_sign_in` | Changed | Back to sign in | साइन इन पर वापस जाएं | സൈൻ ഇൻ-ലേക്ക് മടങ്ങുക |
| `eyebrow` | New | Account recovery | खाता पुनर्प्राप्ति | അക്കൗണ്ട് വീണ്ടെടുക്കൽ |
| `send_button` | Changed | Send reset link | रीसेट लिंक भेजें | റീസെറ്റ് ലിങ്ക് അയയ്ക്കുക |
| `title` | Changed | Reset password | पासवर्ड रीसेट करें | പാസ്‌വേഡ് റീസെറ്റ് ചെയ്യുക |

## practice_results (4)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `done` | Changed | Done | हो गया | പൂർത്തിയായി |
| `penalty_applied` | Changed | Yes (penalty applied) | हाँ (दंड लागू) | അതെ (ശിക്ഷ ബാധകം) |
| `practice_again` | Changed | Practice again | फिर से अभ्यास करें | വീണ്ടും പരിശീലിക്കുക |
| `title` | Changed | Practice complete | अभ्यास पूर्ण | പരിശീലനം പൂർത്തിയായി |

## subscription (4)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `included_features` | Changed | Included features | शामिल सुविधाएँ | ഉൾപ്പെടുത്തിയ സവിശേഷതകൾ |
| `title` | Changed | My subscription | मेरी सब्सक्रिप्शन | എന്റെ സബ്‌സ്‌ക്രിപ്‌ഷൻ |
| `upgrade_button` | Changed | Upgrade to Premium | प्रीमियम में अपग्रेड करें | പ്രീമിയത്തിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |
| `upgrade_prompt` | Changed | Upgrade to Premium for unlimited access | असीमित एक्सेस के लिए प्रीमियम में अपग्रेड करें | എല്ലാ പ്രീമിയം സവിശേഷതകളും അൺലോക്ക് ചെയ്യാൻ പ്രീമിയത്തിലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക |

## email_verification (3)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `description` | Changed | Please verify your email address to ensure account security and enable password recovery. | खाता सुरक्षा और पासवर्ड वापस पाने के लिए कृपया अपना ईमेल पता सत्यापित करें। | അക്കൗണ്ട് സുരക്ഷയും പാസ്‌വേഡ് വീണ്ടെടുക്കലും സാധ്യമാക്കാൻ ദയവായി നിങ്ങളുടെ ഇമെയിൽ വിലാസം സ്ഥിരീകരിക്കുക. |
| `resend_short` | New | Resend | फिर भेजें | വീണ്ടും അയയ്ക്കുക |
| `short_title` | New | Verify your email to secure your account | खाता सुरक्षित रखने के लिए ईमेल सत्यापित करें | അക്കൗണ്ട് സുരക്ഷിതമാക്കാൻ ഇമെയിൽ സ്ഥിരീകരിക്കുക |

## memory_home (3)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `feature_description` | Changed | Memorize Bible verses using proven spaced repetition techniques. Track your progress and strengthen your faith through scripture memorization. | सिद्ध अंतराल पुनरावृत्ति तकनीकों का उपयोग करके बाइबिल वचनों को याद करें। अपनी प्रगति देखें और वचन याद करके अपने विश्वास को मजबूत करें। | തെളിയിക്കപ്പെട്ട ഇടവേള ആവർത്തന സാങ്കേതിക വിദ്യകൾ ഉപയോഗിച്ച് ബൈബിൾ വചനങ്ങൾ മനഃപാഠമാക്കുക. നിങ്ങളുടെ പുരോഗതി കാണുകയും തിരുവെഴുത്ത് ഓർമ്മയിലൂടെ നിങ്ങളുടെ വിശ്വാസം ശക്തിപ്പെടുത്തുകയും ചെയ്യുക. |
| `no_verses_subtitle` | Changed | Start building your memory verse collection. | अपना याद वचन संग्रह बनाना शुरू करें। | നിങ്ങളുടെ മനഃപാഠ വാക്യ ശേഖരം നിർമ്മിക്കാൻ ആരംഭിക്കുക. |
| `title` | Changed | Memory Verses | याद वचन | മനഃപാഠ വാക്യങ്ങൾ |

## practice_selection (3)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `master_this_first` | Changed | Master This First | पहले इसे पक्का करें | ആദ്യം ഇത് ഉറപ്പിക്കുക |
| `master_this_next` | Changed | Master This Next | इसे पक्का करें | ഇത് ഉറപ്പിക്കുക |
| `title` | Changed | Choose a practice | अभ्यास चुनें | ഒരു പരിശീലനം തിരഞ്ഞെടുക്കുക |

## questionnaire (3)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `done` | Changed | Done | हो गया | പൂർത്തിയായി |
| `step_of` | New | Step {current} of {total} | चरण {current} / {total} | ഘട്ടം {current} / {total} |
| `your_focus` | Changed | Your Focus | आपका ध्यान | നിങ്ങളുടെ ശ്രദ്ധ |

## audio_practice (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `ready_to_speak` | Changed | Ready to speak |  |  |
| `title` | Changed | Audio | ऑडियो | ഓഡിയോ |

## bug_report (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `submit_error` | Changed | Failed to prepare bug report submission. Please try again. | गड़बड़ी की रिपोर्ट भेजी नहीं जा सकी। कृपया पुनः प्रयास करें। | പിശക് റിപ്പോർട്ട് സമർപ്പിക്കൽ തയ്യാറാക്കുന്നതിൽ പരാജയപ്പെട്ടു. ദയവായി വീണ്ടും ശ്രമിക്കുക. |
| `subtitle` | Changed | Found a bug? Describe what happened and we'll fix it | कोई गड़बड़ी मिली? बताएं क्या हुआ और हम इसे ठीक करेंगे | ഒരു പിശക് കണ്ടെത്തിയോ? എന്താണ് സംഭവിച്ചതെന്ന് വിവരിക്കുക, ഞങ്ങൾ അത് പരിഹരിക്കും |

## leaderboard (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `title` | Changed | Champions | चैंपियन | ചാമ്പ്യന്മാർ |
| `xp_to_pass` | New | {xp} XP to pass {name} | {name} से आगे निकलने के लिए {xp} XP | {name}-നെ മറികടക്കാൻ {xp} XP |

## memory_champions (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `streak` | Changed | Streak | स्ट्रीक | തുടർച്ച |
| `title` | Changed | Memory Champions | याद वचन चैंपियन | മനഃപാഠ ചാമ്പ്യന്മാർ |

## memory_stats (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `current_streak` | Changed | Current Streak | मौजूदा स्ट्रीक | നിലവിലെ തുടർച്ച |
| `title` | Changed | Statistics | आंकड़े | സ്ഥിതിവിവരം |

## self_assessment (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `subtitle` | Changed | Be honest — this sets your next review | ईमानदारी से बताएं — इसी से आपकी अगली समीक्षा तय होती है | സത്യസന്ധമായി പറയുക — ഇതാണ് അടുത്ത പുനരവലോകനം നിശ്ചയിക്കുന്നത് |
| `title` | Changed | How well did you recall it? | आपको कितना अच्छा याद रहा? | നിങ്ങൾക്ക് എത്ര നന്നായി ഓർമ്മിക്കാൻ കഴിഞ്ഞു? |

## upgrade (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `to_plus` | Changed | Upgrade to Plus | प्लस में अपग्रेड करें | Plus-ലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യൂ |
| `to_standard` | Changed | Upgrade to Standard | स्टैंडर्ड में अपग्रेड करें | Standard-ലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യൂ |

## upgrade_dialog (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `benefit_memory` | Changed | Memory verse memorization | वचन याद करना | വചനം മനഃപാഠമാക്കൽ |
| `benefit_tokens` | Changed | 40 credits a day + buy more | रोज़ 40 क्रेडिट + और खरीदें | ദിവസം 40 ക്രെഡിറ്റ് + കൂടുതൽ വാങ്ങാം |

## verse_sheet (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `added_to_memory` | Changed | Added to Memory Verses | याद वचनों में जोड़ा गया | മനഃപാഠ വാക്യങ്ങളിൽ ചേർത്തു |
| `memory` | Changed | Memory | याद करें | മനഃപാഠം |

## word_bank (2)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `all_placed` | New | All words placed. Tap a word in your answer to put it back. | सभी शब्द रख दिए गए। किसी शब्द को वापस लाने के लिए अपने उत्तर में उस पर टैप करें। | എല്ലാ വാക്കുകളും വെച്ചു. ഒരു വാക്ക് തിരികെ എടുക്കാൻ ഉത്തരത്തിൽ അതിൽ ടാപ്പ് ചെയ്യുക. |
| `all_placed_done` | New | All words placed. | सभी शब्द रख दिए गए। | എല്ലാ വാക്കുകളും വെച്ചു. |

## audio (1)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `ready_to_speak` | Changed | Ready to speak | बोलने के लिए तैयार | സംസാരിക്കാൻ തയ്യാർ |

## continue_learning (1)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `empty_message` | Changed | Start a learning path to begin your journey | अपनी यात्रा शुरू करने के लिए एक रास्ता शुरू करें | നിങ്ങളുടെ യാത്ര ആരംഭിക്കാൻ ഒരു പഠന പാത തുടങ്ങുക |

## disciple_level (1)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `seeker` | Changed | Beginner | शुरुआती | തുടക്കക്കാരൻ |

## quality (1)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `needs_work` | Changed | Needs Work | सुधार आवश्यक | മെച്ചപ്പെടണം |

## sermon (1)

| Key | | English | Hindi | Malayalam |
|---|---|---|---|---|
| `thesis` | Changed | Sermon Thesis | उपदेश का मुख्य विचार | പ്രഭാഷണ തീസിസ് |
