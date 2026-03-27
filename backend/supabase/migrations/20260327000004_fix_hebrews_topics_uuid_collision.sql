-- -------------------------------------------------------
-- Fix: Hebrews path UUID collision with Historical Reliability path
-- -------------------------------------------------------
-- PROBLEM:
--   migration 20260223000001 created ab500000..001-005 for Historical Reliability path (020)
--   migration 20260313000001 tried to reuse the same IDs for Hebrews path (030) with
--   ON CONFLICT DO NOTHING — silently skipped, leaving Historical Reliability content.
--   migration 20260321000002 then added Hi/ML translations for ab500000..001-005
--   using Historical Reliability content (not Hebrews).
--   Result: ALL three languages show Historical Reliability topics 1-5 in the Hebrews path.
--
-- FIX:
--   1. UPDATE ab500000..001-005 English to correct Hebrews 1-5 content
--   2. INSERT new b0200000..001-005 for displaced Historical Reliability topics
--   3. INSERT Hi/ML translations for new b0200000 IDs
--   4. UPDATE Hi/ML translations for ab500000..001-005 to Hebrews content
--   5. UPDATE learning_path_topics for path 020 to use b0200000 IDs
-- -------------------------------------------------------

-- -------------------------------------------------------
-- STEP 1: Fix English base content for ab500000..001-005 → Hebrews 1-5
-- -------------------------------------------------------
UPDATE recommended_topics SET
  title        = 'The Supremacy of Christ',
  description  = 'God spoke through prophets in many ways at many times, but in these last days he has spoken through his Son — the radiance of his glory and the exact imprint of his nature. Hebrews opens by establishing Christ''s absolute supremacy: above the prophets, above the angels who mediated the Law, seated at the right hand of the Majesty on high. Every argument in Hebrews builds on this foundation.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['hebrews', 'christ', 'supremacy', 'revelation'],
  display_order = 381
WHERE id = 'ab500000-e29b-41d4-a716-446655440001';

UPDATE recommended_topics SET
  title        = 'A Great Salvation',
  description  = 'The first of Hebrews'' great warnings: "How shall we escape if we neglect such a great salvation?" The Son who is above angels shared in human flesh and blood, tasted death for everyone, and destroyed the power of the devil. Because he suffered and was tempted, he is able to help those who are tempted. The word is urgent: do not drift from what you have heard.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['hebrews', 'salvation', 'warning', 'suffering'],
  display_order = 382
WHERE id = 'ab500000-e29b-41d4-a716-446655440002';

UPDATE recommended_topics SET
  title        = 'Jesus Greater Than Moses',
  description  = 'Moses was faithful as a servant in God''s house; Jesus is faithful as the Son over God''s house, and we are that house if we hold our confidence firm. The second warning: "Harden not your hearts as in the rebellion." The Israelite generation that witnessed God''s miracles did not enter rest because of unbelief. Perseverance is not a supplement to saving faith — it is the shape saving faith takes through time.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['hebrews', 'moses', 'warning', 'perseverance'],
  display_order = 383
WHERE id = 'ab500000-e29b-41d4-a716-446655440003';

UPDATE recommended_topics SET
  title        = 'Entering God''s Rest',
  description  = 'The promise of rest remains — a rest the Israelites failed to enter through unbelief, and that Joshua''s conquest only partially anticipated. God''s rest (sabbatismos) is the ultimate inheritance of his people, a rest from works as God rested from his. The living and active word of God, sharper than any two-edged sword, lays bare the heart''s condition before the God to whom we must give account.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['hebrews', 'rest', 'word of god', 'faith'],
  display_order = 384
WHERE id = 'ab500000-e29b-41d4-a716-446655440004';

UPDATE recommended_topics SET
  title        = 'Our Great High Priest',
  description  = 'Jesus is our great High Priest who has passed through the heavens, who can sympathize with our weaknesses because he was tempted in every respect as we are — yet without sin. He did not exalt himself but was appointed by God, like Melchizedek. This is an introduction to the Melchizedek argument that will be developed fully in chapter 7.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['hebrews', 'high priest', 'melchizedek', 'sympathy'],
  display_order = 385
WHERE id = 'ab500000-e29b-41d4-a716-446655440005';

-- -------------------------------------------------------
-- STEP 2: INSERT new b0200000..001-005 for displaced Historical Reliability topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('b0200000-e29b-41d4-a716-446655440001', 'Manuscript Evidence for the New Testament',
   'The New Testament is the most well-attested ancient document in history — with over 5,800 Greek manuscripts and thousands more in other languages. Study the science of textual criticism, understand why scholars trust the text we have, and see how the manuscript evidence for the New Testament far surpasses any other ancient work.',
   'Apologetics', ARRAY['manuscripts', 'new testament', 'textual criticism', 'reliability'], 291, 50),

  ('b0200000-e29b-41d4-a716-446655440002', 'Archaeological Confirmation of the Bible',
   'Archaeology has repeatedly confirmed biblical accounts that skeptics once dismissed as legendary — the walls of Jericho, the Pool of Siloam, Pontius Pilate''s inscription, and much more. Survey major archaeological discoveries that corroborate the biblical narrative and understand how these findings support the historical trustworthiness of Scripture.',
   'Apologetics', ARRAY['archaeology', 'bible', 'history', 'evidence'], 292, 50),

  ('b0200000-e29b-41d4-a716-446655440003', 'Old Testament Prophecies Fulfilled in Christ',
   'The Old Testament contains hundreds of specific prophecies fulfilled in the life, death, and resurrection of Jesus — written centuries before His birth. Study key messianic prophecies (Isaiah 53, Psalm 22, Micah 5, Daniel 9) and see how their precise fulfillment in Christ provides powerful evidence for the divine inspiration of Scripture.',
   'Apologetics', ARRAY['prophecy', 'messiah', 'fulfillment', 'old testament'], 293, 50),

  ('b0200000-e29b-41d4-a716-446655440004', 'The Resurrection as Historical Fact',
   'The resurrection of Jesus is the cornerstone of the Christian faith — and it is a claim to be investigated historically, not just believed by faith. Study the evidence: the empty tomb, post-resurrection appearances, the radical transformation of the disciples, and the explosive growth of the early church. The resurrection is the best explanation of the historical facts.',
   'Apologetics', ARRAY['resurrection', 'history', 'evidence', 'empty tomb'], 294, 50),

  ('b0200000-e29b-41d4-a716-446655440005', 'How the Canon Was Formed',
   'Why these 66 books and not others? The canon was not invented at Nicaea — it was recognized by the early church based on apostolicity, consistency with Scripture, and widespread use. Study the process by which God''s Word was confirmed, why books like the Gospel of Thomas were excluded, and what gives us confidence in the canon we have today.',
   'Apologetics', ARRAY['canon', 'bible', 'church history', 'reliability'], 295, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- STEP 3: INSERT Hi/ML translations for b0200000..001-005
-- (Historical Reliability content, copied from 20260321000002)
-- -------------------------------------------------------
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES

  ('b0200000-e29b-41d4-a716-446655440001', 'hi',
   'नए नियम के प्राचीन लेखन प्रमाण',
   'नया नियम इतिहास में सबसे अधिक प्रमाणित प्राचीन दस्तावेज़ है — 5,800 से अधिक यूनानी हस्तलिपियाँ, साथ में 10,000 से अधिक लैटिन और अन्य भाषाओं की हस्तलिपियाँ। तुलना के लिए: होमर की इलियड की केवल 643 हस्तलिपियाँ हैं, फिर भी इसकी ऐतिहासिकता पर कोई सवाल नहीं करता। पांडुलिपियाँ घटनाओं के बहुत करीब की हैं — सबसे प्रारंभिक हस्तलिपि खंड (P52) यूहन्ना के सुसमाचार के लगभग 25-30 वर्षों के भीतर का है। टेक्सचुअल स्कॉलर्स का अनुमान है कि नए नियम का 99.5% मूल पाठ सुरक्षित है। यह अध्ययन उन लोगों के लिए है जो जानना चाहते हैं कि क्या आज की बाइबल वास्तव में वही है जो पहले लिखी गई थी।',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440001', 'ml',
   'പുതിയ നിയമ പ്രാചീന ലേഖന തെളിവ്',
   'പുതിയ നിയമം ചരിത്രത്തിലെ ഏറ്റവും നന്നായി സ്ഥിരീകരിക്കപ്പെട്ട പ്രാചീന ഗ്രന്ഥം — 5,800-ലധികം ഗ്രീക്ക് കൈ ലേഖ, 10,000-ലധികം ലത്തീൻ, ഇതര ഭാഷ ലേഖ. തട്ടേ: ഹോമർ ഇലിയഡ് 643 ലേഖ മാത്രം, എന്നിട്ടും ചരിത്ര ബോദ്ധ്യ ചോദ്യ ഇല്ല. ആദ്യ ലേഖ ഖണ്ഡം (P52) — യോഹ. സുവിശേഷം 25-30 വർഷ ഉൾ. ടെക്സ്ചൽ ഗവേഷകർ: 99.5% മൂല ലേഖ സംരക്ഷിത. ഇന്ന് ഉള്ള ബൈബിൾ ആദ്യ ലേഖ ആണ് — ഇത് അറിയാൻ ആഗ്രഹിക്കുന്നവർക്ക് ഈ പഠനം ആഴ്‌ചിക്കൽ ഉൾക്കൊള്ളും.',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440002', 'hi',
   'बाइबल की पुरातात्विक पुष्टि',
   'पिछले 150 वर्षों में पुरातत्व ने बार-बार बाइबल की ऐतिहासिक सटीकता को सिद्ध किया है — उन विवरणों की भी जिन्हें आलोचकों ने कभी काल्पनिक कहा था। हित्तियों का अस्तित्व — जिसे एक बार बाइबलीय आविष्कार कहा गया था — पुरातत्व ने 1906 में खोज कर पुष्टि की। पोन्तियुस पिलातुस के शिलालेख (1961), दाऊद के घराने का उल्लेख (1993 में टेल दान शिलालेख), और जेरिको की दीवारें — ये सब बाइबलीय अभिलेखों से मेल खाते हैं। पुरातत्व बाइबल को "सिद्ध" नहीं कर सकता, लेकिन यह अनगिनत बार यह दिखाता है कि बाइबल के लेखक वास्तविक इतिहास लिख रहे थे।',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440002', 'ml',
   'ബൈബിളിന്റെ പുരാവസ്തു തെളിവ്',
   'കഴിഞ്ഞ 150 വർഷ പുരാവസ്തു ഗവേഷണം ആവർത്തിച്ച് ബൈബിൾ ചരിത്ര കൃത്യത സ്ഥിരീകരിക്കുന്നു — ഒരു കാലം ഐതിഹ്യം എന്ന് നിരാകരിക്കപ്പെട്ടതൊക്കെ. ഹിത്ത്യർ — ഒരു കാലം ബൈബിൾ ആഖ്യാനം — 1906-ൽ കണ്ടെത്തി. പൊന്തിയൊസ് പീലാത്തൊസ് ലിഖിതം (1961), ദാവീദ് ഗൃഹ ഉദ്ദേശ്യ (1993 ടെൽ ദാൻ ലിഖിതം), യെരിക്കോ മതിൽ — ഇവ ബൈബിൾ ആഖ്യാനം ഒത്ത് ചേരുന്നു. പുരാവസ്തു ബൈബിൾ "തെളിയിക്കാൻ" ആകില്ല, പക്ഷേ ബൈബിൾ ലേഖകർ ഹൃദ ചരിത്രം ആഖ്യാനിക്കുകയായിരുന്നു — ഇത് ആവർത്തിച്ച് ദൃഷ്ടിഗോചരം.',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440003', 'hi',
   'मसीह में पूरी हुई पुराने नियम की भविष्यवाणियाँ',
   'पुराने नियम में 300 से अधिक विशिष्ट भविष्यवाणियाँ यीशु के जन्म से सदियों पहले लिखी गईं और उनके जीवन, मृत्यु और पुनरुत्थान में पूरी हुईं। बेतलहम में जन्म (मीका 5:2), कुँवारी से जन्म (यशायाह 7:14), गधे पर यरुशलेम में प्रवेश (जकर्याह 9:9), 30 चाँदी के टुकड़ों के लिए बेचा जाना (जकर्याह 11:12-13), हड्डियाँ न तोड़ी जाना (भजन 34:20) — ये सब यीशु में सटीक रूप से पूरी हुईं। किसी एक व्यक्ति द्वारा 8 भविष्यवाणियाँ संयोग से पूरी होने की संभावना 10 की घात 17 में एक है। यह बाइबल के दिव्य प्रेरणा और यीशु की मसीहाई पहचान के लिए सबसे शक्तिशाली प्रमाणों में से एक है।',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440003', 'ml',
   'ക്രിസ്തുവിൽ നിറവേറിയ പഴയ നിയമ പ്രവചനങ്ങൾ',
   'പഴയ നിയമ 300-ലധികം വ്യക്തിഗത പ്രവചനങ്ങൾ യേശുവിന്റെ ജനനത്തിന് നൂറ്റാണ്ടുകൾ മുൻ ലേഖനം — അദ്ദേഹ ജീവ-മരണ-പുനരുത്ഥ നിറ. ബേത്‌ലഹം ജനനം (മീഖ 5:2), കന്യക ജനനം (യശ. 7:14), കഴുത ജറൂ. പ്രവേശം (സെക്. 9:9), 30 വെള്ളി വഞ്ചന (സെക്. 11:12-13), അസ്ഥി ഭഞ്ജനം ഇല്ല (സങ്കീ. 34:20) — ഇവ ഒക്കെ കൃത്യ. 8 പ്രവചനം ഒരൊററ ആൾ ആകസ്മ നിറ — 10 ഘാതം 17-ൽ ഒരു. ബൈബിൾ ദൈവ നിശ്വ, യേശുവിന്റെ ക്രിസ്ത ഐഡൻ്ററ്റ — ഇതിന്റെ ഏറ്റവും ശക്ത തെളിവ്.',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440004', 'hi',
   'इतिहास में पुनरुत्थान',
   'यीशु का पुनरुत्थान मसीही विश्वास की आधारशिला है — और पौलुस ने कहा: "यदि मसीह नहीं जी उठा तो तुम्हारा विश्वास व्यर्थ है" (1 कुरिन्थियों 15:17)। पुनरुत्थान के लिए ऐतिहासिक साक्ष्य: खाली कब्र (जिसे यहूदी नेता और रोमन सैनिक कभी अस्वीकार नहीं कर पाए, केवल चोरी का आरोप लगाया), 500 से अधिक लोगों को एक साथ दर्शन (1 कुरिन्थियों 15:6), और शिष्यों का कायापलट — भयभीत और छिपे हुए लोगों का साहसी शहीद बनना। इन तथ्यों की सबसे अच्छी व्याख्या वास्तविक पुनरुत्थान है। यह अध्ययन आपको पुनरुत्थान के ऐतिहासिक प्रमाण देता है जो विश्वास को कारण पर टिकाता है।',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440004', 'ml',
   'ചരിത്ര സത്യമായ പുനരുത്ഥാനം',
   'യേശു പുനരുത്ഥ ക്രൈസ്തവ വിശ്വ ആണി കല്ല് — "ക്രിസ്തു ഉയർക്കായ്കിൽ വിശ്വ ശൂന്യ" (1 കൊ. 15:17). പുനരുത്ഥ ചരിത്ര തെളിവ്: ശൂന്യ കല്ലറ (യഹൂദ നേതൃ-റോമ ഭടൻ ഒരിക്കലും നിഷേ ആകിയില്ല — കൊ. ആരോ ആക്ക മാത്രം), 500-ലധികം ആൾ ഒരുമിച്ച് ദർശ (1 കൊ. 15:6), ഭയ-ഒളി ശിഷ്യ ധൈര്യ രക്ത സാക്ഷ ആകൽ. ഈ വസ്തുതകൾക്ക് ഏറ്റവും ഉചിത ആഖ്യ: ഹൃദ പുനരുത്ഥ. ഈ പഠനം പുനരുത്ഥ ചരിത്ര തെളിവ് — കാരണ ആധാര വിശ്വ — ഇത് ഉൾക്കൊള്ളും.',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440005', 'hi',
   'बाइबल का संग्रह कैसे बना',
   '"कैनन" शब्द का अर्थ है माप की छड़ — वे पुस्तकें जो माप की कसौटी पर खरी उतरीं। ये 66 पुस्तकें क्यों बाइबल में हैं और दूसरी नहीं? आरंभिक कलीसिया ने तीन मुख्य कसौटियों का उपयोग किया: अपोस्तलीयता (प्रत्यक्ष प्रेरित संबंध), बाइबलीय सहमति (शेष पवित्रशास्त्र से मेल), और व्यापक उपयोग (चर्चों में स्वीकृति)। अपोक्रिफा जैसी पुस्तकें इन कसौटियों पर पूरी नहीं उतरीं। यह एक बैठक में नहीं हुआ — सदियों में प्रमाण देखकर कलीसिया ने मान्यता दी। यह अध्ययन बताएगा कि यह प्रक्रिया कैसे काम की और हम आज इस पर विश्वास क्यों रख सकते हैं।',
   'Apologetics'),

  ('b0200000-e29b-41d4-a716-446655440005', 'ml',
   'ബൈബിൾ ശേഖരം എങ്ങനെ രൂപപ്പെട്ടു',
   '"കാനൺ" (Canon) ശബ്ദത്തിന്റെ അർത്ഥം അളക്കൽ ദണ്ഡ് — ആ ദണ്ഡ് ഒത്ത് ചേർന്ന 66 പുസ്തകങ്ങൾ ബൈബിളിൽ ഉൾപ്പെടുത്തി, ബാക്കി ഒഴിവ് — ഇതെന്തുകൊണ്ട്? ആദ്യ സഭ മൂന്ന് മുഖ്യ മാനദണ്ഡം ഉപയോഗിച്ചു: അപ്പൊസ്തലിക ബന്ധം, ബൈബിൾ ഐക്യം, സഭ വ്യാപക ഉപയോഗം. ആ മാനദണ്ഡം ഒത്ത് ചേർന്നില്ലാത്ത ഗ്രന്ഥം ഒഴിവ്. ഒറ്റ ഉൾ ആക്കൽ ഇല്ല — നൂറ്റാണ്ടുകൾ ആഴ ഗവേഷണം, ദൈവ ആത്മ അംഗീകാരം. ഈ പ്രക്രിയ എങ്ങനെ ഉണ്ടായി, ഇന്ന് ഇത് ആശ്രയിക്കാൻ ഒരുവൻ എന്തുകൊണ്ട് — ഈ പഠനം ഇത് ഉൾക്കൊള്ളും.',
   'Apologetics')

ON CONFLICT (topic_id, language_code) DO NOTHING;

-- -------------------------------------------------------
-- STEP 4: UPDATE Hi/ML translations for ab500000..001-005 → Hebrews content
-- (overwrite the Historical Reliability content added in 20260321000002)
-- -------------------------------------------------------
UPDATE recommended_topics_translations SET
  title       = 'इब्रानियों 1: मसीह की सर्वोच्चता',
  description = 'परमेश्वर ने अनेक समयों में और अनेक प्रकारों से भविष्यद्वक्ताओं के द्वारा बोला, परन्तु इन अन्तिम दिनों में अपने पुत्र के द्वारा बोला है — जो उसकी महिमा का प्रकाश और उसके स्वभाव की ठीक छाप है। इब्रानियों का आरम्भ मसीह की परम सर्वोच्चता की घोषणा से होता है: वह भविष्यद्वक्ताओं से ऊपर है, व्यवस्था की मध्यस्थता करने वाले स्वर्गदूतों से ऊपर है, और महामहिम परमेश्वर के दाहिने हाथ पर विराजमान है। इब्रानियों के सभी तर्क इसी नींव पर खड़े हैं — यीशु किसी भी चीज़ से श्रेष्ठ है। यह अध्ययन वह नींव स्थापित करता है जिस पर इब्रानियों का सम्पूर्ण संदेश टिका है।',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440001' AND language_code = 'hi';

UPDATE recommended_topics_translations SET
  title       = 'എബ്രായർ 1: ക്രിസ്തുവിന്റെ സർവ്വോന്നതി',
  description = 'ദൈവം പഴയ കാലങ്ങളിൽ പ്രവാചകർ വഴി പലരീതിയിൽ ബോദ്ധ്യം ചെയ്തു; ഈ അന്ത്യ-ദിനങ്ങളിൽ ദൈവ-മഹത്വ-ദ്യുതിയും ദൈവ-സ്വഭാവ-ഛായയുമായ പുത്രൻ വഴി ബോദ്ധ്യം ചെയ്തു. ക്രിസ്തുവിന്റെ സമ്പൂർണ്ണ-സർവ്വോന്നതി ഉദ്ഘോഷണ ആണ് എബ്രായർ ആദ്യ-ദൗത്യം: പ്രവാചകൻ-ഉപരി, നിയമ-ഇടനിൽ-ദൂതൻ-ഉപരി, ദൈവ-മഹത്വ-ദക്ഷ-ഭാഗ-ആസ്ഥിതൻ. ഈ ലേഖനത്തിലെ ഓരോ തർക്കവും ഈ അടിത്തറ: ക്രിസ്തു ഒക്കെ-ഉപരി — ഇത് ഉൾക്കൊള്ളൽ ഈ പഠനം ഉൾക്കൊള്ളും.',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440001' AND language_code = 'ml';

UPDATE recommended_topics_translations SET
  title       = 'इब्रानियों 2: महान उद्धार',
  description = 'इब्रानियों की पहली बड़ी चेतावनी: "ऐसे बड़े उद्धार की अनदेखी करने पर हम कैसे बचेंगे?" जो पुत्र स्वर्गदूतों से श्रेष्ठ है, वह स्वयं रक्त और मांस में सहभागी हुआ, सबके लिए मृत्यु का स्वाद चखा, और शैतान की शक्ति को नष्ट किया। चूँकि वह स्वयं परीक्षाओं में पड़ा और दुख उठाया, इसलिए वह परीक्षा में पड़े लोगों की सहायता कर सकता है। यह चेतावनी भय के लिए नहीं, बल्कि स्मरण दिलाने के लिए है — जो महान उद्धार प्राप्त हुआ है उसे हल्के में मत लो।',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440002' AND language_code = 'hi';

UPDATE recommended_topics_translations SET
  title       = 'എബ്രായർ 2: മഹത്തായ രക്ഷ',
  description = 'എബ്രായർ ആദ്യ-വലിയ-മുന്നറിയിപ്പ്: "ഇത്ര മഹത്തായ രക്ഷ അവഗണിച്ചാൽ നമ്മൾ എങ്ങനെ ഒഴിഞ്ഞ് പോകും?" ദൂതൻ-ഉപരി-പുത്രൻ ജഡ-രക്ത-ഭാഗ ആകി, ഒക്കെ-വേണ്ടി-മൃത്യ-ആസ്വദ, പിശാച്-ശക്തി-നശ. അദ്ദേഹം-സ്വ-പ്രലോഭ-ദുഖ ആകയാൽ, പ്രലോഭ-ഗ്രസ്ത-സഹായ ആകും. ഈ മുന്നറിയിപ്പ് ഭീതിക്കല്ല — ഓർമ്മ-ഉദ്ദേശം: ലഭിച്ച-മഹത്-രക്ഷ-അലസ-ഭാവ-ഒഴിക. ഈ പഠനം ഇത് ഉൾക്കൊള്ളും.',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440002' AND language_code = 'ml';

UPDATE recommended_topics_translations SET
  title       = 'इब्रानियों 3: मूसा से श्रेष्ठ यीशु',
  description = 'मूसा परमेश्वर के घर में एक सेवक के रूप में विश्वासयोग्य था; यीशु परमेश्वर के घर पर पुत्र के रूप में विश्वासयोग्य है, और यदि हम अपना विश्वास दृढ़ रखें तो हम वही घर हैं। दूसरी चेतावनी: "अपने मन को कठोर मत करो जैसा विद्रोह के समय में किया गया था।" परमेश्वर के चमत्कारों को देखने वाली पीढ़ी अविश्वास के कारण उसके विश्राम में प्रवेश नहीं कर सकी। धैर्य के साथ बने रहना उद्धार के विश्वास का पूरक नहीं है — यह उद्धार के विश्वास का वह रूप है जो समय के साथ प्रकट होता है।',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440003' AND language_code = 'hi';

UPDATE recommended_topics_translations SET
  title       = 'എബ്രായർ 3: മോശയേക്കാൾ ശ്രേഷ്ഠൻ യേശു',
  description = 'ദൈവ-ഭവനത്തിൽ ദ്രഷ്ടാ-ദൗത്യ ആയി മോശ വിശ്വസ്തൻ; ദൈവ-ഭവന-ഉടമ-പുത്രൻ ആയി യേശു വിശ്വസ്തൻ — ബോദ്ധ്യ-ദൃഢ-പാർത്ത ഭവനം നമ്മൾ. രണ്ടാം-മുന്നറിയിപ്പ്: "മത്സര-കാലം-പോൽ ഹൃദ-കഠിനം ആകരുത്." ദൈവ-അദ്ഭുത-ദൃഷ്ടി-ആ-തലമുറ, അവിശ്വ-ഹേതു-ദൈവ-വിശ്രാന്തി-പ്രവേശ-ആകിയില്ല. ദൃഢ-നിൽ — ഇത് രക്ഷ-വിശ്വ-ഉദ്ദേശ-അല്ല, ഇത് രക്ഷ-വിശ്വ-ആകൃതി-കാല-ഒഴുക്ക്. ഈ പഠനം ഇത് ഉൾക്കൊള്ളും.',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440003' AND language_code = 'ml';

UPDATE recommended_topics_translations SET
  title       = 'इब्रानियों 4: परमेश्वर के विश्राम में प्रवेश',
  description = 'विश्राम का वादा अभी भी बना हुआ है — वह विश्राम जिसमें इस्राएली अविश्वास के कारण प्रवेश नहीं कर सके, और जिसे यहोशू की विजय ने केवल आंशिक रूप से दर्शाया था। परमेश्वर का विश्राम (sabbatismos) उसके लोगों की परम विरासत है, जैसे परमेश्वर ने अपने कार्यों से विश्राम किया वैसा ही विश्राम। परमेश्वर का जीवन्त और प्रभावशाली वचन, जो किसी भी दोधारी तलवार से भी तेज है, हृदय की दशा को उसके सामने उघाड़ देता है जिसके प्रति हमें लेखा देना है।',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440004' AND language_code = 'hi';

UPDATE recommended_topics_translations SET
  title       = 'എബ്രായർ 4: ദൈവ-വിശ്രാന്തി-പ്രവേശം',
  description = 'വിശ്രാന്തി-വാഗ്ദ്ത്ത ഇന്നും നിൽക്കുന്നു — ആ വിശ്രാന്തി ഇസ്രായേൽ-ജനം അവിശ്വ-ഹേതു-പ്രവേശ-ആകിയില്ല, ജോഷ്വ-ജയ-ഭൂ-ഭാഗ-ഭാഗ്ശ-ദൃഷ്ടി-മാത്രം. ദൈവ-വിശ്രാന്തി (sabbatismos) ദൈവ-ജനം-ഉത്കൃഷ്ട-അവകാശം, ദൈവ-സ്വ-ദൗത്യ-ഒടുക്കം-പോൽ. ദൈവ-ജീവ-ശക്ത-വചനം — ഏത് ഇരു-ഖഡ്ഗ-ഉപരി-തീർഷ്ണം — ഹൃദ-ഭാവ-ദൈവ-സന്നിധ-ഉദ്ഭേദ. ഈ പഠനം ഇത് ഉൾക്കൊള്ളും.',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440004' AND language_code = 'ml';

UPDATE recommended_topics_translations SET
  title       = 'इब्रानियों 5: हमारा महान महायाजक',
  description = 'यीशु हमारा महान महायाजक है जो स्वर्गों में से होकर गुज़र गया है, और जो हमारी कमज़ोरियों में सहानुभूति कर सकता है क्योंकि वह हर बात में हमारी तरह परीक्षा में पड़ा — फिर भी पाप के बिना। उसने स्वयं को ऊँचा नहीं उठाया बल्कि परमेश्वर ने उसे मेल्कीसेदेक की तरह नियुक्त किया। यह उस मेल्कीसेदेक के तर्क का परिचय है जो अध्याय 7 में पूरी तरह विकसित किया जाएगा।',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440005' AND language_code = 'hi';

UPDATE recommended_topics_translations SET
  title       = 'എബ്രായർ 5: നമ്മുടെ മഹായാജകൻ',
  description = 'യേശു നമ്മുടെ മഹ-മഹായാജകൻ — ആകാശ-മദ്ധ്യ-കടന്ന, നമ്മ-ബല-ഹീന-സഹ-ഭൂതം, കാരണം ഓരോ-ഭാഗ-പ്രലോഭ-ഗ്രസ്ത — എന്നിട്ടും പാപ-ഇല്ല. അദ്ദേഹം-സ്വ-ഉന്നതി-ആകിയില്ല — ദൈവ-നിയോഗ, മെൽക്കീസേദക്-പ്രകാരം. ഇത് 7-ആം-അദ്ധ്യ-പൂർണ്ണ-മെൽക്കീ-തർക്ക-ആദ്യ-ആഖ്യ. ഈ പഠനം ഇത് ഉൾക്കൊള്ളും.',
  category    = 'Foundations of Faith'
WHERE topic_id = 'ab500000-e29b-41d4-a716-446655440005' AND language_code = 'ml';

-- -------------------------------------------------------
-- STEP 5: Re-link path 020 (Historical Reliability) to new b0200000 IDs
-- -------------------------------------------------------
UPDATE learning_path_topics
  SET topic_id = 'b0200000-e29b-41d4-a716-446655440001'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000020'
    AND topic_id = 'ab500000-e29b-41d4-a716-446655440001';

UPDATE learning_path_topics
  SET topic_id = 'b0200000-e29b-41d4-a716-446655440002'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000020'
    AND topic_id = 'ab500000-e29b-41d4-a716-446655440002';

UPDATE learning_path_topics
  SET topic_id = 'b0200000-e29b-41d4-a716-446655440003'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000020'
    AND topic_id = 'ab500000-e29b-41d4-a716-446655440003';

UPDATE learning_path_topics
  SET topic_id = 'b0200000-e29b-41d4-a716-446655440004'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000020'
    AND topic_id = 'ab500000-e29b-41d4-a716-446655440004';

UPDATE learning_path_topics
  SET topic_id = 'b0200000-e29b-41d4-a716-446655440005'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000020'
    AND topic_id = 'ab500000-e29b-41d4-a716-446655440005';

-- Path 029 (Big Questions) also links ab500000..004 ("The Resurrection as Historical Fact").
-- STEP 1 above updated that topic to Hebrews 4 content, so re-link path 029 to the new b0200000 ID.
UPDATE learning_path_topics
  SET topic_id = 'b0200000-e29b-41d4-a716-446655440004'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000029'
    AND topic_id = 'ab500000-e29b-41d4-a716-446655440004';

-- -------------------------------------------------------
-- VERIFICATION
-- -------------------------------------------------------
DO $$
DECLARE
  hebrews_path_id  uuid := 'aaa00000-0000-0000-0000-000000000030';
  hist_rel_path_id uuid := 'aaa00000-0000-0000-0000-000000000020';
  bad_count        int;
BEGIN
  -- Hebrews path topics 1-5 should now show Hebrews content
  SELECT COUNT(*) INTO bad_count
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
  WHERE lpt.learning_path_id = hebrews_path_id
    AND lpt.position BETWEEN 0 AND 4
    AND rt.category != 'Foundations of Faith';

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: % Hebrews path topics still have wrong category', bad_count;
  END IF;

  -- Historical Reliability path topics 1-5 should now use b0200000 IDs
  SELECT COUNT(*) INTO bad_count
  FROM learning_path_topics
  WHERE learning_path_id = hist_rel_path_id
    AND topic_id IN (
      'ab500000-e29b-41d4-a716-446655440001',
      'ab500000-e29b-41d4-a716-446655440002',
      'ab500000-e29b-41d4-a716-446655440003',
      'ab500000-e29b-41d4-a716-446655440004',
      'ab500000-e29b-41d4-a716-446655440005'
    );

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: Historical Reliability path still links % ab500000 topics', bad_count;
  END IF;

  RAISE NOTICE 'VERIFICATION PASSED: Hebrews UUID collision fixed successfully';
END $$;
