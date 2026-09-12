-- Nine New Testament letters and Revelation had no learning path.
--
-- The catalogue covered Romans through 3 John but stopped short of Colossians,
-- both Thessalonian letters, the Pastorals (1-2 Timothy, Titus), Philemon, Jude
-- and Revelation — nine of the twenty-one epistles, plus the book that closes
-- the canon. Searching for any of them returned nothing, in any language.
--
-- One path per book, one topic per chapter, matching the shape every existing
-- book path already uses: 50 XP a chapter, three days a chapter (two for books
-- over eight chapters, as Romans and Corinthians do), topic titles "Book N:
-- Theme" and descriptions opening "Read Book N." so the generator has a
-- consistent prompt. Hindi and Malayalam ship with them rather than following
-- later, because a path with no translation is invisible to a reader searching
-- in their own language.
--
-- Revelation sits under Theology; there is no prophecy category, and the
-- descriptions deliberately stay descriptive — they report what the text says
-- and note where the church has long read a symbol differently, rather than
-- settling millennial questions on a study-app card.
--
-- Idempotent: recommended_topics has no unique index on title, so its insert is
-- guarded by NOT EXISTS rather than ON CONFLICT, which would silently duplicate
-- every topic on a second apply.



-- ===== Colossians: The Supremacy of Christ (4 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('colossians-supremacy-of-christ', 'Colossians: The Supremacy of Christ', 'Written from prison to a church Paul had never visited, Colossians answers a quiet drift toward hollow philosophy and man-made rules. In four chapters Paul lifts up Christ as the image of the invisible God, the one in whom the fullness of deity dwells and in whom you are already complete. Learn to live the new life that is hidden with Christ in God.',
        'workspace_premium', '#7E22CE', 200, 12,
        'follower', 'standard', false, 42, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', 'कुलुस्सियों: मसीह की सर्वोच्चता', 'बंदीगृह से लिखी गई यह पत्री एक ऐसी कलीसिया के नाम है जहाँ पौलुस कभी गया नहीं था। वह खोखले दर्शन और मनुष्यों के बनाए नियमों की ओर बहने की चेतावनी देता है। चार अध्यायों में पौलुस मसीह को अदृश्य परमेश्वर का प्रतिरूप ठहराता है, जिसमें ईश्वरत्व की सारी परिपूर्णता वास करती है और जिसमें आप पहले से ही सम्पूर्ण हैं। सीखिए उस नए जीवन को जीना जो मसीह के साथ परमेश्वर में छिपा है।'
  FROM public.learning_paths WHERE slug = 'colossians-supremacy-of-christ'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', 'കൊലൊസ്സ്യർ: ക്രിസ്തുവിന്റെ സർവാധിപത്യം', 'താൻ ഒരിക്കലും സന്ദർശിച്ചിട്ടില്ലാത്ത ഒരു സഭയ്ക്ക് പൗലോസ് തടവിൽനിന്ന് എഴുതിയ ലേഖനമാണിത്. പൊള്ളയായ തത്ത്വജ്ഞാനത്തിലേക്കും മനുഷ്യനിർമിത ചട്ടങ്ങളിലേക്കുമുള്ള നിശ്ശബ്ദമായ വഴുതൽ അവൻ തിരുത്തുന്നു. നാല് അധ്യായങ്ങളിൽ, അദൃശ്യനായ ദൈവത്തിന്റെ പ്രതിരൂപമായി, ദൈവത്വത്തിന്റെ പൂർണത വസിക്കുന്നവനായി, നിങ്ങൾ പൂർണരായിത്തീരുന്നവനായി ക്രിസ്തുവിനെ പൗലോസ് ഉയർത്തിക്കാട്ടുന്നു. ക്രിസ്തുവിനോടുകൂടെ ദൈവത്തിൽ മറഞ്ഞിരിക്കുന്ന പുതിയ ജീവിതം ജീവിക്കാൻ പഠിക്കുക.'
  FROM public.learning_paths WHERE slug = 'colossians-supremacy-of-christ'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Colossians 1: The Image of the Invisible God', 'Read Colossians 1. Paul thanks God for the Colossians'' faith, love, and hope, and prays that they would be filled with the knowledge of God''s will. He announces that the Father has delivered them from the domain of darkness into the kingdom of his beloved Son. Christ is the image of the invisible God, firstborn over all creation, the one in whom all things hold together, head of the church, reconciling all things to himself by the blood of his cross — and reconciling you, if you continue in the faith. In him God''s mystery is revealed — Christ in you, the hope of glory.', 'Foundations of Faith', 'topic',
       ARRAY['colossians', 'christ', 'creation', 'reconciliation']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Colossians 1: The Image of the Invisible God');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'कुलुस्सियों 1: अदृश्य परमेश्वर का प्रतिरूप', 'कुलुस्सियों 1 पढ़ें। पौलुस कुलुस्से के विश्वासियों के विश्वास, प्रेम और आशा के लिये परमेश्वर का धन्यवाद करता है, और प्रार्थना करता है कि वे परमेश्वर की इच्छा की पहचान से भरपूर हो जाएँ। वह बताता है कि पिता ने उन्हें अंधकार के अधिकार से छुड़ाकर अपने प्रिय पुत्र के राज्य में पहुँचाया है। मसीह अदृश्य परमेश्वर का प्रतिरूप है, सारी सृष्टि में पहलौठा, जिसमें सब कुछ स्थिर रहता है; वह कलीसिया का सिर है और अपने क्रूस के लहू के द्वारा सब कुछ का मेल कराता है — और तुम्हारा भी, यदि तुम विश्वास में बने रहो। उसी में परमेश्वर का भेद प्रगट हुआ है — मसीह तुम में, महिमा की आशा।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Colossians 1: The Image of the Invisible God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'കൊലൊസ്സ്യർ 1: അദൃശ്യദൈവത്തിന്റെ പ്രതിരൂപം', 'കൊലൊസ്സ്യർ 1 വായിക്കുക. കൊലൊസ്സ്യരുടെ വിശ്വാസത്തിനും സ്നേഹത്തിനും പ്രത്യാശയ്ക്കുമായി പൗലോസ് ദൈവത്തിന് നന്ദി പറയുന്നു; ദൈവഹിതത്തിന്റെ പരിജ്ഞാനത്താൽ അവർ നിറയേണ്ടതിന് പ്രാർഥിക്കുന്നു. ഇരുട്ടിന്റെ അധികാരത്തിൽനിന്ന് പിതാവ് അവരെ വിടുവിച്ച് തന്റെ പ്രിയപുത്രന്റെ രാജ്യത്തിലേക്ക് ആക്കിയെന്ന് അവൻ പ്രഖ്യാപിക്കുന്നു. ക്രിസ്തു അദൃശ്യദൈവത്തിന്റെ പ്രതിരൂപം, സർവസൃഷ്ടിക്കും ആദ്യജാതൻ, സകലവും അവനിൽ നിലനിൽക്കുന്നു; അവൻ സഭയുടെ ശിരസ്സും, തന്റെ ക്രൂശിലെ രക്തത്താൽ സകലത്തെയും നിരപ്പിക്കുന്നവനുമാണ് — നിങ്ങൾ വിശ്വാസത്തിൽ നിലനിന്നാൽ നിങ്ങളെയും അവൻ നിരപ്പിക്കുന്നു. അവനിൽ ദൈവത്തിന്റെ മർമം വെളിപ്പെട്ടു — നിങ്ങളിൽ ക്രിസ്തു, തേജസ്സിന്റെ പ്രത്യാശ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Colossians 1: The Image of the Invisible God'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'colossians-supremacy-of-christ' AND rt.title = 'Colossians 1: The Image of the Invisible God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Colossians 2: Complete in Christ', 'Read Colossians 2. Paul warns the church not to be taken captive by plausible arguments, empty philosophy, or human tradition, because in Christ all the treasures of wisdom and knowledge are hidden and the whole fullness of deity dwells bodily. You have been buried with him and raised with him. God cancelled the record of debt that stood against you, nailing it to the cross, and disarmed the powers. So let no one judge you over food, festivals, or man-made regulations; those rules are only a shadow, and the substance belongs to Christ.', 'Foundations of Faith', 'topic',
       ARRAY['colossians', 'fullness', 'philosophy', 'freedom']::text[], true, 50, 1
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Colossians 2: Complete in Christ');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'कुलुस्सियों 2: मसीह में सम्पूर्ण', 'कुलुस्सियों 2 पढ़ें। पौलुस चेतावनी देता है कि कोई भी लुभावने तर्कों, खोखले दर्शन या मनुष्यों की परम्पराओं से तुम्हें बंदी न बना ले, क्योंकि मसीह में ज्ञान और बुद्धि के सारे भण्डार छिपे हैं और ईश्वरत्व की सारी परिपूर्णता देह धारण करके वास करती है। तुम उसके साथ गाड़े गए और उसी के साथ जिलाए भी गए। परमेश्वर ने तुम्हारे विरुद्ध लिखे ऋण-पत्र को मिटाकर क्रूस पर कील से जड़ दिया और प्रधानताओं को निःशस्त्र कर दिया। इसलिये भोजन, पर्वों या मनुष्यों के बनाए नियमों के विषय कोई तुम पर दोष न लगाए; वे केवल छाया हैं, पर वास्तविकता मसीह है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Colossians 2: Complete in Christ'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'കൊലൊസ്സ്യർ 2: ക്രിസ്തുവിൽ പൂർണർ', 'കൊലൊസ്സ്യർ 2 വായിക്കുക. വശീകരിക്കുന്ന വാദങ്ങളാലും പൊള്ളയായ തത്ത്വജ്ഞാനത്താലും മാനുഷിക പാരമ്പര്യത്താലും ആരും നിങ്ങളെ കീഴ്പ്പെടുത്തരുതെന്ന് പൗലോസ് മുന്നറിയിപ്പു നൽകുന്നു; എന്തെന്നാൽ ജ്ഞാനത്തിന്റെയും അറിവിന്റെയും നിക്ഷേപങ്ങളെല്ലാം ക്രിസ്തുവിൽ മറഞ്ഞിരിക്കുന്നു, ദൈവത്വത്തിന്റെ പൂർണത ശരീരമായി അവനിൽ വസിക്കുന്നു. നിങ്ങൾ അവനോടുകൂടെ അടക്കപ്പെട്ടു, അവനോടുകൂടെ ഉയിർത്തെഴുന്നേൽപ്പിക്കപ്പെട്ടു. നിങ്ങൾക്കെതിരായ കടപ്പത്രം ദൈവം മായിച്ച് ക്രൂശിൽ തറച്ചു, വാഴ്ചകളെ നിരായുധരാക്കി. അതുകൊണ്ട് ഭക്ഷണം, ഉത്സവങ്ങൾ, മനുഷ്യനിർമിത ചട്ടങ്ങൾ എന്നിവയുടെ പേരിൽ ആരും നിങ്ങളെ വിധിക്കരുത്; അവ നിഴൽ മാത്രം, സാരാംശം ക്രിസ്തുവത്രേ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Colossians 2: Complete in Christ'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 1, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'colossians-supremacy-of-christ' AND rt.title = 'Colossians 2: Complete in Christ'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Colossians 3: Hidden with Christ in God', 'Read Colossians 3. Since you have been raised with Christ, seek the things above, where he is seated at God''s right hand, for your life is hidden with Christ in God. Put to death sexual immorality, greed, anger, slander, and lying, and put on the new self: compassion, kindness, humility, meekness, patience, forgiving as the Lord forgave you, with love binding it all together. Let the peace and the word of Christ rule and dwell richly among you. Then wives, husbands, children, fathers, and servants are told to do everything for the Lord.', 'Foundations of Faith', 'topic',
       ARRAY['colossians', 'new-life', 'holiness', 'household']::text[], true, 50, 2
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Colossians 3: Hidden with Christ in God');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'कुलुस्सियों 3: मसीह के साथ परमेश्वर में छिपा जीवन', 'कुलुस्सियों 3 पढ़ें। जब तुम मसीह के साथ जिलाए गए हो, तो ऊपर की बातों की खोज करो, जहाँ मसीह परमेश्वर के दाहिने बैठा है, क्योंकि तुम्हारा जीवन मसीह के साथ परमेश्वर में छिपा हुआ है। व्यभिचार, लोभ, क्रोध, निन्दा और झूठ को मार डालो, और नए मनुष्यत्व को पहन लो — करुणा, कृपा, दीनता, नम्रता, धीरज, और जैसे प्रभु ने तुम्हें क्षमा किया वैसे ही क्षमा करना; और इन सब के ऊपर प्रेम, जो सब को जोड़ता है। मसीह की शान्ति और उसका वचन तुम में राज्य करे और बहुतायत से बसे। फिर पत्नियाँ, पति, बच्चे, पिता और सेवक — सब प्रभु के लिये सब कुछ करें।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Colossians 3: Hidden with Christ in God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'കൊലൊസ്സ്യർ 3: ക്രിസ്തുവിനോടുകൂടെ ദൈവത്തിൽ മറഞ്ഞ ജീവിതം', 'കൊലൊസ്സ്യർ 3 വായിക്കുക. ക്രിസ്തുവിനോടുകൂടെ ഉയിർത്തെഴുന്നേറ്റതിനാൽ, ദൈവത്തിന്റെ വലത്തുഭാഗത്ത് അവൻ ഇരിക്കുന്ന ഉയരത്തിലുള്ളവ അന്വേഷിക്കുക; നിങ്ങളുടെ ജീവൻ ക്രിസ്തുവിനോടുകൂടെ ദൈവത്തിൽ മറഞ്ഞിരിക്കുന്നു. പരസംഗം, അത്യാഗ്രഹം, കോപം, ദൂഷണം, ഭോഷ്ക് എന്നിവ മരിപ്പിച്ച്, പുതിയ മനുഷ്യനെ ധരിക്കുക — മനസ്സലിവ്, ദയ, താഴ്മ, സൗമ്യത, ദീർഘക്ഷമ, കർത്താവ് ക്ഷമിച്ചതുപോലെ ക്ഷമിക്കൽ; എല്ലാറ്റിനും മീതെ ഐക്യത്തിന്റെ ബന്ധമായ സ്നേഹം. ക്രിസ്തുവിന്റെ സമാധാനം ഭരിക്കട്ടെ, അവന്റെ വചനം സമൃദ്ധമായി വസിക്കട്ടെ. പിന്നെ ഭാര്യമാരും ഭർത്താക്കന്മാരും മക്കളും പിതാക്കന്മാരും ദാസന്മാരും സകലവും കർത്താവിനായി ചെയ്യണം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Colossians 3: Hidden with Christ in God'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 2, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'colossians-supremacy-of-christ' AND rt.title = 'Colossians 3: Hidden with Christ in God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Colossians 4: Prayer, Wisdom, and Faithful Friends', 'Read Colossians 4. Masters are told to treat their servants justly, knowing they too have a Master in heaven. Paul urges the church to continue steadfastly in prayer, watchful and thankful, and to pray that God would open a door for the word. Walk in wisdom toward outsiders, making the best use of the time, with speech that is gracious and seasoned with salt. He closes with greetings from Tychicus, Onesimus, Mark, Epaphras who wrestles in prayer for them, and Luke, and a charge to Archippus to fulfil his ministry.', 'Foundations of Faith', 'topic',
       ARRAY['colossians', 'prayer', 'witness', 'fellowship']::text[], true, 50, 3
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Colossians 4: Prayer, Wisdom, and Faithful Friends');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'कुलुस्सियों 4: प्रार्थना, बुद्धि और विश्वासयोग्य साथी', 'कुलुस्सियों 4 पढ़ें। स्वामियों से कहा गया है कि वे अपने दासों के साथ न्याय और उचित व्यवहार करें, यह जानकर कि स्वर्ग में उनका भी एक स्वामी है। पौलुस कलीसिया को उत्साह देता है कि वे प्रार्थना में लगे रहें, जागते और धन्यवाद करते हुए, और यह प्रार्थना करें कि परमेश्वर वचन के लिये द्वार खोले। बाहरवालों के साथ बुद्धिमानी से चलो, समय का सदुपयोग करते हुए, और तुम्हारी बातचीत अनुग्रह से भरी और नमक से स्वादिष्ट हो। अन्त में वह तुखिकुस, उनेसिमुस, मरकुस, प्रार्थना में जूझनेवाले इपफ्रास और लूका की ओर से नमस्कार भेजता है, और अरखिप्पुस को अपनी सेवा पूरी करने का आदेश देता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Colossians 4: Prayer, Wisdom, and Faithful Friends'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'കൊലൊസ്സ്യർ 4: പ്രാർഥന, ജ്ഞാനം, വിശ്വസ്ത സഹകാരികൾ', 'കൊലൊസ്സ്യർ 4 വായിക്കുക. യജമാനന്മാർ തങ്ങളുടെ ദാസന്മാരോട് നീതിയോടും ന്യായത്തോടുംകൂടെ പെരുമാറണം; സ്വർഗത്തിൽ അവർക്കും ഒരു യജമാനനുണ്ടല്ലോ. ഉണർന്നും നന്ദിയോടുംകൂടെ പ്രാർഥനയിൽ ഉറ്റിരിക്കാനും, വചനത്തിന് ദൈവം ഒരു വാതിൽ തുറക്കേണ്ടതിന് പ്രാർഥിക്കാനും പൗലോസ് ആഹ്വാനം ചെയ്യുന്നു. പുറത്തുള്ളവരോട് ജ്ഞാനത്തോടെ നടക്കുക, സമയം തക്കത്തിൽ ഉപയോഗിക്കുക, നിങ്ങളുടെ വാക്ക് കൃപയുള്ളതും ഉപ്പിനാൽ രുചിയുള്ളതും ആയിരിക്കട്ടെ. തിഹിക്കൊസ്, ഒനേസിമൊസ്, മർക്കൊസ്, അവർക്കുവേണ്ടി പ്രാർഥനയിൽ പോരാടുന്ന എപ്പഫ്രാസ്, ലൂക്കൊസ് എന്നിവരുടെ വന്ദനത്തോടെയും, ശുശ്രൂഷ നിവർത്തിക്കാൻ അർഹിപ്പൊസിനുള്ള ആഹ്വാനത്തോടെയും അവൻ ഉപസംഹരിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Colossians 4: Prayer, Wisdom, and Faithful Friends'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 3, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'colossians-supremacy-of-christ' AND rt.title = 'Colossians 4: Prayer, Wisdom, and Faithful Friends'
ON CONFLICT DO NOTHING;

-- ===== 1 Thessalonians: Living Ready for Christ's Return (5 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('1-thessalonians-living-ready', '1 Thessalonians: Living Ready for Christ''s Return', 'Paul wrote to a young church in Thessalonica only months after it was born, while persecution was still fresh. In five chapters he pours out pastoral affection, urges a life that pleases God, calls for sexual purity, and comforts those grieving believers who have died with the promise of Christ''s return. Learn to live awake, holy, and full of hope.',
        'visibility', '#0891B2', 250, 15,
        'follower', 'standard', false, 43, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', '1 थिस्सलुनीकियों: मसीह के आगमन के लिए तैयार जीवन', 'थिस्सलुनीके की कलीसिया के जन्म के कुछ ही महीनों बाद, जब सताव अभी ताज़ा था, पौलुस ने यह पत्र लिखा। पाँच अध्यायों में वह अपना पिता-सा स्नेह उंडेलता है, परमेश्वर को प्रसन्न करने वाले जीवन का आग्रह करता है, पवित्रता के लिए बुलाता है, और जिनके प्रियजन मसीह में सो गए हैं उन्हें प्रभु के आगमन की आशा से सांत्वना देता है। जागते हुए, पवित्रता और आशा से भरकर जीना सीखें।'
  FROM public.learning_paths WHERE slug = '1-thessalonians-living-ready'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', '1 തെസ്സലൊനീക്യർ: ക്രിസ്തുവിന്റെ വരവിനായി ഒരുങ്ങിയ ജീവിതം', 'തെസ്സലൊനീക്യയിലെ സഭ പിറന്ന് ഏതാനും മാസങ്ങൾക്കകം, പീഡനം ഇനിയും കടുത്തിരിക്കെ, പൗലൊസ് ഈ ലേഖനം എഴുതി. അഞ്ച് അധ്യായങ്ങളിൽ അവൻ തന്റെ ഇടയസ്നേഹം പകരുന്നു, ദൈവത്തെ പ്രസാദിപ്പിക്കുന്ന ജീവിതത്തിലേക്കു പ്രേരിപ്പിക്കുന്നു, വിശുദ്ധിയിലേക്കു വിളിക്കുന്നു, ക്രിസ്തുവിൽ നിദ്രപ്രാപിച്ചവരെ ഓർത്തു ദുഃഖിക്കുന്നവരെ കർത്താവിന്റെ വരവിന്റെ പ്രത്യാശയാൽ ആശ്വസിപ്പിക്കുന്നു. ഉണർന്നും വിശുദ്ധിയോടും പ്രത്യാശ നിറഞ്ഞും ജീവിക്കാൻ പഠിക്കുക.'
  FROM public.learning_paths WHERE slug = '1-thessalonians-living-ready'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Thessalonians 1: Turned to God, Waiting for His Son', 'Read 1 Thessalonians 1. Paul, Silvanus and Timothy greet a young church and thank God for their work of faith, labour of love and steadfastness of hope. The gospel came to them not in word only but in power and in the Holy Spirit, and they received it with joy even in much affliction. They turned from idols to serve the living and true God and to wait for his Son from heaven, Jesus who rescues us from the coming wrath. Their faith became an example everywhere.', 'Foundations of Faith', 'topic',
       ARRAY['1 thessalonians', 'faith', 'hope', 'conversion']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Thessalonians 1: Turned to God, Waiting for His Son');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 थिस्सलुनीकियों 1: मूर्तियों से फिरकर, पुत्र की प्रतीक्षा में', '1 थिस्सलुनीकियों 1 पढ़ें। पौलुस, सिलवानुस और तीमुथियुस इस नई कलीसिया को नमस्कार करते हैं और उनके विश्वास के काम, प्रेम के परिश्रम और आशा की धीरता के लिए परमेश्वर का धन्यवाद करते हैं। सुसमाचार उनके पास केवल वचन में नहीं, परन्तु सामर्थ्य और पवित्र आत्मा में आया, और उन्होंने बड़े क्लेश में भी उसे आनन्द से ग्रहण किया। वे मूर्तियों से फिरकर जीवित और सच्चे परमेश्वर की सेवा करने लगे, और स्वर्ग से उसके पुत्र यीशु की बाट जोहने लगे, जो हमें आनेवाले क्रोध से बचाता है। उनका विश्वास सब जगह आदर्श बन गया।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 1: Turned to God, Waiting for His Son'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തെസ്സലൊനീക്യർ 1: വിഗ്രഹങ്ങളിൽനിന്നു തിരിഞ്ഞ്, പുത്രനെ കാത്തിരിക്കുന്നു', '1 തെസ്സലൊനീക്യർ 1 വായിക്കുക. പൗലൊസും സില്വാനൊസും തിമൊഥെയൊസും ഈ യുവസഭയെ വന്ദിക്കുകയും അവരുടെ വിശ്വാസത്തിന്റെ പ്രവൃത്തി, സ്നേഹത്തിന്റെ പ്രയത്നം, പ്രത്യാശയുടെ സ്ഥിരത എന്നിവയ്ക്കായി ദൈവത്തിനു നന്ദി പറയുകയും ചെയ്യുന്നു. സുവിശേഷം അവരുടെ അടുക്കൽ വചനമായി മാത്രമല്ല, ശക്തിയോടും പരിശുദ്ധാത്മാവോടുംകൂടെ വന്നു; വലിയ കഷ്ടത്തിലും അവർ അതു സന്തോഷത്തോടെ കൈക്കൊണ്ടു. വിഗ്രഹങ്ങളെ വിട്ടു ജീവനുള്ള സത്യദൈവത്തെ സേവിപ്പാനും വരുവാനുള്ള കോപത്തിൽനിന്നു നമ്മെ വിടുവിക്കുന്ന അവന്റെ പുത്രനായ യേശുവിനെ സ്വർഗത്തിൽനിന്നു കാത്തിരിപ്പാനും അവർ തിരിഞ്ഞു. അവരുടെ വിശ്വാസം എല്ലായിടത്തും മാതൃകയായി.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 1: Turned to God, Waiting for His Son'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-thessalonians-living-ready' AND rt.title = '1 Thessalonians 1: Turned to God, Waiting for His Son'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Thessalonians 2: A Gentle Apostle, a Genuine Gospel', 'Read 1 Thessalonians 2. Paul recalls how he came to them after suffering in Philippi, preaching not to please people or to profit from them, but as one entrusted with the gospel by God. He was gentle among them like a nursing mother and exhorted each one like a father, working night and day so as not to burden anyone. They received his message as the word of God, which it truly is, and then suffered from their own countrymen. Paul longs to return; they are his joy and crown when Christ comes.', 'Foundations of Faith', 'topic',
       ARRAY['1 thessalonians', 'ministry', 'integrity', 'affection']::text[], true, 50, 1
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Thessalonians 2: A Gentle Apostle, a Genuine Gospel');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 थिस्सलुनीकियों 2: कोमल प्रेरित, सच्चा सुसमाचार', '1 थिस्सलुनीकियों 2 पढ़ें। पौलुस स्मरण कराता है कि फिलिप्पी में दुख उठाने के बाद वह उनके पास आया, और मनुष्यों को प्रसन्न करने या उनसे लाभ उठाने के लिए नहीं, परन्तु परमेश्वर के सौंपे हुए सुसमाचार के भण्डारी के समान प्रचार किया। वह उनके बीच दूध पिलानेवाली माता के समान कोमल रहा और पिता के समान हर एक को समझाता रहा, और किसी पर बोझ न डालने के लिए रात-दिन परिश्रम करता रहा। उन्होंने उसका संदेश मनुष्यों का नहीं, परन्तु परमेश्वर का वचन जानकर ग्रहण किया, और फिर अपने ही देशवासियों से दुख सहा। पौलुस लौटने को तरसता है; मसीह के आगमन पर वे ही उसका आनन्द और मुकुट हैं।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 2: A Gentle Apostle, a Genuine Gospel'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തെസ്സലൊനീക്യർ 2: സൗമ്യനായ അപ്പൊസ്തലൻ, നിർമ്മലമായ സുവിശേഷം', '1 തെസ്സലൊനീക്യർ 2 വായിക്കുക. ഫിലിപ്പിയിൽ കഷ്ടം സഹിച്ചശേഷം താൻ അവരുടെ അടുക്കൽ വന്നത് പൗലൊസ് ഓർമ്മിപ്പിക്കുന്നു; മനുഷ്യരെ പ്രസാദിപ്പിക്കാനോ അവരിൽനിന്നു ലാഭം നേടാനോ അല്ല, ദൈവം ഭരമേല്പിച്ച സുവിശേഷത്തിന്റെ കാര്യസ്ഥനായിട്ടത്രേ അവൻ പ്രസംഗിച്ചത്. മുലയൂട്ടുന്ന അമ്മയെപ്പോലെ അവൻ അവരുടെ ഇടയിൽ സൗമ്യനായിരുന്നു, പിതാവിനെപ്പോലെ ഓരോരുത്തരെയും പ്രബോധിപ്പിച്ചു, ആർക്കും ഭാരമാകാതിരിപ്പാൻ രാപകൽ അധ്വാനിച്ചു. അവന്റെ വചനം മനുഷ്യവചനമായിട്ടല്ല, ദൈവവചനമായിട്ടുതന്നെ അവർ കൈക്കൊണ്ടു; പിന്നീടു സ്വന്തം നാട്ടുകാരാൽ കഷ്ടം സഹിച്ചു. മടങ്ങിവരാൻ പൗലൊസ് വാഞ്ഛിക്കുന്നു; ക്രിസ്തുവിന്റെ വരവിൽ അവരാണ് അവന്റെ സന്തോഷവും കിരീടവും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 2: A Gentle Apostle, a Genuine Gospel'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 1, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-thessalonians-living-ready' AND rt.title = '1 Thessalonians 2: A Gentle Apostle, a Genuine Gospel'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Thessalonians 3: Strengthened in Affliction', 'Read 1 Thessalonians 3. Unable to bear the separation any longer, Paul sent Timothy to strengthen the church and to keep anyone from being shaken by the afflictions they faced. He reminds them that such trials are the portion of believers and that he had warned them in advance. Timothy returned with good news of their faith and love, and Paul was comforted. He prays that he may see them again, that the Lord would make their love abound, and that their hearts would be established blameless in holiness at Christ''s coming.', 'Foundations of Faith', 'topic',
       ARRAY['1 thessalonians', 'affliction', 'perseverance', 'prayer']::text[], true, 50, 2
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Thessalonians 3: Strengthened in Affliction');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 थिस्सलुनीकियों 3: क्लेश में दृढ़ किए गए', '1 थिस्सलुनीकियों 3 पढ़ें। जब पौलुस उनसे अलग रहना और न सह सका, तो उसने तीमुथियुस को भेजा कि वह कलीसिया को दृढ़ करे और कोई भी इन क्लेशों से डगमगा न जाए। वह स्मरण कराता है कि ऐसे दुख विश्वासियों के भाग हैं, और उसने पहले ही उन्हें इसकी चेतावनी दी थी। तीमुथियुस उनके विश्वास और प्रेम का सुसमाचार लेकर लौटा, और पौलुस को शान्ति मिली। वह प्रार्थना करता है कि वह उन्हें फिर देख सके, प्रभु उनका प्रेम बढ़ाए, और मसीह के आगमन पर उनके मन पवित्रता में निर्दोष ठहरें।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 3: Strengthened in Affliction'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തെസ്സലൊനീക്യർ 3: കഷ്ടതയിൽ ഉറപ്പിക്കപ്പെട്ടവർ', '1 തെസ്സലൊനീക്യർ 3 വായിക്കുക. വേർപാടു സഹിപ്പാൻ കഴിയാതെ, സഭയെ ഉറപ്പിക്കുവാനും അവർ നേരിട്ട കഷ്ടങ്ങളാൽ ആരും ഇളകിപ്പോകാതിരിപ്പാനും പൗലൊസ് തിമൊഥെയൊസിനെ അയച്ചു. ഇത്തരം കഷ്ടങ്ങൾ വിശ്വാസികളുടെ ഓഹരിയാണെന്നും താൻ മുൻകൂട്ടി അതു പറഞ്ഞിരുന്നു എന്നും അവൻ ഓർമ്മിപ്പിക്കുന്നു. അവരുടെ വിശ്വാസത്തെയും സ്നേഹത്തെയുംകുറിച്ചുള്ള നല്ല വാർത്തയുമായി തിമൊഥെയൊസ് മടങ്ങിവന്നു; പൗലൊസ് ആശ്വാസം പ്രാപിച്ചു. അവരെ വീണ്ടും കാണ്മാനും, കർത്താവ് അവരുടെ സ്നേഹം വർദ്ധിപ്പിക്കുവാനും, ക്രിസ്തുവിന്റെ വരവിൽ അവരുടെ ഹൃദയങ്ങൾ വിശുദ്ധിയിൽ അനിന്ദ്യമായി ഉറയ്ക്കുവാനും അവൻ പ്രാർത്ഥിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 3: Strengthened in Affliction'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 2, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-thessalonians-living-ready' AND rt.title = '1 Thessalonians 3: Strengthened in Affliction'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Thessalonians 4: Please God, and Grieve with Hope', 'Read 1 Thessalonians 4. Paul urges them to keep growing in the life that pleases God. God''s will is their sanctification: to abstain from sexual immorality, to control the body in holiness and honour rather than in passion, and never to wrong a brother in this matter. They are to love one another more and more, live quietly, mind their own affairs and work with their hands. Then he comforts the grieving: the Lord himself will descend, the dead in Christ will rise first, and all will be with him forever.', 'Foundations of Faith', 'topic',
       ARRAY['1 thessalonians', 'holiness', 'purity', 'resurrection', 'hope']::text[], true, 50, 3
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Thessalonians 4: Please God, and Grieve with Hope');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 थिस्सलुनीकियों 4: परमेश्वर को प्रसन्न करो, और आशा के साथ शोक करो', '1 थिस्सलुनीकियों 4 पढ़ें। पौलुस उन्हें ऐसे जीवन में और अधिक बढ़ने को कहता है जो परमेश्वर को भाता है। परमेश्वर की इच्छा उनका पवित्रीकरण है: व्यभिचार से दूर रहें, अपने शरीर को अभिलाषा में नहीं परन्तु पवित्रता और आदर में वश में रखें, और इस बात में किसी भाई के साथ अन्याय न करें। वे एक दूसरे से और अधिक प्रेम करें, शान्ति से रहें, अपने ही काम में लगे रहें और अपने हाथों से परिश्रम करें। फिर वह शोक करनेवालों को सांत्वना देता है: प्रभु स्वयं उतरेगा, मसीह में मरे हुए पहले जी उठेंगे, और सब सदा प्रभु के साथ रहेंगे।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 4: Please God, and Grieve with Hope'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തെസ്സലൊനീക്യർ 4: ദൈവത്തെ പ്രസാദിപ്പിക്കുക, പ്രത്യാശയോടെ ദുഃഖിക്കുക', '1 തെസ്സലൊനീക്യർ 4 വായിക്കുക. ദൈവത്തെ പ്രസാദിപ്പിക്കുന്ന ജീവിതത്തിൽ അധികമധികം വളരുവാൻ പൗലൊസ് പ്രബോധിപ്പിക്കുന്നു. അവരുടെ വിശുദ്ധീകരണമത്രേ ദൈവഹിതം: ദുർന്നടപ്പു വിട്ടൊഴിയുക, മോഹത്തിലല്ല വിശുദ്ധിയിലും മാനത്തിലും സ്വന്ത ശരീരത്തെ അടക്കുക, ഈ കാര്യത്തിൽ സഹോദരനോട് അന്യായം ചെയ്യാതിരിക്കുക. അവർ അന്യോന്യം അധികമധികം സ്നേഹിക്കണം, സാവധാനമായി ജീവിക്കണം, സ്വന്തകാര്യം നോക്കി സ്വന്തകൈകൊണ്ടു വേല ചെയ്യണം. പിന്നെ അവൻ ദുഃഖിക്കുന്നവരെ ആശ്വസിപ്പിക്കുന്നു: കർത്താവുതന്നെ ഇറങ്ങിവരും, ക്രിസ്തുവിൽ മരിച്ചവർ ആദ്യം ഉയിർത്തെഴുന്നേല്ക്കും, എല്ലാവരും എന്നേക്കും കർത്താവിനോടുകൂടെ ഇരിക്കും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 4: Please God, and Grieve with Hope'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 3, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-thessalonians-living-ready' AND rt.title = '1 Thessalonians 4: Please God, and Grieve with Hope'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Thessalonians 5: Children of the Day, Awake and Sober', 'Read 1 Thessalonians 5. The day of the Lord comes like a thief in the night, but you are children of light and of the day, so stay awake and sober, putting on faith and love as a breastplate and the hope of salvation as a helmet. God has not destined you for wrath but to obtain salvation through Jesus, who died for you. Paul closes with brief commands: honour your leaders, warn the idle, help the weak, rejoice always, pray constantly, give thanks, test everything and hold fast what is good.', 'Foundations of Faith', 'topic',
       ARRAY['1 thessalonians', 'day of the lord', 'watchfulness', 'sanctification']::text[], true, 50, 4
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Thessalonians 5: Children of the Day, Awake and Sober');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 थिस्सलुनीकियों 5: दिन की सन्तान, जागते और सचेत', '1 थिस्सलुनीकियों 5 पढ़ें। प्रभु का दिन रात के चोर के समान आता है, परन्तु तुम ज्योति और दिन की सन्तान हो; इसलिए जागते और सचेत रहो, विश्वास और प्रेम की झिलम और उद्धार की आशा का टोप पहन लो। परमेश्वर ने तुम्हें क्रोध के लिए नहीं, परन्तु यीशु के द्वारा उद्धार पाने के लिए ठहराया, जो तुम्हारे लिए मरा। पौलुस छोटे-छोटे आदेशों के साथ पत्र समाप्त करता है: अगुवों का आदर करो, आलसियों को चिताओ, निर्बलों को सम्भालो, सदा आनन्दित रहो, निरन्तर प्रार्थना करो, धन्यवाद दो, सब बातों को परखो और भली बात को थामे रहो।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 5: Children of the Day, Awake and Sober'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തെസ്സലൊനീക്യർ 5: പകലിന്റെ മക്കൾ, ഉണർന്നും സുബോധത്തോടും', '1 തെസ്സലൊനീക്യർ 5 വായിക്കുക. കർത്താവിന്റെ ദിവസം രാത്രിയിലെ കള്ളനെപ്പോലെ വരുന്നു; എന്നാൽ നിങ്ങൾ വെളിച്ചത്തിന്റെയും പകലിന്റെയും മക്കളാകുന്നു. അതുകൊണ്ടു ഉണർന്നും സുബോധത്തോടും ഇരിപ്പിൻ; വിശ്വാസവും സ്നേഹവും കവചമായും രക്ഷയുടെ പ്രത്യാശ ശിരസ്ത്രമായും ധരിപ്പിൻ. ദൈവം നമ്മെ കോപത്തിനല്ല, നമുക്കുവേണ്ടി മരിച്ച യേശുവിലൂടെ രക്ഷ പ്രാപിപ്പാനത്രേ നിയമിച്ചത്. ചുരുക്കമായ കല്പനകളോടെ പൗലൊസ് അവസാനിപ്പിക്കുന്നു: നായകന്മാരെ മാനിപ്പിൻ, മടിയന്മാരെ ബുദ്ധിയുപദേശിപ്പിൻ, ബലഹീനരെ താങ്ങുവിൻ, എപ്പോഴും സന്തോഷിപ്പിൻ, ഇടവിടാതെ പ്രാർത്ഥിപ്പിൻ, സ്തോത്രം ചെയ്‌വിൻ, സകലവും ശോധന ചെയ്തു നല്ലതു മുറുകെ പിടിപ്പിൻ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Thessalonians 5: Children of the Day, Awake and Sober'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 4, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-thessalonians-living-ready' AND rt.title = '1 Thessalonians 5: Children of the Day, Awake and Sober'
ON CONFLICT DO NOTHING;

-- ===== 2 Thessalonians: Standing Firm Until He Comes (3 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('2-thessalonians-standing-firm', '2 Thessalonians: Standing Firm Until He Comes', 'Written soon after his first letter, Paul''s second note to Thessalonica steadies a church shaken by persecution and by a false report that the day of the Lord had already come. In three chapters he promises God''s just relief, corrects their confusion, urges them to hold fast the teaching they received, and warns against idleness. Learn to stand firm and keep doing good.',
        'anchor', '#15803D', 150, 9,
        'follower', 'standard', false, 44, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', '2 थिस्सलुनीकियों: उसके आने तक स्थिर खड़े रहो', 'अपने पहले पत्र के थोड़े ही समय बाद पौलुस ने यह दूसरा पत्र लिखा, ताकि वह कलीसिया को थामे जो सताव से और इस झूठी खबर से हिल गई थी कि प्रभु का दिन आ चुका है। तीन अध्यायों में वह परमेश्वर के न्यायपूर्ण विश्राम की प्रतिज्ञा करता है, उनकी उलझन को सुधारता है, सौंपी गई शिक्षा को थामे रहने का आग्रह करता है, और आलस्य से चेतावनी देता है। स्थिर रहना और भलाई करते रहना सीखें।'
  FROM public.learning_paths WHERE slug = '2-thessalonians-standing-firm'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', '2 തെസ്സലൊനീക്യർ: അവൻ വരുവോളം ഉറച്ചുനില്ക്കുക', 'ആദ്യലേഖനത്തിനു തൊട്ടുപിന്നാലെ എഴുതിയ ഈ രണ്ടാം ലേഖനത്തിൽ, പീഡനത്താലും കർത്താവിന്റെ ദിവസം കഴിഞ്ഞുപോയി എന്ന തെറ്റായ വാർത്തയാലും ഇളകിപ്പോയ സഭയെ പൗലൊസ് ഉറപ്പിക്കുന്നു. മൂന്ന് അധ്യായങ്ങളിൽ അവൻ ദൈവത്തിന്റെ നീതിയുള്ള ആശ്വാസം വാഗ്ദാനം ചെയ്യുന്നു, അവരുടെ ആശയക്കുഴപ്പം തിരുത്തുന്നു, ലഭിച്ച ഉപദേശം മുറുകെ പിടിപ്പാൻ പ്രബോധിപ്പിക്കുന്നു, മടിയെക്കുറിച്ചു മുന്നറിയിപ്പു നല്കുന്നു. ഉറച്ചുനില്ക്കാനും നന്മ ചെയ്തുകൊണ്ടിരിക്കാനും പഠിക്കുക.'
  FROM public.learning_paths WHERE slug = '2-thessalonians-standing-firm'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '2 Thessalonians 1: Steadfast Under Persecution', 'Read 2 Thessalonians 1. Paul thanks God that their faith is growing abundantly and their love for one another is increasing, and he boasts of their steadfastness under persecution and affliction. This endurance is evidence of God''s righteous judgement: he will repay those who afflict them and grant relief to the afflicted when the Lord Jesus is revealed from heaven with his mighty angels. Paul prays that God would make them worthy of his calling and fulfil every resolve for good, so that Christ is glorified in them.', 'Foundations of Faith', 'topic',
       ARRAY['2 thessalonians', 'persecution', 'endurance', 'judgment']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '2 Thessalonians 1: Steadfast Under Persecution');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '2 थिस्सलुनीकियों 1: सताव में स्थिर', '2 थिस्सलुनीकियों 1 पढ़ें। पौलुस परमेश्वर का धन्यवाद करता है कि उनका विश्वास बहुत बढ़ रहा है और एक दूसरे के लिए उनका प्रेम अधिक होता जा रहा है, और वह सताव तथा क्लेश में उनकी धीरता पर गर्व करता है। यह धीरज परमेश्वर के धर्मी न्याय का प्रमाण है: जब प्रभु यीशु अपने सामर्थी स्वर्गदूतों के साथ स्वर्ग से प्रगट होगा, तब वह क्लेश देनेवालों को बदला देगा और क्लेश उठानेवालों को विश्राम देगा। पौलुस प्रार्थना करता है कि परमेश्वर उन्हें अपने बुलावे के योग्य ठहराए और भलाई की हर इच्छा पूरी करे, कि मसीह उनमें महिमा पाए।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '2 Thessalonians 1: Steadfast Under Persecution'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '2 തെസ്സലൊനീക്യർ 1: പീഡനത്തിൽ ഉറച്ചുനില്ക്കുന്നവർ', '2 തെസ്സലൊനീക്യർ 1 വായിക്കുക. അവരുടെ വിശ്വാസം ഏറ്റവും വളരുന്നതിനും അന്യോന്യമുള്ള സ്നേഹം പെരുകുന്നതിനും പൗലൊസ് ദൈവത്തിനു നന്ദി പറയുന്നു; പീഡനത്തിലും കഷ്ടത്തിലുമുള്ള അവരുടെ സ്ഥിരതയിൽ അവൻ പ്രശംസിക്കുന്നു. ഈ സഹിഷ്ണുത ദൈവത്തിന്റെ നീതിയുള്ള ന്യായവിധിയുടെ അടയാളമത്രേ: കർത്താവായ യേശു തന്റെ ശക്തിയുള്ള ദൂതന്മാരോടുകൂടെ സ്വർഗത്തിൽനിന്നു വെളിപ്പെടുമ്പോൾ ഉപദ്രവിക്കുന്നവർക്കു പകരം നല്കുകയും ഉപദ്രവം സഹിക്കുന്നവർക്ക് ആശ്വാസം നല്കുകയും ചെയ്യും. ദൈവം അവരെ തന്റെ വിളിക്കു യോഗ്യരാക്കുവാനും നന്മയുടെ സകല താല്പര്യവും നിവർത്തിക്കുവാനും, അങ്ങനെ ക്രിസ്തു അവരിൽ മഹത്വപ്പെടുവാനും പൗലൊസ് പ്രാർത്ഥിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '2 Thessalonians 1: Steadfast Under Persecution'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '2-thessalonians-standing-firm' AND rt.title = '2 Thessalonians 1: Steadfast Under Persecution'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '2 Thessalonians 2: Do Not Be Quickly Shaken', 'Read 2 Thessalonians 2. Some had been shaken by a report that the day of the Lord had already come. Paul answers that it will not arrive until the rebellion comes and the man of lawlessness is revealed, who exalts himself against God and is for now held back by a restraining power. The Lord Jesus will destroy him by the breath of his mouth. Scripture does not name that restrainer or set any date, so do not speculate; instead give thanks that God chose you for salvation, and stand firm in the teaching you received.', 'Foundations of Faith', 'topic',
       ARRAY['2 thessalonians', 'day of the lord', 'truth', 'stand firm']::text[], true, 50, 1
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '2 Thessalonians 2: Do Not Be Quickly Shaken');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '2 थिस्सलुनीकियों 2: शीघ्र विचलित न हो', '2 थिस्सलुनीकियों 2 पढ़ें। कुछ लोग इस खबर से विचलित हो गए थे कि प्रभु का दिन आ चुका है। पौलुस उत्तर देता है कि जब तक धर्मत्याग न हो जाए और वह अधर्म का पुरुष प्रगट न हो, तब तक वह दिन नहीं आएगा; वह अपने आप को परमेश्वर के विरोध में ऊँचा करता है और अभी एक रोकनेवाली सामर्थ्य से रुका हुआ है। प्रभु यीशु उसे अपने मुँह की फूँक से नाश करेगा। पवित्रशास्त्र न तो उस रोकनेवाले का नाम बताता है और न कोई समय ठहराता है, इसलिए अटकलें न लगाएँ; इसके बजाय धन्यवाद करें कि परमेश्वर ने आपको उद्धार के लिए चुना, और जो शिक्षा आपको मिली उसमें स्थिर रहें।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '2 Thessalonians 2: Do Not Be Quickly Shaken'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '2 തെസ്സലൊനീക്യർ 2: വേഗത്തിൽ ഇളകിപ്പോകരുത്', '2 തെസ്സലൊനീക്യർ 2 വായിക്കുക. കർത്താവിന്റെ ദിവസം വന്നുകഴിഞ്ഞു എന്ന വാർത്തയാൽ ചിലർ ഇളകിപ്പോയിരുന്നു. വിശ്വാസത്യാഗം സംഭവിക്കയും ദൈവത്തിനെതിരെ തന്നെത്താൻ ഉയർത്തുന്ന അധർമ്മമൂർത്തി വെളിപ്പെടുകയും ചെയ്യുവോളം ആ ദിവസം വരികയില്ല എന്നു പൗലൊസ് ഉത്തരം പറയുന്നു; ഇപ്പോൾ ഒരു തടയുന്ന ശക്തി അവനെ തടഞ്ഞുനിർത്തുന്നു. കർത്താവായ യേശു തന്റെ വായിലെ ശ്വാസത്താൽ അവനെ നശിപ്പിക്കും. ആ തടയുന്നവൻ ആരെന്നു തിരുവെഴുത്തു പേരെടുത്തു പറയുന്നില്ല, സമയവും നിശ്ചയിക്കുന്നില്ല; അതുകൊണ്ട് ഊഹങ്ങൾ വേണ്ടാ. പകരം, ദൈവം നിങ്ങളെ രക്ഷയ്ക്കായി തിരഞ്ഞെടുത്തതിൽ നന്ദി പറകയും ലഭിച്ച ഉപദേശത്തിൽ ഉറച്ചുനില്ക്കയും ചെയ്‌വിൻ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '2 Thessalonians 2: Do Not Be Quickly Shaken'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 1, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '2-thessalonians-standing-firm' AND rt.title = '2 Thessalonians 2: Do Not Be Quickly Shaken'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '2 Thessalonians 3: Keep Working, Do Not Grow Weary', 'Read 2 Thessalonians 3. Paul asks for prayer that the word of the Lord may speed ahead, and assures them that the Lord is faithful and will guard them from the evil one. Then he addresses idleness: some had stopped working and become busybodies. He points to his own example of labouring night and day so as not to burden anyone, and gives the rule that whoever is unwilling to work should not eat. Such a person is to be warned as a brother, not treated as an enemy. Do not grow weary in doing good.', 'Foundations of Faith', 'topic',
       ARRAY['2 thessalonians', 'work', 'discipline', 'perseverance']::text[], true, 50, 2
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '2 Thessalonians 3: Keep Working, Do Not Grow Weary');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '2 थिस्सलुनीकियों 3: काम करते रहो, भलाई करने से न थको', '2 थिस्सलुनीकियों 3 पढ़ें। पौलुस प्रार्थना माँगता है कि प्रभु का वचन शीघ्र फैलता जाए, और उन्हें भरोसा दिलाता है कि प्रभु विश्वासयोग्य है और उन्हें उस दुष्ट से बचाए रखेगा। फिर वह आलस्य की बात करता है: कुछ लोगों ने काम करना छोड़ दिया था और दूसरों के कामों में हाथ डालने लगे थे। वह अपना उदाहरण रखता है कि किसी पर बोझ न डालने के लिए उसने रात-दिन परिश्रम किया, और यह नियम देता है कि जो काम करना नहीं चाहता वह खाए भी नहीं। ऐसे व्यक्ति को शत्रु न समझो, परन्तु भाई जानकर चिताओ। भलाई करने से मन न हटाओ।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '2 Thessalonians 3: Keep Working, Do Not Grow Weary'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '2 തെസ്സലൊനീക്യർ 3: വേല ചെയ്യുവിൻ, നന്മ ചെയ്യുന്നതിൽ മടുക്കരുത്', '2 തെസ്സലൊനീക്യർ 3 വായിക്കുക. കർത്താവിന്റെ വചനം വേഗം വ്യാപിക്കേണ്ടതിനു പ്രാർത്ഥിപ്പാൻ പൗലൊസ് അപേക്ഷിക്കുന്നു; കർത്താവ് വിശ്വസ്തനാകുന്നു, ദുഷ്ടനിൽനിന്ന് അവരെ കാത്തുകൊള്ളും എന്ന് ഉറപ്പു നല്കുന്നു. പിന്നെ അവൻ മടിയെക്കുറിച്ചു സംസാരിക്കുന്നു: ചിലർ വേല നിർത്തി അന്യരുടെ കാര്യങ്ങളിൽ ഇടപെടുന്നവരായിത്തീർന്നിരുന്നു. ആർക്കും ഭാരമാകാതിരിപ്പാൻ രാപകൽ അധ്വാനിച്ച സ്വന്തം മാതൃക അവൻ ചൂണ്ടിക്കാട്ടുന്നു; വേല ചെയ്‌വാൻ മനസ്സില്ലാത്തവൻ ഭക്ഷിക്കയുമരുത് എന്ന ചട്ടം നല്കുന്നു. അങ്ങനെയുള്ളവനെ ശത്രുവായിട്ടല്ല, സഹോദരനായി ബുദ്ധിയുപദേശിക്കണം. നന്മ ചെയ്യുന്നതിൽ മടുത്തുപോകരുത്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '2 Thessalonians 3: Keep Working, Do Not Grow Weary'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 2, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '2-thessalonians-standing-firm' AND rt.title = '2 Thessalonians 3: Keep Working, Do Not Grow Weary'
ON CONFLICT DO NOTHING;

-- ===== 1 Timothy: The Household of God (6 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('1-timothy-household-of-god', '1 Timothy: The Household of God', 'Written to a young pastor left behind in Ephesus, 1 Timothy shows how the household of God is to conduct itself. In six chapters Paul guards sound doctrine against false teachers, calls for prayer for all people, sets out qualifications for overseers and deacons, orders honour for widows and elders, and exposes the love of money. Learn to pursue godliness with contentment and fight the good fight of the faith.',
        'church', '#B91C1C', 300, 18,
        'disciple', 'standard', false, 45, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', '1 तीमुथियुस: परमेश्वर का घराना', 'इफिसुस में छोड़े गए एक युवा सेवक को लिखा गया 1 तीमुथियुस बताता है कि परमेश्वर के घराने में आचरण कैसा होना चाहिए। छह अध्यायों में पौलुस झूठे शिक्षकों के विरुद्ध खरे सिद्धांत की रक्षा करता है, सब मनुष्यों के लिए प्रार्थना का आह्वान करता है, अध्यक्षों और सेवकों की योग्यताएँ बताता है, विधवाओं और प्राचीनों के आदर की व्यवस्था देता है, और धन के लोभ को उजागर करता है। संतोष सहित भक्ति को अपनाना और विश्वास की अच्छी लड़ाई लड़ना सीखें।'
  FROM public.learning_paths WHERE slug = '1-timothy-household-of-god'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', '1 തിമൊഥെയൊസ്: ദൈവത്തിന്റെ ഭവനം', 'എഫെസൊസിൽ വിട്ടേച്ചുപോയ യുവ ശുശ്രൂഷകനു എഴുതിയ 1 തിമൊഥെയൊസ്, ദൈവഭവനത്തിൽ എങ്ങനെ പെരുമാറണമെന്നു കാണിക്കുന്നു. ആറ് അധ്യായങ്ങളിൽ പൗലൊസ് കള്ളഉപദേഷ്ടാക്കൾക്കെതിരെ സത്യോപദേശം കാത്തുസൂക്ഷിക്കുന്നു, സകല മനുഷ്യർക്കുവേണ്ടി പ്രാർത്ഥിക്കാൻ ആഹ്വാനം ചെയ്യുന്നു, അധ്യക്ഷന്മാരുടെയും ശുശ്രൂഷകന്മാരുടെയും യോഗ്യതകൾ പറയുന്നു, വിധവമാരെയും മൂപ്പന്മാരെയും ബഹുമാനിക്കാൻ പഠിപ്പിക്കുന്നു, ദ്രവ്യാഗ്രഹത്തെ വെളിപ്പെടുത്തുന്നു. സംതൃപ്തിയോടുകൂടിയ ദൈവഭക്തി പിന്തുടരാനും വിശ്വാസത്തിന്റെ നല്ല പോർ പൊരുതാനും പഠിക്കുക.'
  FROM public.learning_paths WHERE slug = '1-timothy-household-of-god'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Timothy 1: Mercy for the Foremost of Sinners', 'Read 1 Timothy 1. Paul leaves Timothy in Ephesus to charge certain people not to teach a different doctrine or devote themselves to myths and endless genealogies, which produce speculation rather than the stewardship from God that is by faith. The aim of the charge is love that issues from a pure heart, a good conscience, and a sincere faith. The law is good if used lawfully. Paul, once a blasphemer and persecutor, calls himself the foremost of sinners and a display of Christ''s perfect patience.', 'Foundations of Faith', 'topic',
       ARRAY['1 timothy', 'sound doctrine', 'mercy', 'grace', 'false teaching']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Timothy 1: Mercy for the Foremost of Sinners');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 तीमुथियुस 1: सबसे बड़े पापी पर दया', '1 तीमुथियुस 1 पढ़ें। पौलुस तीमुथियुस को इफिसुस में छोड़ता है कि वह कुछ लोगों को आज्ञा दे कि वे और प्रकार का उपदेश न दें, न कहानियों और अनन्त वंशावलियों पर मन लगाएँ, जिनसे विश्वास पर आधारित परमेश्वर की भण्डारीपन नहीं, केवल विवाद उत्पन्न होते हैं। इस आज्ञा का लक्ष्य वह प्रेम है जो शुद्ध मन, अच्छे विवेक और निष्कपट विश्वास से उपजता है। व्यवस्था भली है यदि उसका उचित उपयोग हो। पौलुस, जो पहले निन्दक और सतानेवाला था, स्वयं को सबसे बड़ा पापी और मसीह की पूरी सहनशीलता का नमूना कहता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Timothy 1: Mercy for the Foremost of Sinners'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തിമൊഥെയൊസ് 1: പാപികളിൽ ഒന്നാമനോടു കരുണ', '1 തിമൊഥെയൊസ് 1 വായിക്കുക. അന്യോപദേശം പഠിപ്പിക്കരുതെന്നും കെട്ടുകഥകളിലും അന്തമില്ലാത്ത വംശാവലികളിലും മുഴുകരുതെന്നും ചിലരോടു കല്പിക്കാൻ പൗലൊസ് തിമൊഥെയൊസിനെ എഫെസൊസിൽ വിട്ടിരിക്കുന്നു; അവ വിശ്വാസത്താലുള്ള ദൈവിക ഗൃഹവിചാരണയല്ല, തർക്കങ്ങളത്രേ ഉളവാക്കുന്നത്. ഈ കല്പനയുടെ ലക്ഷ്യം ശുദ്ധഹൃദയത്തിൽനിന്നും നല്ല മനസ്സാക്ഷിയിൽനിന്നും നിർവ്യാജവിശ്വാസത്തിൽനിന്നും ഉളവാകുന്ന സ്നേഹമാകുന്നു. ന്യായപ്രമാണം ന്യായമായി ഉപയോഗിച്ചാൽ നല്ലതു തന്നേ. മുമ്പു ദൂഷകനും ഉപദ്രവിയുമായിരുന്ന പൗലൊസ് തന്നെത്താൻ പാപികളിൽ ഒന്നാമനെന്നും ക്രിസ്തുവിന്റെ പൂർണ്ണ ദീർഘക്ഷമയുടെ ദൃഷ്ടാന്തമെന്നും വിളിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Timothy 1: Mercy for the Foremost of Sinners'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-timothy-household-of-god' AND rt.title = '1 Timothy 1: Mercy for the Foremost of Sinners'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Timothy 2: Prayer for All People, One Mediator', 'Read 1 Timothy 2. Paul urges that supplications, prayers, intercessions, and thanksgivings be made for all people, and for kings and all who are in high positions, so that believers may lead peaceful and quiet lives. This is good and pleasing to God our Savior, who desires all people to be saved and to come to the knowledge of the truth. There is one God and one mediator, the man Christ Jesus, who gave himself as a ransom for all. Men are to pray without anger, and women to adorn themselves with good works and learn quietly.', 'Foundations of Faith', 'topic',
       ARRAY['1 timothy', 'prayer', 'one mediator', 'ransom', 'worship']::text[], true, 50, 1
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Timothy 2: Prayer for All People, One Mediator');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 तीमुथियुस 2: सब मनुष्यों के लिए प्रार्थना, एक ही मध्यस्थ', '1 तीमुथियुस 2 पढ़ें। पौलुस आग्रह करता है कि सब मनुष्यों के लिए, और राजाओं तथा सब ऊँचे पदवालों के लिए बिनती, प्रार्थना, निवेदन और धन्यवाद किए जाएँ, ताकि विश्वासी भक्ति और गम्भीरता से शान्त और चैन का जीवन बिताएँ। यह हमारे उद्धारकर्ता परमेश्वर को भला और ग्रहणयोग्य लगता है, जो चाहता है कि सब मनुष्यों का उद्धार हो और वे सत्य की पहचान तक पहुँचें। परमेश्वर एक ही है, और परमेश्वर और मनुष्यों के बीच एक ही मध्यस्थ है, अर्थात् मसीह यीशु, जिसने सब के छुटकारे के दाम में अपने आप को दे दिया। पुरुष क्रोध और विवाद बिना प्रार्थना करें, और स्त्रियाँ भले कामों से अपना श्रृंगार करें और चुपचाप सीखें।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Timothy 2: Prayer for All People, One Mediator'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തിമൊഥെയൊസ് 2: എല്ലാവർക്കുംവേണ്ടി പ്രാർത്ഥന, ഏക മധ്യസ്ഥൻ', '1 തിമൊഥെയൊസ് 2 വായിക്കുക. സകല മനുഷ്യർക്കുംവേണ്ടിയും രാജാക്കന്മാർക്കും ഉന്നതസ്ഥാനത്തുള്ള ഏവർക്കുംവേണ്ടിയും യാചനയും പ്രാർത്ഥനയും പക്ഷവാദവും സ്തോത്രവും കഴിക്കണമെന്നു പൗലൊസ് പ്രബോധിപ്പിക്കുന്നു; അങ്ങനെ വിശ്വാസികൾ സർവ്വഭക്തിയിലും ഗൗരവത്തിലും സാവധാനതയും സ്വസ്ഥതയുമുള്ള ജീവിതം നയിക്കും. ഇതു നമ്മുടെ രക്ഷിതാവായ ദൈവത്തിന്റെ മുമ്പാകെ നല്ലതും പ്രസാദകരവുമാകുന്നു; സകല മനുഷ്യരും രക്ഷപ്രാപിപ്പാനും സത്യത്തിന്റെ പരിജ്ഞാനത്തിൽ എത്തുവാനും അവൻ ഇച്ഛിക്കുന്നു. ദൈവം ഒരുവൻ, ദൈവത്തിനും മനുഷ്യർക്കും മധ്യസ്ഥനും ഒരുവൻ — എല്ലാവർക്കുംവേണ്ടി തന്നെത്താൻ മറുവിലയായി നൽകിയ ക്രിസ്തുയേശു എന്ന മനുഷ്യൻ. പുരുഷന്മാർ കോപവും തർക്കവും കൂടാതെ പ്രാർത്ഥിക്കട്ടെ; സ്ത്രീകൾ സൽപ്രവൃത്തികളാൽ തങ്ങളെ അലങ്കരിച്ചു മൗനമായി പഠിക്കട്ടെ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Timothy 2: Prayer for All People, One Mediator'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 1, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-timothy-household-of-god' AND rt.title = '1 Timothy 2: Prayer for All People, One Mediator'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Timothy 3: Overseers, Deacons, and the Pillar of Truth', 'Read 1 Timothy 3. Paul lists what an overseer must be: above reproach, faithful to his wife, sober-minded, self-controlled, hospitable, able to teach, not a drunkard or a lover of money, managing his own household well, not a recent convert, and well thought of by outsiders. Deacons likewise must be dignified, not double-tongued, tested first and found blameless. Paul writes so that you may know how one ought to behave in the household of God, the church of the living God, a pillar and buttress of the truth, which confesses the great mystery of godliness.', 'Foundations of Faith', 'topic',
       ARRAY['1 timothy', 'overseers', 'deacons', 'church', 'godliness']::text[], true, 50, 2
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Timothy 3: Overseers, Deacons, and the Pillar of Truth');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 तीमुथियुस 3: अध्यक्ष, सेवक और सत्य का खम्भा', '1 तीमुथियुस 3 पढ़ें। पौलुस बताता है कि अध्यक्ष कैसा होना चाहिए: निर्दोष, एक ही पत्नी का पति, संयमी, आत्मसंयमी, अतिथि-सत्कार करनेवाला, सिखाने में निपुण, न पियक्कड़ न लोभी, अपने घर का अच्छा प्रबन्ध करनेवाला, नया चेला नहीं, और बाहरवालों में भी सुनाम रखनेवाला। वैसे ही सेवक गम्भीर हों, दो रंगी बात न करें, पहले परखे जाएँ और निर्दोष पाए जाएँ। पौलुस यह इसलिए लिखता है कि तुम जानो कि परमेश्वर के घराने में, जो जीवते परमेश्वर की कलीसिया और सत्य का खम्भा और नींव है, कैसा चलना चाहिए; वही भक्ति के महान भेद को अंगीकार करती है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Timothy 3: Overseers, Deacons, and the Pillar of Truth'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തിമൊഥെയൊസ് 3: അധ്യക്ഷന്മാർ, ശുശ്രൂഷകന്മാർ, സത്യത്തിന്റെ തൂൺ', '1 തിമൊഥെയൊസ് 3 വായിക്കുക. അധ്യക്ഷൻ എങ്ങനെയുള്ളവനായിരിക്കണമെന്നു പൗലൊസ് വിവരിക്കുന്നു: അനിന്ദ്യൻ, ഏകഭാര്യയുടെ ഭർത്താവ്, നിർമ്മദൻ, ജിതേന്ദ്രിയൻ, അതിഥിപ്രിയൻ, ഉപദേശിപ്പാൻ സമർത്ഥൻ, മദ്യപ്രിയനോ ദ്രവ്യാഗ്രഹിയോ അല്ലാത്തവൻ, സ്വന്തഭവനം നന്നായി ഭരിക്കുന്നവൻ, പുതുവിശ്വാസിയല്ലാത്തവൻ, പുറത്തുള്ളവരുടെ ഇടയിലും നല്ല സാക്ഷ്യമുള്ളവൻ. അങ്ങനെതന്നെ ശുശ്രൂഷകന്മാരും ഗൗരവമുള്ളവരും ഇരുവാക്കുകാരല്ലാത്തവരും ആദ്യം പരീക്ഷിക്കപ്പെട്ടു കുറ്റമില്ലാത്തവരും ആയിരിക്കണം. ജീവനുള്ള ദൈവത്തിന്റെ സഭയും സത്യത്തിന്റെ തൂണും അടിസ്ഥാനവുമായ ദൈവഭവനത്തിൽ എങ്ങനെ നടക്കേണമെന്നു നീ അറിയേണ്ടതിന്നാകുന്നു പൗലൊസ് ഇതെഴുതുന്നത്; ആ സഭ ദൈവഭക്തിയുടെ മഹാരഹസ്യം ഏറ്റുപറയുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Timothy 3: Overseers, Deacons, and the Pillar of Truth'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 2, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-timothy-household-of-god' AND rt.title = '1 Timothy 3: Overseers, Deacons, and the Pillar of Truth'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Timothy 4: Train Yourself for Godliness', 'Read 1 Timothy 4. The Spirit says that in later times some will depart from the faith by devoting themselves to deceitful spirits and the teachings of demons, forbidding marriage and requiring abstinence from foods that God created to be received with thanksgiving. Timothy is to have nothing to do with irreverent myths and instead to train himself for godliness, which holds promise for this life and the life to come. Let no one despise his youth: set an example, devote yourself to Scripture, and keep a close watch on yourself and your teaching.', 'Foundations of Faith', 'topic',
       ARRAY['1 timothy', 'godliness', 'training', 'scripture', 'perseverance']::text[], true, 50, 3
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Timothy 4: Train Yourself for Godliness');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 तीमुथियुस 4: भक्ति के लिए अपने आप को साध', '1 तीमुथियुस 4 पढ़ें। आत्मा स्पष्ट कहता है कि अन्तिम समयों में कितने लोग भरमानेवाली आत्माओं और दुष्टात्माओं के उपदेशों पर मन लगाकर विश्वास से भटक जाएँगे; वे विवाह से रोकेंगे और उन भोजनों से दूर रहने को कहेंगे जिन्हें परमेश्वर ने इसलिए बनाया कि विश्वासी और सत्य के जाननेवाले धन्यवाद के साथ उन्हें ग्रहण करें। तीमुथियुस अशुद्ध कहानियों से दूर रहे और भक्ति के लिए अपने आप को साधे, क्योंकि भक्ति इस जीवन और आनेवाले जीवन दोनों की प्रतिज्ञा रखती है। कोई तेरी जवानी को तुच्छ न समझे: वचन, चालचलन, प्रेम, विश्वास और पवित्रता में आदर्श बन, पवित्रशास्त्र के पढ़ने में लगा रह, और अपनी तथा अपने उपदेश की चौकसी कर।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Timothy 4: Train Yourself for Godliness'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തിമൊഥെയൊസ് 4: ദൈവഭക്തിക്കായി അഭ്യസിക്കുക', '1 തിമൊഥെയൊസ് 4 വായിക്കുക. പിൽക്കാലങ്ങളിൽ ചിലർ വഞ്ചിക്കുന്ന ആത്മാക്കളെയും ഭൂതങ്ങളുടെ ഉപദേശങ്ങളെയും ആശ്രയിച്ചു വിശ്വാസം ത്യജിക്കുമെന്നു ആത്മാവു വ്യക്തമായി പറയുന്നു; അവർ വിവാഹം വിലക്കുകയും, വിശ്വസിക്കുന്നവരും സത്യം അറിയുന്നവരും സ്തോത്രത്തോടെ അനുഭവിപ്പാൻ ദൈവം സൃഷ്ടിച്ച ഭക്ഷണങ്ങൾ വർജ്ജിപ്പാൻ കല്പിക്കുകയും ചെയ്യും. ഭക്തിവിരുദ്ധമായ കെട്ടുകഥകളെ തിമൊഥെയൊസ് ഒഴിവാക്കി, ദൈവഭക്തിക്കായി തന്നെത്താൻ അഭ്യസിക്കട്ടെ; ദൈവഭക്തി ഈ ജീവന്റെയും വരുവാനുള്ളതിന്റെയും വാഗ്ദത്തമുള്ളതാകുന്നു. നിന്റെ യൗവനം ആരും തുച്ഛീകരിക്കരുതു: വാക്കിലും നടപ്പിലും സ്നേഹത്തിലും വിശ്വാസത്തിലും നിർമ്മലതയിലും മാതൃകയായിരിക്ക, തിരുവെഴുത്തു വായനയിൽ ഉത്സാഹിക്ക, നിന്നെയും നിന്റെ ഉപദേശത്തെയും സൂക്ഷിച്ചുകൊൾക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Timothy 4: Train Yourself for Godliness'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 3, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-timothy-household-of-god' AND rt.title = '1 Timothy 4: Train Yourself for Godliness'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Timothy 5: Honouring Widows and Elders', 'Read 1 Timothy 5. Paul teaches Timothy to treat the church as a family: older men as fathers, younger men as brothers, older women as mothers, and younger women as sisters in all purity. Widows who are truly left alone are to be honoured and supported, while families must first learn to care for their own relatives, and younger widows are encouraged to marry. Elders who rule well, especially those who labour in preaching and teaching, are worthy of double honour. No charge against an elder may be received except on two or three witnesses.', 'Foundations of Faith', 'topic',
       ARRAY['1 timothy', 'widows', 'elders', 'family', 'church order']::text[], true, 50, 4
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Timothy 5: Honouring Widows and Elders');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 तीमुथियुस 5: विधवाओं और प्राचीनों का आदर', '1 तीमुथियुस 5 पढ़ें। पौलुस तीमुथियुस को सिखाता है कि कलीसिया के साथ परिवार जैसा व्यवहार करे: बूढ़ों को पिता, जवानों को भाई, बूढ़ी स्त्रियों को माता, और जवान स्त्रियों को पूरी पवित्रता के साथ बहन समझे। जो विधवाएँ सचमुच असहाय हैं उनका आदर और सहायता की जाए, पर परिवारों को पहले अपने ही सम्बन्धियों की सुधि लेनी चाहिए, और जवान विधवाओं को विवाह करने को कहा गया है। जो प्राचीन अच्छी रीति से अगुवाई करते हैं, विशेषकर वे जो वचन सुनाने और सिखाने में परिश्रम करते हैं, दुगने आदर के योग्य हैं, क्योंकि मजदूर अपनी मजदूरी का हकदार है। किसी प्राचीन पर दो या तीन गवाहों के बिना दोष न लगाया जाए।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Timothy 5: Honouring Widows and Elders'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തിമൊഥെയൊസ് 5: വിധവമാരെയും മൂപ്പന്മാരെയും ബഹുമാനിക്കുക', '1 തിമൊഥെയൊസ് 5 വായിക്കുക. സഭയോടു ഒരു കുടുംബത്തോടെന്നപോലെ പെരുമാറാൻ പൗലൊസ് തിമൊഥെയൊസിനെ പഠിപ്പിക്കുന്നു: വൃദ്ധന്മാരെ അപ്പനായും യൗവനക്കാരെ സഹോദരന്മാരായും വൃദ്ധമാരെ അമ്മമാരായും യുവതികളെ പൂർണ്ണനിർമ്മലതയോടെ സഹോദരിമാരായും കരുതുക. യഥാർത്ഥത്തിൽ ഏകാകികളായ വിധവമാരെ ബഹുമാനിക്കയും സഹായിക്കയും വേണം; എന്നാൽ കുടുംബങ്ങൾ ആദ്യം സ്വന്ത ചാർച്ചക്കാരെ പരിപാലിപ്പാൻ പഠിക്കണം, യുവവിധവമാർ വിവാഹം കഴിക്കട്ടെ. നന്നായി ഭരിക്കുന്ന മൂപ്പന്മാർ, വിശേഷാൽ വചനത്തിലും ഉപദേശത്തിലും അദ്ധ്വാനിക്കുന്നവർ, ഇരട്ടി മാനത്തിനു യോഗ്യർ; വേലക്കാരൻ തന്റെ കൂലിക്കു യോഗ്യനല്ലോ. രണ്ടു മൂന്നു സാക്ഷികളില്ലാതെ ഒരു മൂപ്പന്റെ നേരെ ആരോപണം കൈക്കൊള്ളരുതു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Timothy 5: Honouring Widows and Elders'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 4, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-timothy-household-of-god' AND rt.title = '1 Timothy 5: Honouring Widows and Elders'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '1 Timothy 6: Godliness with Contentment', 'Read 1 Timothy 6. Bondservants are to honour their masters so God''s name is not reviled. Paul exposes teachers who imagine godliness is a means of gain, and answers that godliness with contentment is great gain, for we brought nothing into the world and take nothing out. The love of money is a root of all kinds of evils. Flee these things; pursue righteousness, godliness, faith, love, steadfastness, gentleness. Fight the good fight of the faith and take hold of eternal life. Charge the rich to be rich in good works, and guard the deposit entrusted to you.', 'Foundations of Faith', 'topic',
       ARRAY['1 timothy', 'contentment', 'money', 'good fight', 'eternal life']::text[], true, 50, 5
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '1 Timothy 6: Godliness with Contentment');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '1 तीमुथियुस 6: संतोष सहित भक्ति', '1 तीमुथियुस 6 पढ़ें। दास अपने स्वामियों का आदर करें, कि परमेश्वर के नाम और उपदेश की निन्दा न हो। पौलुस उन शिक्षकों को उजागर करता है जो भक्ति को कमाई का साधन समझते हैं, और उत्तर देता है कि संतोष सहित भक्ति ही बड़ी कमाई है, क्योंकि हम जगत में कुछ नहीं लाए और न कुछ ले जा सकते हैं। धन का लोभ सब प्रकार की बुराइयों की जड़ है। इन बातों से भाग, और धर्म, भक्ति, विश्वास, प्रेम, धीरज और नम्रता का पीछा कर। विश्वास की अच्छी लड़ाई लड़ और अनन्त जीवन को थाम ले। धनवानों को आज्ञा दे कि वे उदार और भले कामों में धनी हों, और जो धरोहर तुझे सौंपी गई है उसकी रखवाली कर।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '1 Timothy 6: Godliness with Contentment'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '1 തിമൊഥെയൊസ് 6: സംതൃപ്തിയോടുകൂടിയ ദൈവഭക്തി', '1 തിമൊഥെയൊസ് 6 വായിക്കുക. ദൈവനാമവും ഉപദേശവും ദുഷിക്കപ്പെടാതിരിക്കേണ്ടതിന്നു ദാസന്മാർ യജമാനന്മാരെ ബഹുമാനിക്കട്ടെ. ദൈവഭക്തി ആദായമാർഗ്ഗമെന്നു നിരൂപിക്കുന്ന ഉപദേഷ്ടാക്കളെ പൗലൊസ് വെളിപ്പെടുത്തി, സംതൃപ്തിയോടുകൂടിയ ദൈവഭക്തിതന്നേ വലിയ ആദായം എന്നു ഉത്തരം പറയുന്നു; നാം ലോകത്തിലേക്കു ഒന്നും കൊണ്ടുവന്നിട്ടില്ല, ഒന്നും കൊണ്ടുപോകുവാൻ കഴിയുകയുമില്ല. ദ്രവ്യാഗ്രഹം സകലവിധ ദോഷത്തിനും മൂലമാകുന്നു. ഇവ വിട്ടോടി നീതി, ദൈവഭക്തി, വിശ്വാസം, സ്നേഹം, ക്ഷമ, സൗമ്യത എന്നിവ പിന്തുടരുക. വിശ്വാസത്തിന്റെ നല്ല പോർ പൊരുതി നിത്യജീവനെ പിടിച്ചുകൊൾക. ധനവാന്മാരോടു ഉദാരതയുള്ളവരും സൽപ്രവൃത്തികളിൽ സമ്പന്നരും ആകുവാൻ കല്പിക്ക; നിന്നെ ഏല്പിച്ച ഉപനിധി കാത്തുകൊൾക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '1 Timothy 6: Godliness with Contentment'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 5, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '1-timothy-household-of-god' AND rt.title = '1 Timothy 6: Godliness with Contentment'
ON CONFLICT DO NOTHING;

-- ===== 2 Timothy: Finish the Race (4 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('2-timothy-guard-the-good-deposit', '2 Timothy: Finish the Race', 'Written from a Roman cell as execution drew near, 2 Timothy is Paul''s last letter, a father''s charge to a younger minister. In four chapters he calls Timothy to fan into flame the gift of God, to suffer as a good soldier, to entrust the message to faithful people, and to trust the Scripture God himself breathed out. Finish your race and keep the faith.',
        'military_tech', '#A16207', 200, 12,
        'disciple', 'standard', false, 46, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', '2 तीमुथियुस: दौड़ को पूरा करो', 'मृत्युदंड के निकट, रोम की कैद से लिखा गया 2 तीमुथियुस पौलुस की अंतिम पत्री है, एक पिता समान सेवक की ओर से एक युवा सेवक को सौंपा गया आदेश। चार अध्यायों में वह तीमुथियुस को बुलाता है कि परमेश्वर के वरदान को प्रज्वलित करे, अच्छे सिपाही के समान दुख उठाए, संदेश को विश्वासयोग्य लोगों को सौंपे, और उस पवित्रशास्त्र पर भरोसा रखे जो परमेश्वर की प्रेरणा से रचा गया है। अपनी दौड़ पूरी करो और विश्वास को थामे रहो।'
  FROM public.learning_paths WHERE slug = '2-timothy-guard-the-good-deposit'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', '2 തിമൊഥെയൊസ്: ഓട്ടം പൂർത്തിയാക്കുക', 'വധശിക്ഷ അടുത്തിരിക്കെ റോമിലെ തടവറയിൽനിന്ന് എഴുതിയ 2 തിമൊഥെയൊസ് പൗലൊസിന്റെ അവസാന ലേഖനമാണ്, ഒരു പിതാവ് യുവശുശ്രൂഷകന് നൽകുന്ന കൽപ്പന. നാല് അധ്യായങ്ങളിൽ ദൈവത്തിന്റെ കൃപാവരം ജ്വലിപ്പിക്കുവാനും, നല്ല പടയാളിയെപ്പോലെ കഷ്ടം സഹിക്കുവാനും, സന്ദേശം വിശ്വസ്തരായവരെ ഭരമേൽപ്പിക്കുവാനും, ദൈവം ശ്വസിച്ചുനൽകിയ തിരുവെഴുത്തിൽ ആശ്രയിക്കുവാനും അവൻ തിമൊഥെയൊസിനെ ആഹ്വാനം ചെയ്യുന്നു. നിന്റെ ഓട്ടം പൂർത്തിയാക്കി വിശ്വാസം കാത്തുകൊള്ളുക.'
  FROM public.learning_paths WHERE slug = '2-timothy-guard-the-good-deposit'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '2 Timothy 1: Fan Into Flame the Gift of God', 'Read 2 Timothy 1. Paul writes from prison and thanks God for the sincere faith he first saw in Timothy''s grandmother Lois and his mother Eunice. He urges Timothy to fan into flame the gift of God, for God gave us a spirit not of fear but of power, love and self-control. Do not be ashamed of the testimony about our Lord, nor of Paul''s chains. God saved and called us not because of our works but because of his own purpose and grace.', 'Foundations of Faith', 'topic',
       ARRAY['2 timothy', 'courage', 'calling', 'grace']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '2 Timothy 1: Fan Into Flame the Gift of God');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '2 तीमुथियुस 1: परमेश्वर के वरदान को प्रज्वलित करो', '2 तीमुथियुस 1 पढ़ें। पौलुस कैद से लिखता है और उस निष्कपट विश्वास के लिये परमेश्वर का धन्यवाद करता है जो पहले तीमुथियुस की नानी लोइस और माता यूनीके में था। वह तीमुथियुस से आग्रह करता है कि परमेश्वर के वरदान को प्रज्वलित करे, क्योंकि परमेश्वर ने हमें भय की नहीं, पर सामर्थ्य, प्रेम और संयम की आत्मा दी है। हमारे प्रभु की गवाही से या पौलुस की जंजीरों से लज्जित न हो। परमेश्वर ने हमें हमारे कामों के कारण नहीं, पर अपने ही उद्देश्य और अनुग्रह के अनुसार उद्धार दिया और बुलाया।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '2 Timothy 1: Fan Into Flame the Gift of God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '2 തിമൊഥെയൊസ് 1: ദൈവകൃപാവരം ജ്വലിപ്പിക്കുക', '2 തിമൊഥെയൊസ് 1 വായിക്കുക. തടവറയിൽനിന്ന് എഴുതുന്ന പൗലൊസ്, തിമൊഥെയൊസിന്റെ വലിയമ്മ ലോവീസിലും അമ്മ യൂനീക്കയിലും ആദ്യം കണ്ട നിർവ്യാജ വിശ്വാസത്തിനായി ദൈവത്തിന് നന്ദി പറയുന്നു. ദൈവത്തിന്റെ കൃപാവരം ജ്വലിപ്പിക്കുവാൻ അവൻ തിമൊഥെയൊസിനെ പ്രബോധിപ്പിക്കുന്നു; ദൈവം നമുക്കു നൽകിയത് ഭീരുത്വത്തിന്റെ ആത്മാവിനെയല്ല, ശക്തിയുടെയും സ്നേഹത്തിന്റെയും സുബോധത്തിന്റെയും ആത്മാവിനെയത്രേ. നമ്മുടെ കർത്താവിന്റെ സാക്ഷ്യത്തെക്കുറിച്ചോ പൗലൊസിന്റെ ചങ്ങലകളെക്കുറിച്ചോ ലജ്ജിക്കരുത്. നമ്മുടെ പ്രവൃത്തികൾ നിമിത്തമല്ല, തന്റെ സ്വന്ത ഉദ്ദേശ്യവും കൃപയും അനുസരിച്ചത്രേ ദൈവം നമ്മെ രക്ഷിച്ചു വിളിച്ചത്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '2 Timothy 1: Fan Into Flame the Gift of God'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '2-timothy-guard-the-good-deposit' AND rt.title = '2 Timothy 1: Fan Into Flame the Gift of God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '2 Timothy 2: Entrust It to Faithful People', 'Read 2 Timothy 2. Be strengthened by the grace that is in Christ Jesus, and entrust what you have heard to faithful people who will be able to teach others also. Paul pictures the single-minded soldier, the rule-keeping athlete and the hard-working farmer, then points to the risen Christ: if we are faithless, he remains faithful. Rightly handle the word of truth, flee youthful passions, and pursue righteousness from a pure heart. The Lord''s servant must not quarrel but correct opponents with gentleness, praying God grants them repentance.', 'Foundations of Faith', 'topic',
       ARRAY['2 timothy', 'discipleship', 'endurance', 'truth']::text[], true, 50, 1
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '2 Timothy 2: Entrust It to Faithful People');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '2 तीमुथियुस 2: विश्वासयोग्य लोगों को सौंप दो', '2 तीमुथियुस 2 पढ़ें। उस अनुग्रह से बलवन्त हो जो मसीह यीशु में है, और जो बातें तूने सुनी हैं उन्हें ऐसे विश्वासयोग्य लोगों को सौंप दे जो दूसरों को भी सिखाने योग्य हों। पौलुस एकाग्र सिपाही, नियम से लड़नेवाले पहलवान और परिश्रमी किसान का चित्र देता है, फिर जी उठे मसीह की ओर संकेत करता है: यदि हम अविश्वासी भी हों, तौभी वह विश्वासयोग्य बना रहता है। सत्य के वचन को ठीक-ठीक काम में ला, जवानी की अभिलाषाओं से भाग, और शुद्ध मन से धार्मिकता का पीछा कर। प्रभु के दास को झगड़ालू नहीं, पर नम्रता से विरोधियों को सुधारनेवाला होना चाहिए, यह प्रार्थना करते हुए कि परमेश्वर उन्हें मन फिराव दे।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '2 Timothy 2: Entrust It to Faithful People'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '2 തിമൊഥെയൊസ് 2: വിശ്വസ്തരെ ഭരമേൽപ്പിക്കുക', '2 തിമൊഥെയൊസ് 2 വായിക്കുക. ക്രിസ്തുയേശുവിലുള്ള കൃപയാൽ ശക്തിപ്പെടുക; നീ കേട്ടത് മറ്റുള്ളവരെ പഠിപ്പിക്കുവാൻ പ്രാപ്തരായ വിശ്വസ്തരെ ഭരമേൽപ്പിക്കുക. ഏകാഗ്രതയുള്ള പടയാളി, ചട്ടപ്രകാരം മത്സരിക്കുന്ന ഗുസ്തിക്കാരൻ, അധ്വാനിക്കുന്ന കൃഷിക്കാരൻ എന്നീ ചിത്രങ്ങൾ നൽകിയശേഷം പൗലൊസ് ഉയിർത്തെഴുന്നേറ്റ ക്രിസ്തുവിലേക്ക് വിരൽ ചൂണ്ടുന്നു: നാം അവിശ്വസ്തരായാലും അവൻ വിശ്വസ്തനായി നിലനിൽക്കുന്നു. സത്യവചനം യഥാർഥമായി പ്രയോഗിക്കുക, യൗവനമോഹങ്ങളിൽനിന്ന് ഓടിയകലുക, നിർമല ഹൃദയത്തോടെ നീതി പിന്തുടരുക. കർത്താവിന്റെ ദാസൻ കലഹിക്കാതെ, ദൈവം മാനസാന്തരം നൽകട്ടെ എന്നു പ്രാർഥിച്ച് സൗമ്യതയോടെ എതിരാളികളെ തിരുത്തണം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '2 Timothy 2: Entrust It to Faithful People'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 1, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '2-timothy-guard-the-good-deposit' AND rt.title = '2 Timothy 2: Entrust It to Faithful People'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '2 Timothy 3: All Scripture Is Breathed Out by God', 'Read 2 Timothy 3. Paul warns that in the last days difficult times will come: people will love themselves, money and pleasure rather than God, holding a form of godliness while denying its power. All who desire to live a godly life in Christ Jesus will be persecuted. Timothy is to continue in what he has learned and firmly believed, remembering the sacred writings that made him wise for salvation through faith in Christ Jesus. All Scripture is breathed out by God and equips his servant for every good work.', 'Foundations of Faith', 'topic',
       ARRAY['2 timothy', 'scripture', 'last days', 'perseverance']::text[], true, 50, 2
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '2 Timothy 3: All Scripture Is Breathed Out by God');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '2 तीमुथियुस 3: सम्पूर्ण पवित्रशास्त्र परमेश्वर की प्रेरणा से है', '2 तीमुथियुस 3 पढ़ें। पौलुस चेतावनी देता है कि अन्तिम दिनों में कठिन समय आएगा: लोग परमेश्वर के नहीं, पर अपने आप के, धन के और सुख-विलास के प्रेमी होंगे, और भक्ति का भेष धरे रहेंगे पर उसकी शक्ति का इन्कार करेंगे। जो कोई मसीह यीशु में भक्ति के साथ जीवन बिताना चाहता है, वह सताया जाएगा। तीमुथियुस को उन बातों में बने रहना है जो उसने सीखीं और जिन पर दृढ़ विश्वास किया, और उन पवित्रशास्त्रों को स्मरण रखना है जिन्होंने उसे मसीह यीशु पर विश्वास के द्वारा उद्धार के लिये बुद्धिमान बनाया। सम्पूर्ण पवित्रशास्त्र परमेश्वर की प्रेरणा से रचा गया है और परमेश्वर के जन को हर एक भले काम के लिये तैयार करता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '2 Timothy 3: All Scripture Is Breathed Out by God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '2 തിമൊഥെയൊസ് 3: എല്ലാ തിരുവെഴുത്തും ദൈവശ്വാസീയം', '2 തിമൊഥെയൊസ് 3 വായിക്കുക. അന്ത്യകാലത്ത് ദുർഘടസമയങ്ങൾ വരുമെന്ന് പൗലൊസ് മുന്നറിയിപ്പു നൽകുന്നു: മനുഷ്യർ ദൈവത്തെക്കാൾ തങ്ങളെയും ദ്രവ്യത്തെയും സുഖഭോഗത്തെയും സ്നേഹിക്കുന്നവരായി, ഭക്തിയുടെ വേഷം ധരിച്ച് അതിന്റെ ശക്തിയെ തള്ളിപ്പറയും. ക്രിസ്തുയേശുവിൽ ഭക്തിയോടെ ജീവിക്കാൻ ഇച്ഛിക്കുന്ന എല്ലാവരും ഉപദ്രവം അനുഭവിക്കും. താൻ പഠിച്ചതിലും ഉറച്ചു വിശ്വസിച്ചതിലും നിലനിൽക്കുവാനും, ക്രിസ്തുയേശുവിലുള്ള വിശ്വാസത്താൽ രക്ഷയ്ക്കായി തന്നെ ജ്ഞാനിയാക്കിയ വിശുദ്ധ എഴുത്തുകളെ ഓർക്കുവാനും തിമൊഥെയൊസ് വിളിക്കപ്പെടുന്നു. എല്ലാ തിരുവെഴുത്തും ദൈവശ്വാസീയമാകുന്നു; അത് ദൈവഭൃത്യനെ സകല സൽപ്രവൃത്തിക്കും സജ്ജനാക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '2 Timothy 3: All Scripture Is Breathed Out by God'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 2, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '2-timothy-guard-the-good-deposit' AND rt.title = '2 Timothy 3: All Scripture Is Breathed Out by God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT '2 Timothy 4: I Have Kept the Faith', 'Read 2 Timothy 4. Paul gives his final charge: preach the word, be ready in season and out of season, reprove, rebuke and exhort with complete patience and teaching, because people will gather teachers to suit their own itching ears. Do the work of an evangelist and fulfil your ministry. Paul knows his departure is near: I have fought the good fight, I have finished the race, I have kept the faith, and the crown of righteousness awaits all who love his appearing. Though friends deserted him, the Lord stood by him.', 'Foundations of Faith', 'topic',
       ARRAY['2 timothy', 'preaching', 'faithfulness', 'reward']::text[], true, 50, 3
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = '2 Timothy 4: I Have Kept the Faith');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', '2 तीमुथियुस 4: मैंने विश्वास की रखवाली की है', '2 तीमुथियुस 4 पढ़ें। पौलुस अपना अन्तिम आदेश देता है: वचन का प्रचार कर, समय और असमय तैयार रह, पूरे धीरज और शिक्षा के साथ समझा, डाँट और उपदेश दे, क्योंकि लोग अपनी कानों की खुजली के अनुसार अपने लिये उपदेशक बटोर लेंगे। सुसमाचार प्रचारक का काम कर और अपनी सेवा को पूरा कर। पौलुस जानता है कि उसके कूच का समय निकट है: मैं अच्छी लड़ाई लड़ चुका, मैंने अपनी दौड़ पूरी कर ली, मैंने विश्वास की रखवाली की है; और धार्मिकता का मुकुट उन सब की प्रतीक्षा करता है जो उसके प्रगट होने के प्रेमी हैं। यद्यपि मित्रों ने उसे छोड़ दिया, प्रभु उसके साथ खड़ा रहा।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = '2 Timothy 4: I Have Kept the Faith'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', '2 തിമൊഥെയൊസ് 4: ഞാൻ വിശ്വാസം കാത്തു', '2 തിമൊഥെയൊസ് 4 വായിക്കുക. പൗലൊസ് തന്റെ അന്തിമ കൽപ്പന നൽകുന്നു: വചനം പ്രസംഗിക്കുക, സമയത്തും അസമയത്തും ഒരുങ്ങിയിരിക്കുക, പൂർണ ദീർഘക്ഷമയോടും ഉപദേശത്തോടുംകൂടെ ബോധിപ്പിക്കുകയും ശാസിക്കുകയും പ്രബോധിപ്പിക്കുകയും ചെയ്യുക; എന്തെന്നാൽ ചെവിക്കു ഇമ്പമുള്ളത് കേൾക്കാൻ മനുഷ്യർ സ്വന്തം ഇഷ്ടപ്രകാരം ഉപദേഷ്ടാക്കന്മാരെ കൂട്ടും. സുവിശേഷകന്റെ വേല ചെയ്ത് നിന്റെ ശുശ്രൂഷ പൂർത്തിയാക്കുക. തന്റെ വേർപാടിന്റെ സമയം അടുത്തെന്ന് പൗലൊസ് അറിയുന്നു: ഞാൻ നല്ല പോർ പൊരുതി, ഓട്ടം തികച്ചു, വിശ്വാസം കാത്തു; അവന്റെ പ്രത്യക്ഷതയെ സ്നേഹിക്കുന്ന എല്ലാവർക്കും നീതിയുടെ കിരീടം ഒരുങ്ങിയിരിക്കുന്നു. സ്നേഹിതർ ഉപേക്ഷിച്ചിട്ടും കർത്താവ് അവനോടുകൂടെ നിന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = '2 Timothy 4: I Have Kept the Faith'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 3, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = '2-timothy-guard-the-good-deposit' AND rt.title = '2 Timothy 4: I Have Kept the Faith'
ON CONFLICT DO NOTHING;

-- ===== Titus: Sound Doctrine, Sound Living (3 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('titus-sound-doctrine-sound-living', 'Titus: Sound Doctrine, Sound Living', 'Left on Crete to finish Paul''s work, Titus was told to appoint qualified elders in every town and teach what accords with sound doctrine. In three chapters Paul shows how sound teaching produces sound living in every age and station, grounded in grace: God saved us not by works done in righteousness, but according to his mercy. Learn to devote yourself to good works as the fruit of that salvation.',
        'verified', '#4338CA', 150, 9,
        'disciple', 'standard', false, 47, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', 'तीतुस: खरा सिद्धांत, खरा जीवन', 'पौलुस ने जो आरम्भ किया था उसे पूरा करने के लिए तीतुस क्रेते में छोड़ा गया, कि वह हर नगर में योग्य प्राचीन नियुक्त करे और वही सिखाए जो खरे सिद्धांत के अनुसार है। तीन छोटे अध्यायों में पौलुस दिखाता है कि खरी शिक्षा हर आयु और हर स्थिति में खरा जीवन उत्पन्न करती है, और इस सब की नींव अनुग्रह है: परमेश्वर ने हमें धर्म के कामों के कारण नहीं, पर अपनी ही दया के अनुसार बचाया। उसी उद्धार के फल के रूप में भले कामों में लगे रहना सीखें।'
  FROM public.learning_paths WHERE slug = 'titus-sound-doctrine-sound-living'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', 'തീത്തൊസ്: സത്യോപദേശവും സത്യജീവിതവും', 'പൗലൊസ് ആരംഭിച്ചതു പൂർത്തിയാക്കാൻ ക്രേത്തയിൽ വിടപ്പെട്ട തീത്തൊസിനോടു, ഓരോ പട്ടണത്തിലും യോഗ്യരായ മൂപ്പന്മാരെ നിയമിക്കാനും സത്യോപദേശത്തിനു യോജിച്ചതു പഠിപ്പിക്കാനും കല്പിക്കുന്നു. മൂന്നു ചെറിയ അധ്യായങ്ങളിൽ, സത്യമായ ഉപദേശം എല്ലാ പ്രായത്തിലും അവസ്ഥയിലും സത്യമായ ജീവിതം ഉളവാക്കുന്നതു പൗലൊസ് കാണിക്കുന്നു; അതിന്റെ അടിസ്ഥാനമോ കൃപതന്നേ: നാം ചെയ്ത നീതിപ്രവൃത്തികളാലല്ല, തന്റെ കരുണപ്രകാരമത്രേ ദൈവം നമ്മെ രക്ഷിച്ചത്. ആ രക്ഷയുടെ ഫലമായി സൽപ്രവൃത്തികളിൽ ഉത്സാഹിക്കാൻ പഠിക്കുക.'
  FROM public.learning_paths WHERE slug = 'titus-sound-doctrine-sound-living'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Titus 1: Elders in Every Town', 'Read Titus 1. Paul writes as a servant of God and an apostle for the sake of the faith of God''s elect and the knowledge of the truth that accords with godliness, resting on the hope of eternal life promised by God, who never lies. He left Titus in Crete to put what remained into order and appoint elders in every town: men above reproach, faithful husbands, self-controlled, hospitable, lovers of good, holding firmly to the trustworthy word. Such elders can teach sound doctrine and rebuke those who profess to know God but deny him by their works.', 'Foundations of Faith', 'topic',
       ARRAY['titus', 'elders', 'crete', 'sound doctrine', 'leadership']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Titus 1: Elders in Every Town');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'तीतुस 1: हर नगर में प्राचीन', 'तीतुस 1 पढ़ें। पौलुस परमेश्वर के दास और यीशु मसीह के प्रेरित के रूप में लिखता है, परमेश्वर के चुने हुओं के विश्वास और उस सत्य की पहचान के लिए जो भक्ति के अनुसार है, और जिसकी नींव उस अनन्त जीवन की आशा है जिसकी प्रतिज्ञा झूठ न बोलनेवाले परमेश्वर ने की। उसने तीतुस को क्रेते में इसलिए छोड़ा कि जो बातें रह गई थीं उन्हें सुधारे और हर नगर में प्राचीन नियुक्त करे: ऐसे जन जो निर्दोष हों, एक ही पत्नी के पति, संयमी, अतिथि-सत्कार करनेवाले, भलाई से प्रीति रखनेवाले, और विश्वासयोग्य वचन को थामे रहनेवाले। ऐसे प्राचीन खरा उपदेश दे सकते हैं और उन्हें डाँट सकते हैं जो परमेश्वर को जानने का दावा तो करते हैं पर अपने कामों से उसका इन्कार करते हैं।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Titus 1: Elders in Every Town'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'തീത്തൊസ് 1: ഓരോ പട്ടണത്തിലും മൂപ്പന്മാർ', 'തീത്തൊസ് 1 വായിക്കുക. ദൈവത്തിന്റെ ദാസനും യേശുക്രിസ്തുവിന്റെ അപ്പൊസ്തലനുമായി പൗലൊസ് എഴുതുന്നു — ദൈവത്തിന്റെ വൃതന്മാരുടെ വിശ്വാസത്തിനും ദൈവഭക്തിക്കു യോജിച്ച സത്യത്തിന്റെ പരിജ്ഞാനത്തിനുംവേണ്ടി; ഭോഷ്കില്ലാത്ത ദൈവം വാഗ്ദത്തം ചെയ്ത നിത്യജീവന്റെ പ്രത്യാശയത്രേ അതിന്റെ അടിസ്ഥാനം. ബാക്കിയുള്ളവ ക്രമപ്പെടുത്തുവാനും ഓരോ പട്ടണത്തിലും മൂപ്പന്മാരെ നിയമിപ്പാനും അവൻ തീത്തൊസിനെ ക്രേത്തയിൽ വിട്ടു: അനിന്ദ്യരും ഏകഭാര്യയുടെ ഭർത്താക്കന്മാരും ജിതേന്ദ്രിയരും അതിഥിപ്രിയരും നന്മയെ സ്നേഹിക്കുന്നവരും വിശ്വാസ്യവചനം മുറുകെ പിടിക്കുന്നവരും ആയവർ. അങ്ങനെയുള്ള മൂപ്പന്മാർക്കു സത്യോപദേശം പഠിപ്പിപ്പാനും, ദൈവത്തെ അറിയുന്നു എന്നു പറഞ്ഞിട്ടു പ്രവൃത്തികളാൽ അവനെ തള്ളിപ്പറയുന്നവരെ ശാസിപ്പാനും കഴിയും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Titus 1: Elders in Every Town'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'titus-sound-doctrine-sound-living' AND rt.title = 'Titus 1: Elders in Every Town'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Titus 2: The Grace That Trains Us', 'Read Titus 2. Titus is to teach what accords with sound doctrine, shaping every age and station: older men sober-minded and sound in faith, love, and steadfastness; older women reverent, not slanderers, teaching what is good and training the younger women to love their husbands and children; younger men self-controlled, with Titus himself a model of good works. All of it rests on grace. The grace of God has appeared, bringing salvation, and it trains us to renounce ungodliness and worldly passions and to live godly lives while we wait for our blessed hope. He gave himself to redeem us and purify a people zealous for good works.', 'Foundations of Faith', 'topic',
       ARRAY['titus', 'grace', 'self-control', 'blessed hope', 'sound doctrine']::text[], true, 50, 1
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Titus 2: The Grace That Trains Us');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'तीतुस 2: वह अनुग्रह जो हमें सिखाता है', 'तीतुस 2 पढ़ें। तीतुस वही सिखाए जो खरे सिद्धांत के अनुसार है, और जो हर आयु और हर स्थिति को गढ़ता है: बूढ़े पुरुष संयमी हों और विश्वास, प्रेम तथा धीरज में पक्के; बूढ़ी स्त्रियाँ आदर के योग्य चालचलनवाली हों, दोष लगानेवाली न हों, पर भली बातें सिखाएँ और जवान स्त्रियों को सिखाएँ कि वे अपने पतियों और बच्चों से प्रेम रखें; जवान पुरुष संयमी हों, और तीतुस स्वयं भले कामों का आदर्श हो। यह सब अनुग्रह पर टिका है। परमेश्वर का उद्धारदायक अनुग्रह प्रगट हुआ है, और वही हमें सिखाता है कि हम भक्तिहीनता और सांसारिक अभिलाषाओं से मन फेरकर भक्ति से जीवन बिताएँ, जब तक हम उस धन्य आशा की बाट जोहते हैं। उसने अपने आप को हमारे लिये दे दिया, कि हमें छुड़ा ले और भले कामों में सरगर्म एक निज लोग शुद्ध करे।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Titus 2: The Grace That Trains Us'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'തീത്തൊസ് 2: നമ്മെ അഭ്യസിപ്പിക്കുന്ന കൃപ', 'തീത്തൊസ് 2 വായിക്കുക. സത്യോപദേശത്തിനു യോജിച്ചതു പഠിപ്പിക്കേണ്ടതു തീത്തൊസിന്റെ കടമയാകുന്നു; അതു എല്ലാ പ്രായത്തെയും അവസ്ഥയെയും രൂപപ്പെടുത്തുന്നു: വൃദ്ധന്മാർ നിർമ്മദരും വിശ്വാസത്തിലും സ്നേഹത്തിലും ക്ഷമയിലും ആരോഗ്യമുള്ളവരും; വൃദ്ധമാർ ഭക്തിക്കു യോഗ്യമായ നടപ്പുള്ളവരും ഏഷണിക്കാരികളല്ലാത്തവരും നന്മ ഉപദേശിക്കുന്നവരും, യുവതികളെ ഭർത്താക്കന്മാരെയും മക്കളെയും സ്നേഹിപ്പാൻ അഭ്യസിപ്പിക്കുന്നവരും; യൗവനക്കാർ ജിതേന്ദ്രിയരും; തീത്തൊസ് തന്നേ സൽപ്രവൃത്തികളുടെ മാതൃകയും ആയിരിക്കണം. ഇതെല്ലാം കൃപയിലത്രേ അടിസ്ഥാനപ്പെട്ടിരിക്കുന്നു. രക്ഷാകരമായ ദൈവകൃപ പ്രത്യക്ഷമായി, ഭക്തികേടും ലൗകികമോഹങ്ങളും ത്യജിച്ചു, ധന്യമായ പ്രത്യാശയ്ക്കായി കാത്തിരിക്കുമ്പോൾ ദൈവഭക്തിയോടെ ജീവിപ്പാൻ അതു നമ്മെ അഭ്യസിപ്പിക്കുന്നു. നമ്മെ വീണ്ടെടുപ്പാനും സൽപ്രവൃത്തികളിൽ ശുഷ്കാന്തിയുള്ള ഒരു സ്വന്തജനത്തെ ശുദ്ധീകരിപ്പാനും അവൻ തന്നെത്താൻ ഏൽപ്പിച്ചുകൊടുത്തു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Titus 2: The Grace That Trains Us'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 1, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'titus-sound-doctrine-sound-living' AND rt.title = 'Titus 2: The Grace That Trains Us'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Titus 3: Saved by His Mercy, Devoted to Good Works', 'Read Titus 3. Believers are to submit to rulers, be ready for every good work, speak evil of no one, and show perfect courtesy, remembering that we ourselves were once foolish and disobedient. But when the goodness and loving kindness of God our Savior appeared, he saved us, not because of works done by us in righteousness, but according to his own mercy, by the washing of regeneration and renewal of the Holy Spirit. Justified by his grace, we became heirs of eternal life — and so believers devote themselves to good works, the fruit of that mercy.', 'Foundations of Faith', 'topic',
       ARRAY['titus', 'mercy', 'regeneration', 'justification', 'good works']::text[], true, 50, 2
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Titus 3: Saved by His Mercy, Devoted to Good Works');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'तीतुस 3: उसकी दया से उद्धार, भले कामों में लगन', 'तीतुस 3 पढ़ें। विश्वासी हाकिमों के अधीन रहें, हर भले काम के लिए तैयार रहें, किसी को बुरा न कहें, और सब के साथ पूरी नम्रता से पेश आएँ, यह स्मरण रखते हुए कि हम भी कभी निर्बुद्धि, आज्ञा न माननेवाले और भटके हुए थे। पर जब हमारे उद्धारकर्ता परमेश्वर की कृपा और मनुष्यों पर उसका प्रेम प्रगट हुआ, तो उसने हमें बचाया — उन धर्म के कामों के कारण नहीं जो हमने किए, पर अपनी ही दया के अनुसार, नए जन्म के स्नान और पवित्र आत्मा के द्वारा नया बनाए जाने से। उसके अनुग्रह से धर्मी ठहरकर हम अनन्त जीवन के वारिस हुए — और इसी दया के फल के रूप में विश्वासी भले कामों में लगे रहते हैं।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Titus 3: Saved by His Mercy, Devoted to Good Works'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'തീത്തൊസ് 3: അവന്റെ കരുണയാൽ രക്ഷ, സൽപ്രവൃത്തികളിൽ ഉത്സാഹം', 'തീത്തൊസ് 3 വായിക്കുക. വിശ്വാസികൾ അധികാരികൾക്കു കീഴടങ്ങുകയും എല്ലാ സൽപ്രവൃത്തിക്കും ഒരുങ്ങിയിരിക്കുകയും ആരെയും ദുഷിക്കാതെ എല്ലാവരോടും പൂർണ്ണസൗമ്യത കാണിക്കുകയും വേണം; നാമും ഒരുകാലത്തു ബുദ്ധിഹീനരും അനുസരണമില്ലാത്തവരും വഴിതെറ്റിയവരും ആയിരുന്നുവല്ലോ. എന്നാൽ നമ്മുടെ രക്ഷിതാവായ ദൈവത്തിന്റെ ദയയും മനുഷ്യപ്രീതിയും പ്രത്യക്ഷമായപ്പോൾ, നാം ചെയ്ത നീതിപ്രവൃത്തികളാലല്ല, തന്റെ കരുണപ്രകാരമത്രേ പുനർജനനസ്നാനത്താലും പരിശുദ്ധാത്മാവിന്റെ പുതുക്കത്താലും അവൻ നമ്മെ രക്ഷിച്ചു. അവന്റെ കൃപയാൽ നീതീകരിക്കപ്പെട്ടു നാം നിത്യജീവന്റെ അവകാശികളായി — ആ കരുണയുടെ ഫലമായി വിശ്വാസികൾ സൽപ്രവൃത്തികളിൽ ഉത്സാഹിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Titus 3: Saved by His Mercy, Devoted to Good Works'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 2, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'titus-sound-doctrine-sound-living' AND rt.title = 'Titus 3: Saved by His Mercy, Devoted to Good Works'
ON CONFLICT DO NOTHING;

-- ===== Philemon: A Brother, Not a Slave (1 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('philemon-forgiveness-and-reconciliation', 'Philemon: A Brother, Not a Slave', 'Philemon is Paul''s shortest letter and his most personal. Writing from prison, he pleads with a friend to welcome back Onesimus, a slave separated from him who has become a brother in Christ. Paul offers to pay whatever is owed. In one short chapter you will see how the gospel rewrites status, debt, and the costly work of forgiveness.',
        'family_restroom', '#C2410C', 50, 3,
        'follower', 'standard', false, 48, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', 'फिलेमोन: दास नहीं, भाई', 'फिलेमोन पौलुस की सबसे छोटी और सबसे व्यक्तिगत पत्री है। बंदीगृह से लिखते हुए वह अपने मित्र से विनती करता है कि वह उनेसिमुस को फिर से ग्रहण करे — वह दास जो उससे अलग हो गया था और अब मसीह में भाई बन गया है। पौलुस स्वयं उसका कर्ज चुकाने को तैयार है। इस एक ही अध्याय में आप देखेंगे कि सुसमाचार पद, कर्ज और क्षमा के कठिन काम को कैसे नया रूप देता है।'
  FROM public.learning_paths WHERE slug = 'philemon-forgiveness-and-reconciliation'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', 'ഫിലേമോൻ: ദാസനല്ല, സഹോദരൻ', 'പൗലോസിന്റെ ഏറ്റവും ചെറുതും ഏറ്റവും വ്യക്തിപരവുമായ ലേഖനമാണ് ഫിലേമോൻ. തടവിൽനിന്ന് എഴുതിക്കൊണ്ട്, തന്നിൽനിന്നു വേർപിരിഞ്ഞ ദാസനായിരുന്ന, ഇപ്പോൾ ക്രിസ്തുവിൽ സഹോദരനായിത്തീർന്ന ഒനേസിമൊസിനെ വീണ്ടും സ്വീകരിക്കാൻ അവൻ സ്നേഹിതനോട് അപേക്ഷിക്കുന്നു. കടമുള്ളതെന്തും താൻ വീട്ടാമെന്ന് പൗലോസ് ഏറ്റുപറയുന്നു. ഈ ഒരൊറ്റ അധ്യായത്തിൽ, സുവിശേഷം പദവിയെയും കടത്തെയും ക്ഷമയുടെ വിലയേറിയ പ്രവൃത്തിയെയും എങ്ങനെ പുതുക്കിയെഴുതുന്നു എന്ന് നിങ്ങൾ കാണും.'
  FROM public.learning_paths WHERE slug = 'philemon-forgiveness-and-reconciliation'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Philemon 1: Charge It to My Account', 'Read Philemon 1. Paul writes from prison to Philemon, Apphia, Archippus, and the church that meets in Philemon''s house. He thanks God for Philemon''s love and faith, and for how he has refreshed the hearts of the saints. Then he appeals: though bold enough to command, he asks for love''s sake instead. Onesimus, once useless to Philemon, has become Paul''s own child in the faith and is now useful. Receive him back, Paul says, no longer merely as a slave but as more than a slave, a beloved brother — and if he owes you anything, charge it to my account.', 'Foundations of Faith', 'topic',
       ARRAY['philemon', 'forgiveness', 'reconciliation', 'onesimus']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Philemon 1: Charge It to My Account');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'फिलेमोन 1: उसे मेरे नाम लिख लेना', 'फिलेमोन 1 पढ़ें। पौलुस बंदीगृह से फिलेमोन, अफफिया, अरखिप्पुस और उस कलीसिया को लिखता है जो फिलेमोन के घर में इकट्ठी होती है। वह फिलेमोन के प्रेम और विश्वास के लिये, और इसलिये भी कि उसने पवित्र लोगों के मन ताजे किए हैं, परमेश्वर का धन्यवाद करता है। फिर वह विनती करता है: यद्यपि वह आज्ञा देने का साहस रखता है, तौभी प्रेम के कारण वह निवेदन करना चुनता है। उनेसिमुस, जो पहले फिलेमोन के लिये निकम्मा था, अब पौलुस का आत्मिक पुत्र और काम का बन गया है। पौलुस कहता है — उसे फिर ग्रहण कर, अब केवल दास के समान नहीं पर दास से बढ़कर, प्रिय भाई के समान; और यदि उसने तेरा कुछ बिगाड़ा या वह तेरा कर्जदार हो, तो उसे मेरे नाम लिख ले।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Philemon 1: Charge It to My Account'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'ഫിലേമോൻ 1: അത് എന്റെ പേരിൽ കണക്കാക്കുക', 'ഫിലേമോൻ 1 വായിക്കുക. തടവിൽനിന്ന് പൗലോസ് ഫിലേമോനും അപ്ഫിയയ്ക്കും അർഹിപ്പൊസിനും ഫിലേമോന്റെ വീട്ടിൽ കൂടിവരുന്ന സഭയ്ക്കും എഴുതുന്നു. ഫിലേമോന്റെ സ്നേഹത്തിനും വിശ്വാസത്തിനും, വിശുദ്ധന്മാരുടെ ഹൃദയങ്ങളെ അവൻ തണുപ്പിച്ചതിനും ദൈവത്തിന് അവൻ നന്ദി പറയുന്നു. പിന്നെ അവൻ അപേക്ഷിക്കുന്നു: കല്പിക്കാൻ ധൈര്യമുണ്ടെങ്കിലും സ്നേഹം നിമിത്തം അവൻ യാചിക്കുന്നു. മുമ്പ് ഫിലേമോന് പ്രയോജനമില്ലാതിരുന്ന ഒനേസിമൊസ് ഇപ്പോൾ പൗലോസിന്റെ ആത്മീയപുത്രനും പ്രയോജനമുള്ളവനുമായി. അവനെ ഇനി കേവലം ദാസനായിട്ടല്ല, ദാസനിലുപരി പ്രിയ സഹോദരനായി സ്വീകരിക്കുക; അവൻ നിനക്ക് വല്ലതും കടമായിരുന്നാൽ അത് എന്റെ പേരിൽ കണക്കാക്കുക എന്ന് പൗലോസ് പറയുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Philemon 1: Charge It to My Account'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'philemon-forgiveness-and-reconciliation' AND rt.title = 'Philemon 1: Charge It to My Account'
ON CONFLICT DO NOTHING;

-- ===== Jude: Contend for the Faith (1 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('jude-contend-for-the-faith', 'Jude: Contend for the Faith', 'Jude wrote a short, urgent letter when false teachers slipped quietly into the churches. In a single chapter he calls you to contend earnestly for the faith once for all delivered to the saints, warns from history how God judges rebellion, and shows that grace is never a licence to sin. It closes with one of Scripture''s great doxologies: God is able to keep you from stumbling.',
        'shield', '#14B8A6', 50, 3,
        'disciple', 'standard', false, 49, 'Epistles', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', 'यहूदा: विश्वास के लिये पूरा यत्न करो', 'जब झूठे उपदेशक चुपके से कलीसियाओं में घुस आए, तब यहूदा ने यह छोटी पर अत्यावश्यक पत्री लिखी। एक ही अध्याय में वह तुम्हें बुलाता है कि उस विश्वास के लिये पूरा यत्न करो जो पवित्र लोगों को एक ही बार सौंपा गया था; वह इतिहास से चेतावनी देता है कि परमेश्वर विद्रोह का न्याय कैसे करता है, और दिखाता है कि अनुग्रह कभी पाप की छूट नहीं है। पत्री पवित्रशास्त्र की एक महान स्तुति से समाप्त होती है: परमेश्वर तुम्हें ठोकर खाने से बचा सकता है।'
  FROM public.learning_paths WHERE slug = 'jude-contend-for-the-faith'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', 'യൂദാ: വിശ്വാസത്തിനായി പോരാടുക', 'വ്യാജ ഉപദേഷ്ടാക്കന്മാർ സഭകളിലേക്ക് നുഴഞ്ഞുകയറിയപ്പോൾ യൂദാ എഴുതിയ ഹ്രസ്വവും അടിയന്തരവുമായ ലേഖനമാണിത്. ഒരൊറ്റ അധ്യായത്തിൽ, വിശുദ്ധന്മാർക്ക് ഒരിക്കലായി ഭരമേൽപ്പിക്കപ്പെട്ട വിശ്വാസത്തിനായി പോരാടുവാൻ അവൻ നിങ്ങളെ ആഹ്വാനം ചെയ്യുന്നു; മത്സരത്തെ ദൈവം എങ്ങനെ ന്യായംവിധിക്കുന്നു എന്ന് ചരിത്രത്തിൽനിന്ന് മുന്നറിയിപ്പു നൽകുന്നു; കൃപ ഒരിക്കലും പാപത്തിനുള്ള അനുമതിയല്ലെന്ന് കാണിക്കുന്നു. തിരുവെഴുത്തിലെ മഹത്തായ ഒരു സ്തുതിയോടെ ഇത് അവസാനിക്കുന്നു: ഇടറാതെ നിങ്ങളെ കാത്തുകൊള്ളുവാൻ ദൈവം ശക്തനാകുന്നു.'
  FROM public.learning_paths WHERE slug = 'jude-contend-for-the-faith'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Jude: Keep Yourselves in the Love of God', 'Read Jude. Jude meant to write about our common salvation, but urges instead that you contend earnestly for the faith once for all delivered to the saints. Certain people have crept in who pervert God''s grace into a licence for immorality and deny our only Master and Lord. Jude recalls God''s past judgements and calls these intruders waterless clouds. But you: build yourselves up in your most holy faith, pray in the Spirit, keep yourselves in the love of God, be merciful to doubters. He closes praising the One able to keep you from stumbling.', 'Foundations of Faith', 'topic',
       ARRAY['jude', 'contending', 'false teachers', 'perseverance']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Jude: Keep Yourselves in the Love of God');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'यहूदा: अपने आप को परमेश्वर के प्रेम में बनाए रखो', 'यहूदा पढ़ें। यहूदा हमारे साझे उद्धार के विषय में लिखना चाहता था, पर इसके बदले वह आग्रह करता है कि तुम उस विश्वास के लिये पूरा यत्न करो जो पवित्र लोगों को एक ही बार सौंपा गया था। कुछ लोग चुपके से घुस आए हैं जो परमेश्वर के अनुग्रह को लुचपन की छूट में बदल देते हैं और हमारे एकमात्र स्वामी और प्रभु का इन्कार करते हैं। यहूदा परमेश्वर के पिछले न्यायों को स्मरण दिलाता है और इन उपदेशकों को बिन पानी के बादल कहता है। पर तुम अपने अति पवित्र विश्वास में अपनी उन्नति करते हुए, पवित्र आत्मा में प्रार्थना करते हुए, अपने आप को परमेश्वर के प्रेम में बनाए रखो, और सन्देह करनेवालों पर दया करो। वह उसकी स्तुति करते हुए पत्री समाप्त करता है जो तुम्हें ठोकर खाने से बचा सकता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Jude: Keep Yourselves in the Love of God'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'യൂദാ: ദൈവസ്നേഹത്തിൽ നിങ്ങളെത്തന്നെ കാത്തുകൊൾവിൻ', 'യൂദാ വായിക്കുക. നമ്മുടെ പൊതുവായ രക്ഷയെക്കുറിച്ച് എഴുതുവാൻ യൂദാ ഉദ്ദേശിച്ചിരുന്നു; എന്നാൽ വിശുദ്ധന്മാർക്ക് ഒരിക്കലായി ഭരമേൽപ്പിക്കപ്പെട്ട വിശ്വാസത്തിനായി പോരാടുവാൻ അവൻ പകരം പ്രബോധിപ്പിക്കുന്നു. ദൈവകൃപയെ ദുർന്നടപ്പിനുള്ള അനുമതിയാക്കി മാറ്റുകയും നമ്മുടെ ഏക നാഥനും കർത്താവുമായവനെ നിഷേധിക്കുകയും ചെയ്യുന്ന ചിലർ നുഴഞ്ഞുകയറിയിരിക്കുന്നു. ദൈവത്തിന്റെ പൂർവകാല ന്യായവിധികൾ അനുസ്മരിച്ച്, ഈ ഉപദേഷ്ടാക്കന്മാരെ വെള്ളമില്ലാത്ത മേഘങ്ങൾ എന്ന് അവൻ വിളിക്കുന്നു. നിങ്ങളോ, നിങ്ങളുടെ അതിവിശുദ്ധ വിശ്വാസത്തിൽ നിങ്ങളെത്തന്നെ ആത്മികവർധന വരുത്തി, പരിശുദ്ധാത്മാവിൽ പ്രാർഥിച്ച്, ദൈവസ്നേഹത്തിൽ നിങ്ങളെത്തന്നെ കാത്തുകൊൾവിൻ; സംശയിക്കുന്നവരോട് കരുണ കാണിക്കുവിൻ. ഇടറാതെ നിങ്ങളെ കാത്തുകൊള്ളുവാൻ ശക്തനായവനെ സ്തുതിച്ചുകൊണ്ട് അവൻ ഉപസംഹരിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Jude: Keep Yourselves in the Love of God'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'jude-contend-for-the-faith' AND rt.title = 'Jude: Keep Yourselves in the Love of God'
ON CONFLICT DO NOTHING;

-- ===== Revelation: The Lamb Who Reigns (22 chapters) =====

INSERT INTO public.learning_paths
  (slug, title, description, icon_name, color, total_xp, estimated_days,
   disciple_level, recommended_mode, is_featured, display_order, category, is_active)
VALUES ('revelation-the-lamb-who-reigns', 'Revelation: The Lamb Who Reigns', 'Written to seven pressured churches in Asia, Revelation unveils the risen Christ who walks among his people and the Lamb who was slain yet reigns. Across twenty-two chapters John sees the throne of God, seals, trumpets, beasts and bowls, and at last a new heaven and earth where God dwells with his people. Christians have long read its symbols differently; its call never changes — worship God, and endure faithfully.',
        'visibility', '#7F1D1D', 1100, 44,
        'disciple', 'standard', false, 50, 'Theology', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'hi', 'प्रकाशितवाक्य: राज्य करनेवाला मेम्ना', 'कठिनाई झेलती आसिया की सात कलीसियाओं को लिखी गई प्रकाशितवाक्य उस जीवित मसीह को प्रकट करती है जो अपने लोगों के बीच चलता है, और उस मेम्ने को जो वध किया गया तौभी राज्य करता है। बाईस अध्यायों में यूहन्ना परमेश्वर का सिंहासन, मुहरें, तुरहियाँ, पशु और कटोरे, और अंत में नया आकाश और नई पृथ्वी देखता है जहाँ परमेश्वर अपने लोगों के साथ वास करता है। मसीही लोग इसके प्रतीकों को भिन्न-भिन्न रूप से पढ़ते आए हैं; पर इसका आह्वान कभी नहीं बदलता — परमेश्वर की आराधना करो और विश्वासयोग्य होकर धीरज धरो।'
  FROM public.learning_paths WHERE slug = 'revelation-the-lamb-who-reigns'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'ml', 'വെളിപ്പാട്: വാഴുന്ന കുഞ്ഞാട്', 'ഞെരുക്കത്തിലായിരുന്ന ആസ്യയിലെ ഏഴു സഭകൾക്ക് എഴുതപ്പെട്ട വെളിപ്പാട്, തന്റെ ജനത്തിന്റെ നടുവിൽ നടക്കുന്ന ഉയിർത്തെഴുന്നേറ്റ ക്രിസ്തുവിനെയും, അറുക്കപ്പെട്ടിട്ടും വാഴുന്ന കുഞ്ഞാടിനെയും വെളിപ്പെടുത്തുന്നു. ഇരുപത്തിരണ്ട് അധ്യായങ്ങളിൽ യോഹന്നാൻ ദൈവത്തിന്റെ സിംഹാസനവും മുദ്രകളും കാഹളങ്ങളും മൃഗങ്ങളും കലശങ്ങളും, ഒടുവിൽ ദൈവം തന്റെ ജനത്തോടുകൂടെ വസിക്കുന്ന പുതിയ ആകാശവും പുതിയ ഭൂമിയും കാണുന്നു. ഈ ചിഹ്നങ്ങളെ ക്രിസ്ത്യാനികൾ പലവിധത്തിൽ വായിച്ചിട്ടുണ്ട്; എന്നാൽ അതിന്റെ വിളി ഒരിക്കലും മാറുന്നില്ല — ദൈവത്തെ ആരാധിക്കുക, വിശ്വസ്തതയോടെ സഹിച്ചുനിൽക്കുക.'
  FROM public.learning_paths WHERE slug = 'revelation-the-lamb-who-reigns'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 1: The Risen Christ Among the Lampstands', 'Read Revelation 1. John, exiled on Patmos for the word of God, writes what he sees to seven churches in Asia. He greets them from the God who is and who was and who is to come, and from Jesus Christ the faithful witness, the firstborn of the dead, who freed us from our sins by his blood. Turning, John sees the risen Christ walking among seven golden lampstands, eyes like flame, voice like many waters. He falls as dead; Christ lays a hand on him: Fear not, I am the first and the last, the living one.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'risen christ', 'lampstands', 'patmos']::text[], true, 50, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 1: The Risen Christ Among the Lampstands');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 1: दीवटों के बीच जीवित मसीह', 'प्रकाशितवाक्य 1 पढ़ें। परमेश्वर के वचन के कारण पतमुस द्वीप पर निर्वासित यूहन्ना जो कुछ देखता है वह आसिया की सात कलीसियाओं को लिखता है। वह उन्हें उस परमेश्वर की ओर से नमस्कार करता है जो है, जो था और जो आनेवाला है, और यीशु मसीह की ओर से, जो विश्वासयोग्य साक्षी, मरे हुओं में पहलौठा और पृथ्वी के राजाओं का अधिपति है, जिसने अपने लहू से हमें पापों से छुड़ाया। मुड़कर यूहन्ना जीवित मसीह को सात सोने के दीवटों के बीच चलते देखता है — आँखें आग की ज्वाला सी, शब्द बहुत जल की धारा सा। वह मरे हुए समान गिर पड़ता है, और मसीह उस पर हाथ रखकर कहता है: मत डर, मैं प्रथम और अंतिम और जीवित हूँ।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 1: The Risen Christ Among the Lampstands'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 1: നിലവിളക്കുകളുടെ നടുവിൽ ഉയിർത്ത ക്രിസ്തു', 'വെളിപ്പാട് 1 വായിക്കുക. ദൈവവചനം നിമിത്തം പത്മൊസ് ദ്വീപിൽ നാടുകടത്തപ്പെട്ട യോഹന്നാൻ താൻ കാണുന്നത് ആസ്യയിലെ ഏഴു സഭകൾക്ക് എഴുതുന്നു. ഇരിക്കുന്നവനും ഇരുന്നവനും വരുന്നവനുമായ ദൈവത്തിൽനിന്നും, വിശ്വസ്ത സാക്ഷിയും മരിച്ചവരിൽ ആദ്യജാതനും ഭൂരാജാക്കന്മാരുടെ അധിപതിയുമായി സ്വന്തരക്തത്താൽ നമ്മെ പാപങ്ങളിൽനിന്നു വിടുവിച്ച യേശുക്രിസ്തുവിൽനിന്നും അവൻ അവരെ അഭിവാദ്യം ചെയ്യുന്നു. തിരിഞ്ഞുനോക്കിയപ്പോൾ ഏഴു പൊൻനിലവിളക്കുകളുടെ നടുവിൽ നടക്കുന്ന ഉയിർത്തെഴുന്നേറ്റ ക്രിസ്തുവിനെ അവൻ കാണുന്നു — കണ്ണുകൾ അഗ്നിജ്വാലപോലെ, ശബ്ദം പെരുവെള്ളത്തിന്റെ ഇരച്ചിൽപോലെ. അവൻ മരിച്ചവനെപ്പോലെ വീഴുന്നു; ക്രിസ്തു കൈവെച്ചു പറയുന്നു: ഭയപ്പെടേണ്ട, ഞാൻ ആദ്യനും അന്ത്യനും ജീവിക്കുന്നവനും ആകുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 1: The Risen Christ Among the Lampstands'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 0, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 1: The Risen Christ Among the Lampstands'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 2: Letters to Ephesus, Smyrna, Pergamum and Thyatira', 'Read Revelation 2. Christ addresses four churches, each time saying, I know your works. Ephesus is commended for labour and discernment but has abandoned its first love and must repent. Smyrna is poor yet rich, facing prison and testing, and is told to be faithful unto death. Pergamum holds fast his name where Satan''s throne is, yet tolerates the teaching of Balaam. Thyatira grows in love and service but tolerates a false prophetess. To everyone who conquers he promises the tree of life, escape from the second death, hidden manna and the morning star.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'seven churches', 'repentance', 'endurance']::text[], true, 50, 1
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 2: Letters to Ephesus, Smyrna, Pergamum and Thyatira');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 2: इफिसुस, स्मुरना, पिरगमुन और थुआतीरा के नाम पत्र', 'प्रकाशितवाक्य 2 पढ़ें। मसीह चार कलीसियाओं से बात करता है, और हर बार कहता है, मैं तेरे कामों को जानता हूँ। इफिसुस के परिश्रम और परख की प्रशंसा होती है, पर उसने अपना पहला प्रेम छोड़ दिया है और उसे मन फिराना है। स्मुरना कंगाल है तौभी धनी है; बंदीगृह और परीक्षा उसके सामने है, और उससे कहा जाता है कि मरने तक विश्वासयोग्य रह। पिरगमुन शैतान के सिंहासन के स्थान में भी मसीह का नाम थामे है, फिर भी बिलाम की शिक्षा सहता है। थुआतीरा प्रेम और सेवा में बढ़ता है, पर एक झूठी भविष्यद्वक्तिन को सहता है। हर जय पानेवाले को वह जीवन का वृक्ष, दूसरी मृत्यु से बचाव, छिपा हुआ मन्ना और भोर का तारा देने की प्रतिज्ञा करता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 2: Letters to Ephesus, Smyrna, Pergamum and Thyatira'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 2: എഫെസൊസ്, സ്മുർന്ന, പെർഗ്ഗമൊസ്, തുയഥൈര എന്നിവർക്കുള്ള ലേഖനങ്ങൾ', 'വെളിപ്പാട് 2 വായിക്കുക. ക്രിസ്തു നാലു സഭകളോടു സംസാരിക്കുന്നു; ഓരോ പ്രാവശ്യവും, ഞാൻ നിന്റെ പ്രവൃത്തികൾ അറിയുന്നു എന്നു പറയുന്നു. അധ്വാനത്തിനും വിവേചനത്തിനും എഫെസൊസ് പ്രശംസിക്കപ്പെടുന്നു, എങ്കിലും ആദ്യസ്നേഹം വിട്ടുകളഞ്ഞതിനാൽ മാനസാന്തരപ്പെടേണം. സ്മുർന്ന ദരിദ്രമെങ്കിലും സമ്പന്നമാണ്; തടവും പരീക്ഷയും മുന്നിലുണ്ട്, മരണപര്യന്തം വിശ്വസ്തനായിരിക്കുക എന്ന് അതിനോടു പറയുന്നു. സാത്താന്റെ സിംഹാസനമുള്ളിടത്തും പെർഗ്ഗമൊസ് അവന്റെ നാമം മുറുകെ പിടിക്കുന്നു, എങ്കിലും ബിലെയാമിന്റെ ഉപദേശം സഹിക്കുന്നു. തുയഥൈര സ്നേഹത്തിലും ശുശ്രൂഷയിലും വളരുന്നു, എങ്കിലും ഒരു കള്ളപ്രവാചകിയെ സഹിക്കുന്നു. ജയിക്കുന്ന ഏവർക്കും ജീവവൃക്ഷവും രണ്ടാം മരണത്തിൽനിന്നുള്ള വിടുതലും മറഞ്ഞിരിക്കുന്ന മന്നയും ഉദയനക്ഷത്രവും അവൻ വാഗ്ദാനം ചെയ്യുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 2: Letters to Ephesus, Smyrna, Pergamum and Thyatira'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 1, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 2: Letters to Ephesus, Smyrna, Pergamum and Thyatira'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 3: Letters to Sardis, Philadelphia and Laodicea', 'Read Revelation 3. Sardis has a reputation for being alive but is dead; it must wake up and strengthen what remains, though a few have not soiled their garments. Philadelphia has little power yet has kept his word, and Christ sets before it an open door no one can shut, promising to make the conqueror a pillar in God''s temple. Laodicea, lukewarm and self-satisfied, thinks it is rich but is wretched, poor, blind and naked. Christ counsels it to buy gold refined by fire, and stands at the door and knocks.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'seven churches', 'sardis', 'laodicea']::text[], true, 50, 2
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 3: Letters to Sardis, Philadelphia and Laodicea');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 3: सरदीस, फिलदिलफिया और लौदीकिया के नाम पत्र', 'प्रकाशितवाक्य 3 पढ़ें। सरदीस की ख्याति तो जीवित होने की है, पर वह मरा हुआ है; उसे जागना और जो बचा है उसे दृढ़ करना है, यद्यपि कुछ ऐसे हैं जिन्होंने अपने वस्त्र दूषित नहीं किए। फिलदिलफिया में सामर्थ्य थोड़ी है, फिर भी उसने मसीह का वचन थामा है; इसलिए मसीह उसके सामने एक खुला द्वार रखता है जिसे कोई बंद नहीं कर सकता, और जय पानेवाले को परमेश्वर के मंदिर में खंभा बनाने की प्रतिज्ञा करता है। लौदीकिया गुनगुना और आत्मसंतुष्ट है; वह अपने को धनी समझता है, पर अभागा, कंगाल, अंधा और नंगा है। मसीह उसे आग में तपाया हुआ सोना मोल लेने की सलाह देता है, और द्वार पर खड़ा होकर खटखटाता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 3: Letters to Sardis, Philadelphia and Laodicea'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 3: സർദ്ദിസ്, ഫിലദെൽഫ്യ, ലവൊദിക്യ എന്നിവർക്കുള്ള ലേഖനങ്ങൾ', 'വെളിപ്പാട് 3 വായിക്കുക. ജീവനുള്ളവൻ എന്ന പേര് സർദ്ദിസിനുണ്ട്, എന്നാൽ അത് മരിച്ചിരിക്കുന്നു; ഉണർന്ന് ശേഷിച്ചവയെ ഉറപ്പിക്കേണം — വസ്ത്രം മലിനമാക്കാത്ത ചിലരും അവിടെയുണ്ട്. ഫിലദെൽഫ്യക്ക് ശക്തി അല്പമേയുള്ളൂ, എങ്കിലും അത് അവന്റെ വചനം കാത്തു; അതുകൊണ്ട് ആർക്കും അടയ്ക്കാനാവാത്ത ഒരു വാതിൽ ക്രിസ്തു അതിന്റെ മുമ്പിൽ തുറന്നുവെക്കുന്നു, ജയിക്കുന്നവനെ ദൈവാലയത്തിൽ ഒരു തൂണാക്കുമെന്നു വാഗ്ദാനം ചെയ്യുന്നു. ലവൊദിക്യ ശീതവുമല്ല ഉഷ്ണവുമല്ല, സ്വയം തൃപ്തമാണ്; താൻ സമ്പന്നൻ എന്നു കരുതുന്നു, എന്നാൽ നിർഭാഗ്യനും ദരിദ്രനും കുരുടനും നഗ്നനുമാകുന്നു. തീയിൽ ഊതിക്കഴിച്ച പൊന്ന് വാങ്ങുവാൻ ക്രിസ്തു ഉപദേശിക്കുന്നു, വാതില്ക്കൽ നിന്നു മുട്ടുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 3: Letters to Sardis, Philadelphia and Laodicea'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 2, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 3: Letters to Sardis, Philadelphia and Laodicea'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 4: The Throne Room of Heaven', 'Read Revelation 4. A door stands open in heaven and John is called up to see what must take place. At the centre is a throne, and on it One whose appearance is like jasper and carnelian, encircled by a rainbow. Around the throne are twenty-four elders in white with golden crowns, seven torches burning, and a sea of glass. Four living creatures never cease to say, Holy, holy, holy is the Lord God Almighty. The elders fall down and cast their crowns before him, for he created all things. Before any judgment is described, heaven is worshipping.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'throne', 'worship', 'creation']::text[], true, 50, 3
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 4: The Throne Room of Heaven');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 4: स्वर्ग का सिंहासन-कक्ष', 'प्रकाशितवाक्य 4 पढ़ें। स्वर्ग में एक द्वार खुला है और यूहन्ना ऊपर बुलाया जाता है कि देखे जो होनेवाला है। केंद्र में एक सिंहासन है, और उस पर एक विराजमान है जिसका रूप यशब और गोमेद सा है, और चारों ओर मेघधनुष है। सिंहासन के चारों ओर श्वेत वस्त्र और सोने के मुकुट पहने चौबीस प्राचीन हैं, सात दीपक जल रहे हैं, और काँच का समुद्र है। चार प्राणी लगातार कहते हैं, पवित्र, पवित्र, पवित्र प्रभु परमेश्वर सर्वशक्तिमान। प्राचीन गिरकर अपने मुकुट उसके सामने डाल देते हैं, क्योंकि उसी ने सब कुछ सृजा। किसी भी दंड के वर्णन से पहले स्वर्ग आराधना कर रहा है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 4: The Throne Room of Heaven'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 4: സ്വർഗ്ഗത്തിലെ സിംഹാസനമുറി', 'വെളിപ്പാട് 4 വായിക്കുക. സ്വർഗ്ഗത്തിൽ ഒരു വാതിൽ തുറന്നുകിടക്കുന്നു; സംഭവിക്കാനുള്ളത് കാണ്മാൻ യോഹന്നാൻ മുകളിലേക്കു വിളിക്കപ്പെടുന്നു. നടുവിൽ ഒരു സിംഹാസനം; അതിൽ ഇരിക്കുന്നവന്റെ രൂപം സൂര്യകാന്തത്തിനും ചുവന്ന രത്നത്തിനും സമം, ചുറ്റും ഒരു മഴവില്ല്. സിംഹാസനത്തിനു ചുറ്റും വെള്ളവസ്ത്രവും പൊൻകിരീടവും ധരിച്ച ഇരുപത്തിനാലു മൂപ്പന്മാർ, കത്തുന്ന ഏഴു ദീപങ്ങൾ, സ്ഫടികക്കടൽ. നാലു ജീവികൾ ഇടവിടാതെ പറയുന്നു: പരിശുദ്ധൻ, പരിശുദ്ധൻ, പരിശുദ്ധൻ, സർവ്വശക്തനായ കർത്താവായ ദൈവം. മൂപ്പന്മാർ വീണു തങ്ങളുടെ കിരീടങ്ങൾ അവന്റെ മുമ്പിൽ ഇടുന്നു, എല്ലാം സൃഷ്ടിച്ചത് അവനത്രേ. ഒരു ന്യായവിധിയും വർണ്ണിക്കുംമുമ്പേ സ്വർഗ്ഗം ആരാധിക്കുകയാണ്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 4: The Throne Room of Heaven'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 3, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 4: The Throne Room of Heaven'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 5: The Lamb Who Was Slain Takes the Scroll', 'Read Revelation 5. In the right hand of the One on the throne is a sealed scroll, and no one in heaven or on earth is worthy to open it. John weeps until an elder says, Do not weep; the Lion of the tribe of Judah, the Root of David, has conquered. Then John sees a Lamb standing as though slain, who takes the scroll. The living creatures and elders sing a new song: you were slain and by your blood ransomed people from every tribe and tongue. Every creature joins the praise. He conquered by dying.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'lamb', 'scroll', 'worship']::text[], true, 50, 4
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 5: The Lamb Who Was Slain Takes the Scroll');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 5: वध किया हुआ मेम्ना पुस्तक लेता है', 'प्रकाशितवाक्य 5 पढ़ें। सिंहासन पर बैठे हुए के दाहिने हाथ में मुहर लगी हुई एक पुस्तक है, और स्वर्ग या पृथ्वी पर कोई उसे खोलने के योग्य नहीं मिलता। यूहन्ना रोने लगता है, तब एक प्राचीन कहता है, मत रो; यहूदा के गोत्र का सिंह, दाऊद का मूल, जय पा चुका है। यूहन्ना देखता है और एक मेम्ना खड़ा दिखाई देता है, मानो वध किया गया हो; वही पुस्तक लेता है। प्राणी और प्राचीन एक नया गीत गाते हैं: तू वध हुआ और अपने लहू से हर एक कुल और भाषा में से लोगों को मोल लिया। हर एक प्राणी स्तुति में सम्मिलित होता है। उसने मरकर जय पाई।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 5: The Lamb Who Was Slain Takes the Scroll'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 5: അറുക്കപ്പെട്ട കുഞ്ഞാട് ചുരുൾ ഏറ്റുവാങ്ങുന്നു', 'വെളിപ്പാട് 5 വായിക്കുക. സിംഹാസനത്തിൽ ഇരിക്കുന്നവന്റെ വലങ്കയ്യിൽ മുദ്രയിട്ട ഒരു ചുരുളുണ്ട്; അതു തുറപ്പാൻ യോഗ്യനായി സ്വർഗ്ഗത്തിലും ഭൂമിയിലും ആരെയും കാണുന്നില്ല. യോഹന്നാൻ കരയുമ്പോൾ ഒരു മൂപ്പൻ പറയുന്നു: കരയേണ്ട, യെഹൂദാഗോത്രത്തിലെ സിംഹം, ദാവീദിന്റെ വേര്, ജയിച്ചിരിക്കുന്നു. നോക്കിയപ്പോൾ അറുക്കപ്പെട്ടതുപോലെ നില്ക്കുന്ന ഒരു കുഞ്ഞാടിനെ അവൻ കാണുന്നു; അവൻ ചുരുൾ ഏറ്റുവാങ്ങുന്നു. ജീവികളും മൂപ്പന്മാരും പുതിയൊരു പാട്ടു പാടുന്നു: നീ അറുക്കപ്പെട്ടു, നിന്റെ രക്തത്താൽ സകല ഗോത്രത്തിൽനിന്നും ഭാഷയിൽനിന്നും മനുഷ്യരെ വിലയ്ക്കു വാങ്ങി. സകല സൃഷ്ടിയും സ്തുതിയിൽ ചേരുന്നു. അവൻ ജയിച്ചത് മരിച്ചുകൊണ്ടാണ്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 5: The Lamb Who Was Slain Takes the Scroll'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 4, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 5: The Lamb Who Was Slain Takes the Scroll'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 6: The Opening of the Seals', 'Read Revelation 6. The Lamb opens the first six seals. Four horsemen ride out — conquest, the removal of peace, scarcity that spares oil and wine, and death that follows after. Under the fifth seal the souls of those slain for the word of God cry, How long, O Lord? They are given white robes and told to rest a little longer. At the sixth seal the sun darkens, stars fall, and the powerful of the earth hide and ask who can stand. Christians differ over what these seals picture; all agree the Lamb holds the scroll.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'seals', 'judgment', 'martyrs']::text[], true, 50, 5
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 6: The Opening of the Seals');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 6: मुहरों का खोला जाना', 'प्रकाशितवाक्य 6 पढ़ें। मेम्ना सात में से छह मुहरें खोलता है। चार घुड़सवार निकलते हैं — विजय, शांति का उठा लिया जाना, वह अकाल जो तेल और दाखरस को छोड़ देता है, और उनके पीछे आती हुई मृत्यु। पाँचवीं मुहर के नीचे उनके प्राण जो परमेश्वर के वचन के कारण मारे गए थे पुकारते हैं, हे प्रभु, कब तक? उन्हें श्वेत वस्त्र दिए जाते हैं और थोड़ी देर और विश्राम करने को कहा जाता है। छठी मुहर पर सूर्य अंधियारा हो जाता है, तारे गिरते हैं, और पृथ्वी के बड़े लोग छिपकर पूछते हैं कि कौन ठहर सकता है। मसीही लोग इन मुहरों के अर्थ पर भिन्न मत रखते हैं; पर सब मानते हैं कि पुस्तक अराजकता के नहीं, मेम्ने के हाथ में है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 6: The Opening of the Seals'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 6: മുദ്രകൾ തുറക്കപ്പെടുന്നു', 'വെളിപ്പാട് 6 വായിക്കുക. ഏഴിൽ ആറു മുദ്രകൾ കുഞ്ഞാട് തുറക്കുന്നു. നാലു കുതിരക്കാർ പുറപ്പെടുന്നു — ജയം, സമാധാനം എടുത്തുകളയൽ, എണ്ണയും വീഞ്ഞും ഒഴിവാക്കുന്ന ക്ഷാമം, പിന്നാലെ വരുന്ന മരണം. അഞ്ചാം മുദ്രയിൽ ദൈവവചനം നിമിത്തം കൊല്ലപ്പെട്ടവരുടെ ആത്മാക്കൾ നിലവിളിക്കുന്നു: കർത്താവേ, എത്രത്തോളം? അവർക്കു വെള്ളനിലയങ്കി നല്കി അല്പകാലംകൂടെ വിശ്രമിപ്പാൻ പറയുന്നു. ആറാം മുദ്രയിൽ സൂര്യൻ ഇരുണ്ടു, നക്ഷത്രങ്ങൾ വീഴുന്നു, ഭൂമിയിലെ വലിയവർ ഒളിച്ച്, ആർക്കു നില്പാൻ കഴിയും എന്നു ചോദിക്കുന്നു. ഈ മുദ്രകൾ എന്തിനെ ചിത്രീകരിക്കുന്നു എന്നതിൽ ക്രിസ്ത്യാനികൾ വ്യത്യസ്തരാണ്; എന്നാൽ ചുരുൾ കുഴപ്പത്തിന്റെയല്ല, കുഞ്ഞാടിന്റെ കയ്യിലാണെന്ന് എല്ലാവരും സമ്മതിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 6: The Opening of the Seals'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 5, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 6: The Opening of the Seals'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 7: The Sealed and the Countless Multitude', 'Read Revelation 7. Before the seventh seal, four angels hold back the winds until the servants of God are sealed on their foreheads — a hundred and forty-four thousand from the tribes of Israel. Then John sees a great multitude no one could number, from every nation, tribe, people and language, standing before the throne in white robes with palm branches, crying, Salvation belongs to our God and to the Lamb. They have washed their robes in the blood of the Lamb. God shelters them; the Lamb shepherds them and wipes every tear from their eyes.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'sealed', 'multitude', 'nations']::text[], true, 50, 6
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 7: The Sealed and the Countless Multitude');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 7: मुहर लगे हुए और अनगिनत भीड़', 'प्रकाशितवाक्य 7 पढ़ें। सातवीं मुहर से पहले चार स्वर्गदूत हवाओं को थामे रहते हैं जब तक परमेश्वर के दासों के माथे पर मुहर न लग जाए — इस्राएल के गोत्रों में से एक लाख चौवालीस हजार। फिर यूहन्ना एक बड़ी भीड़ देखता है जिसे कोई गिन नहीं सकता, हर एक जाति, कुल, लोग और भाषा में से, जो श्वेत वस्त्र पहने और खजूर की डालियाँ लिए सिंहासन के सामने खड़ी है और पुकारती है, उद्धार हमारे परमेश्वर का और मेम्ने का है। उन्होंने अपने वस्त्र मेम्ने के लहू में धोए हैं। परमेश्वर उन पर तम्बू तानता है; मेम्ना उनकी रखवाली करता है और उनकी आँखों से हर एक आँसू पोंछ देता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 7: The Sealed and the Countless Multitude'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 7: മുദ്രയിട്ടവരും എണ്ണമറ്റ പുരുഷാരവും', 'വെളിപ്പാട് 7 വായിക്കുക. ഏഴാം മുദ്രയ്ക്കുമുമ്പ്, ദൈവദാസന്മാരുടെ നെറ്റിയിൽ മുദ്രയിടുവോളം നാലു ദൂതന്മാർ കാറ്റുകളെ പിടിച്ചുനിർത്തുന്നു — യിസ്രായേൽ ഗോത്രങ്ങളിൽനിന്ന് ലക്ഷത്തിനാല്പത്തിനാലായിരം. പിന്നെ ആർക്കും എണ്ണാൻ കഴിയാത്ത ഒരു മഹാപുരുഷാരത്തെ യോഹന്നാൻ കാണുന്നു — സകല ജാതിയിലും ഗോത്രത്തിലും വംശത്തിലും ഭാഷയിലുംനിന്നുള്ളവർ, വെള്ളനിലയങ്കി ധരിച്ച്, കുരുത്തോലകളുമായി സിംഹാസനത്തിനു മുമ്പിൽ നിന്ന് ആർക്കുന്നു: രക്ഷ നമ്മുടെ ദൈവത്തിനും കുഞ്ഞാടിനും. അവർ തങ്ങളുടെ വസ്ത്രം കുഞ്ഞാടിന്റെ രക്തത്തിൽ കഴുകിയിരിക്കുന്നു. ദൈവം അവരുടെമേൽ കൂടാരം വിരിക്കുന്നു; കുഞ്ഞാട് അവരെ മേയിക്കുകയും കണ്ണീരെല്ലാം തുടയ്ക്കുകയും ചെയ്യുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 7: The Sealed and the Countless Multitude'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 6, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 7: The Sealed and the Countless Multitude'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 8: The Seventh Seal and the First Trumpets', 'Read Revelation 8. When the Lamb opens the seventh seal there is silence in heaven for about half an hour. Seven angels are given trumpets, and another angel offers incense with the saints'' prayers on the golden altar; the smoke rises before God, and fire from the altar is thrown to the earth. Then four trumpets sound, and a third of the land, the sea, the fresh waters and the lights of the sky is struck. An eagle cries woe over those who dwell on the earth. Notice first: the prayers of ordinary believers are heard in heaven.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'seventh seal', 'trumpets', 'prayer']::text[], true, 50, 7
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 8: The Seventh Seal and the First Trumpets');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 8: सातवीं मुहर और पहली तुरहियाँ', 'प्रकाशितवाक्य 8 पढ़ें। जब मेम्ना सातवीं मुहर खोलता है तो स्वर्ग में लगभग आधे घंटे तक सन्नाटा छा जाता है। सात स्वर्गदूतों को तुरहियाँ दी जाती हैं, और एक अन्य स्वर्गदूत सोने की वेदी पर सब पवित्र लोगों की प्रार्थनाओं के साथ धूप चढ़ाता है; धुआँ परमेश्वर के सामने ऊपर उठता है, और वेदी की आग पृथ्वी पर डाली जाती है। फिर चार तुरहियाँ फूँकी जाती हैं, और पृथ्वी, समुद्र, मीठे जल और आकाश की ज्योतियों का तिहाई भाग मारा जाता है। एक उकाब पृथ्वी के निवासियों पर हाय पुकारता है। सबसे पहले यह देखिए: साधारण विश्वासियों की प्रार्थनाएँ स्वर्ग में सुनी जाती हैं।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 8: The Seventh Seal and the First Trumpets'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 8: ഏഴാം മുദ്രയും ആദ്യകാഹളങ്ങളും', 'വെളിപ്പാട് 8 വായിക്കുക. കുഞ്ഞാട് ഏഴാം മുദ്ര തുറക്കുമ്പോൾ ഏകദേശം അരമണിക്കൂർ സ്വർഗ്ഗത്തിൽ മൗനമുണ്ടാകുന്നു. ഏഴു ദൂതന്മാർക്കു കാഹളങ്ങൾ ലഭിക്കുന്നു; മറ്റൊരു ദൂതൻ പൊൻയാഗപീഠത്തിന്മേൽ സകല വിശുദ്ധരുടെയും പ്രാർത്ഥനകളോടുകൂടെ ധൂപം അർപ്പിക്കുന്നു; പുക ദൈവസന്നിധിയിൽ ഉയരുന്നു, യാഗപീഠത്തിലെ തീ ഭൂമിയിലേക്ക് എറിയപ്പെടുന്നു. പിന്നെ നാലു കാഹളങ്ങൾ മുഴങ്ങുന്നു; കരയുടെയും കടലിന്റെയും ശുദ്ധജലത്തിന്റെയും ആകാശജ്യോതിസ്സുകളുടെയും മൂന്നിലൊന്ന് അടിക്കപ്പെടുന്നു. ഒരു കഴുകൻ ഭൂവാസികളുടെമേൽ കഷ്ടം എന്നു വിളിച്ചുപറയുന്നു. ആദ്യം ഇതു ശ്രദ്ധിക്കുക: സാധാരണ വിശ്വാസികളുടെ പ്രാർത്ഥനകൾ സ്വർഗ്ഗത്തിൽ കേൾക്കപ്പെടുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 8: The Seventh Seal and the First Trumpets'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 7, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 8: The Seventh Seal and the First Trumpets'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 9: The Locusts and the Horsemen', 'Read Revelation 9. The fifth trumpet opens the shaft of the bottomless pit, and out of the smoke come locusts with power like scorpions. They may not harm the grass or those sealed by God, and they may not kill, only torment for five months; their king is called Destroyer. The sixth trumpet releases four angels at the Euphrates and an immense army of horsemen, and a third of mankind is killed. Yet the rest do not repent of their idols, murders, sorceries, immorality or thefts. Even under judgment, God''s aim is repentance, and hard hearts refuse it.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'trumpets', 'judgment', 'repentance']::text[], true, 50, 8
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 9: The Locusts and the Horsemen');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 9: टिड्डियाँ और घुड़सवार', 'प्रकाशितवाक्य 9 पढ़ें। पाँचवीं तुरही अथाह कुंड का मुँह खोलती है, और धुएँ में से बिच्छुओं जैसी सामर्थ्य रखनेवाली टिड्डियाँ निकलती हैं। उन्हें घास को या उन लोगों को हानि पहुँचाने की अनुमति नहीं जिन पर परमेश्वर की मुहर है, और न मार डालने की, केवल पाँच महीने तक पीड़ा देने की; उनके राजा का नाम विनाशक है। छठी तुरही फरात नदी पर बँधे चार स्वर्गदूतों को और घुड़सवारों की एक विशाल सेना को छोड़ती है, और मनुष्यों का तिहाई भाग मारा जाता है। फिर भी बाकी लोग अपनी मूरतों, हत्याओं, टोन्हों, व्यभिचार और चोरियों से मन नहीं फिराते। दंड में भी परमेश्वर का लक्ष्य मन फिराव है, पर कठोर मन उसे ठुकराते हैं।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 9: The Locusts and the Horsemen'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 9: വെട്ടുക്കിളികളും കുതിരപ്പടയും', 'വെളിപ്പാട് 9 വായിക്കുക. അഞ്ചാം കാഹളം അഗാധകൂപത്തിന്റെ വാതിൽ തുറക്കുന്നു; പുകയിൽനിന്ന് തേളിന്റേതുപോലുള്ള ശക്തിയുള്ള വെട്ടുക്കിളികൾ പുറപ്പെടുന്നു. പുല്ലിനെയോ ദൈവത്തിന്റെ മുദ്രയുള്ളവരെയോ കേടുവരുത്തുവാൻ അവയ്ക്ക് അനുവാദമില്ല; കൊല്ലുവാനുമല്ല, അഞ്ചു മാസം വേദനിപ്പിക്കുവാൻ മാത്രം; അവയുടെ രാജാവിന്റെ പേര് നാശകൻ എന്നാകുന്നു. ആറാം കാഹളം യൂഫ്രട്ടീസ് നദിക്കരികെ ബന്ധിച്ചിരുന്ന നാലു ദൂതന്മാരെയും ഒരു മഹാ കുതിരപ്പടയെയും അഴിച്ചുവിടുന്നു; മനുഷ്യരിൽ മൂന്നിലൊന്ന് കൊല്ലപ്പെടുന്നു. എന്നിട്ടും ശേഷിച്ചവർ തങ്ങളുടെ വിഗ്രഹങ്ങളിൽനിന്നും കൊലപാതകങ്ങളിൽനിന്നും ക്ഷുദ്രത്തിൽനിന്നും ദുർന്നടപ്പിൽനിന്നും മോഷണത്തിൽനിന്നും മാനസാന്തരപ്പെടുന്നില്ല. ന്യായവിധിയിലും ദൈവത്തിന്റെ ലക്ഷ്യം മാനസാന്തരമാണ്; കഠിനഹൃദയങ്ങളോ അതു നിരസിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 9: The Locusts and the Horsemen'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 8, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 9: The Locusts and the Horsemen'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 10: The Little Scroll', 'Read Revelation 10. A mighty angel comes down wrapped in a cloud, a rainbow over his head, holding a little open scroll, and calls out like a lion. Seven thunders answer, but John is told to seal up what they said, not write it — God keeps some things to himself. The angel swears by the Creator that there will be no more delay; the mystery of God will be fulfilled as he announced to his prophets. John eats the scroll: sweet as honey in his mouth, bitter in his stomach. He must prophesy again to many peoples.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'little scroll', 'prophecy', 'calling']::text[], true, 50, 9
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 10: The Little Scroll');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 10: छोटी पुस्तक', 'प्रकाशितवाक्य 10 पढ़ें। एक शक्तिशाली स्वर्गदूत बादल ओढ़े, सिर पर मेघधनुष लिए उतरता है; उसके हाथ में एक छोटी खुली पुस्तक है, और वह सिंह की सी ऊँची आवाज़ से पुकारता है। सात गर्जन उत्तर देते हैं, पर यूहन्ना से कहा जाता है कि जो उन्होंने कहा उसे मुहरबंद कर दे और न लिखे — कुछ बातें परमेश्वर अपने पास ही रखता है। स्वर्गदूत सृष्टिकर्ता की शपथ खाकर कहता है कि अब और विलंब न होगा; परमेश्वर का भेद पूरा होगा, जैसा उसने अपने दास भविष्यद्वक्ताओं को बताया था। यूहन्ना को पुस्तक खाने को कहा जाता है: मुँह में मधु सी मीठी, पेट में कड़वी। उसे फिर बहुत लोगों के विषय में भविष्यद्वाणी करनी है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 10: The Little Scroll'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 10: ചെറിയ ചുരുൾ', 'വെളിപ്പാട് 10 വായിക്കുക. മേഘം പുതച്ച്, തലയ്ക്കുമീതെ മഴവില്ലുമായി ഒരു ബലവാനായ ദൂതൻ ഇറങ്ങിവരുന്നു; കയ്യിൽ തുറന്ന ഒരു ചെറിയ ചുരുളുണ്ട്; സിംഹഗർജ്ജനംപോലെ അവൻ വിളിച്ചുപറയുന്നു. ഏഴു ഇടിമുഴക്കങ്ങൾ ഉത്തരം പറയുന്നു; എന്നാൽ അവ പറഞ്ഞത് മുദ്രയിട്ട് എഴുതരുത് എന്ന് യോഹന്നാനോടു കല്പിക്കുന്നു — ചിലത് ദൈവം തനിക്കായി വെച്ചിരിക്കുന്നു. ഇനി താമസം ഉണ്ടാകയില്ല എന്ന് സ്രഷ്ടാവിന്റെ നാമത്തിൽ ദൂതൻ ആണയിടുന്നു; തന്റെ ദാസന്മാരായ പ്രവാചകന്മാരോട് അറിയിച്ചതുപോലെ ദൈവത്തിന്റെ മർമ്മം നിവൃത്തിയാകും. ചുരുൾ തിന്നുവാൻ യോഹന്നാനോടു പറയുന്നു: വായിൽ തേൻപോലെ മധുരം, വയറ്റിൽ കൈപ്പ്. അനേകം ജനതകളെക്കുറിച്ച് അവൻ വീണ്ടും പ്രവചിക്കേണം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 10: The Little Scroll'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 9, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 10: The Little Scroll'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 11: The Two Witnesses and the Seventh Trumpet', 'Read Revelation 11. John is told to measure the temple while the outer court is given to the nations. Two witnesses, pictured as olive trees and lampstands, prophesy in sackcloth for 1,260 days until they are killed, their bodies lie in the great city''s street while the world celebrates. After three and a half days God raises them and calls them up, and survivors give glory to him. Then the seventh trumpet sounds and heaven declares, The kingdom of the world has become the kingdom of our Lord and of his Christ, and he shall reign for ever.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'two witnesses', 'seventh trumpet', 'kingdom']::text[], true, 50, 10
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 11: The Two Witnesses and the Seventh Trumpet');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 11: दो गवाह और सातवीं तुरही', 'प्रकाशितवाक्य 11 पढ़ें। यूहन्ना से कहा जाता है कि मंदिर को नापे, जबकि बाहरी आँगन अन्यजातियों को दे दिया गया है। दो गवाह, जो जैतून के वृक्ष और दीवट के रूप में दिखाए गए हैं, टाट ओढ़े 1,260 दिन तक भविष्यद्वाणी करते हैं, जब तक वे मार डाले नहीं जाते; उनकी लोथें बड़े नगर की सड़क पर पड़ी रहती हैं और संसार आनंद मनाता है। साढ़े तीन दिन के बाद परमेश्वर उन्हें जिलाकर ऊपर बुला लेता है, और बचे हुए लोग उसकी महिमा करते हैं। तब सातवीं तुरही फूँकी जाती है और स्वर्ग घोषणा करता है: जगत का राज्य हमारे प्रभु का और उसके मसीह का हो गया, और वह युगानुयुग राज्य करेगा।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 11: The Two Witnesses and the Seventh Trumpet'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 11: രണ്ടു സാക്ഷികളും ഏഴാം കാഹളവും', 'വെളിപ്പാട് 11 വായിക്കുക. ദൈവാലയം അളക്കുവാൻ യോഹന്നാനോടു കല്പിക്കുന്നു; പുറത്തെ പ്രാകാരമോ ജാതികൾക്കു വിട്ടുകൊടുത്തിരിക്കുന്നു. ഒലിവുമരങ്ങളും നിലവിളക്കുകളുമായി ചിത്രീകരിക്കപ്പെട്ട രണ്ടു സാക്ഷികൾ രട്ടുടുത്ത് 1,260 ദിവസം പ്രവചിക്കുന്നു; ഒടുവിൽ കൊല്ലപ്പെടുന്നു, അവരുടെ ശവങ്ങൾ മഹാനഗരത്തിന്റെ വീഥിയിൽ കിടക്കുമ്പോൾ ലോകം ആഹ്ലാദിക്കുന്നു. മൂന്നര ദിവസത്തിനുശേഷം ദൈവം അവരെ ഉയിർപ്പിച്ചു മുകളിലേക്കു വിളിക്കുന്നു; ശേഷിച്ചവർ അവന് മഹത്വം കൊടുക്കുന്നു. പിന്നെ ഏഴാം കാഹളം മുഴങ്ങുന്നു, സ്വർഗ്ഗം പ്രഖ്യാപിക്കുന്നു: ലോകരാജ്യം നമ്മുടെ കർത്താവിന്റെയും അവന്റെ ക്രിസ്തുവിന്റെയും രാജ്യമായിത്തീർന്നിരിക്കുന്നു; അവൻ എന്നെന്നേക്കും വാഴും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 11: The Two Witnesses and the Seventh Trumpet'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 10, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 11: The Two Witnesses and the Seventh Trumpet'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 12: The Woman, the Child and the Dragon', 'Read Revelation 12. A woman clothed with the sun gives birth to a male child who will rule the nations, and a great red dragon waits to devour him. The child is caught up to God, the woman is kept safe, and war breaks out in heaven until the dragon, the ancient serpent called the devil and Satan, is thrown down. Heaven rejoices: the brothers conquered him by the blood of the Lamb and the word of their testimony. Enraged, the dragon makes war on her other children. Your enemy is real, but already defeated.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'spiritual warfare', 'victory', 'the lamb']::text[], true, 50, 11
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 12: The Woman, the Child and the Dragon');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 12: स्त्री, बालक और अजगर', 'प्रकाशितवाक्य 12 पढ़ें। सूर्य को ओढ़े हुए एक स्त्री उस पुत्र को जन्म देती है जो सब जातियों पर राज्य करेगा, और एक बड़ा लाल अजगर उसे निगलने के लिए खड़ा रहता है। बालक परमेश्वर के पास उठा लिया जाता है, स्त्री जंगल में सुरक्षित रखी जाती है, और स्वर्ग में युद्ध होता है जब तक वह पुराना सर्प, जो शैतान कहलाता है, नीचे न गिराया जाए। स्वर्ग जयजयकार करता है: भाइयों ने मेम्ने के लहू और अपनी गवाही के वचन से उस पर जय पाई। क्रोधित होकर अजगर स्त्री की शेष सन्तान से लड़ता है। तेरा शत्रु सच्चा है, परन्तु वह पहले ही हार चुका है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 12: The Woman, the Child and the Dragon'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 12: സ്ത്രീയും ശിശുവും മഹാസർപ്പവും', 'വെളിപ്പാട് 12 വായിക്കുക. സൂര്യനെ ഉടുത്ത ഒരു സ്ത്രീ സകല ജാതികളെയും ഭരിക്കാനിരിക്കുന്ന ആൺകുഞ്ഞിനെ പ്രസവിക്കുന്നു; ചുവന്ന മഹാസർപ്പം അവനെ വിഴുങ്ങാൻ കാത്തുനിൽക്കുന്നു. ശിശു ദൈവസന്നിധിയിലേക്കു എടുക്കപ്പെടുന്നു, സ്ത്രീ മരുഭൂമിയിൽ സംരക്ഷിക്കപ്പെടുന്നു, സ്വർഗ്ഗത്തിൽ യുദ്ധമുണ്ടായി പിശാചും സാത്താനും എന്നു വിളിക്കപ്പെടുന്ന പുരാതന സർപ്പം താഴെ തള്ളപ്പെടുന്നു. സ്വർഗ്ഗം ആനന്ദിക്കുന്നു: സഹോദരന്മാർ കുഞ്ഞാടിന്റെ രക്തത്താലും തങ്ങളുടെ സാക്ഷ്യവചനത്താലും അവനെ ജയിച്ചു. കോപിച്ച സർപ്പം അവളുടെ ശേഷം സന്തതിയോടു യുദ്ധം ചെയ്യുന്നു. നിന്റെ ശത്രു യഥാർത്ഥമാണ്, എന്നാൽ അവൻ ഇതിനകം തോറ്റുപോയവനാണ്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 12: The Woman, the Child and the Dragon'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 11, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 12: The Woman, the Child and the Dragon'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 13: The Two Beasts', 'Read Revelation 13. A beast rises from the sea with blasphemous names, receiving its power and throne from the dragon. The whole earth marvels and worships it, and it is allowed to speak proud words and to make war on the saints for a limited time. A second beast rises from the earth, performing signs and forcing people to honour the first beast''s image, marking those who comply. The chapter twice calls for wisdom, endurance and faith. Read it as a summons to worship God alone, whatever the cost.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'endurance', 'worship', 'faithfulness']::text[], true, 50, 12
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 13: The Two Beasts');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 13: दो पशु', 'प्रकाशितवाक्य 13 पढ़ें। समुद्र में से एक पशु निकलता है जिस पर निन्दा के नाम हैं, और अजगर उसे अपनी सामर्थ्य और सिंहासन देता है। सारी पृथ्वी अचम्भा करके उसकी उपासना करती है; उसे घमण्ड की बातें कहने और सीमित समय तक पवित्र लोगों से लड़ने की छूट दी जाती है। फिर पृथ्वी में से दूसरा पशु निकलता है, जो चिन्ह दिखाकर लोगों से पहले पशु की मूरत का आदर करवाता है और मानने वालों पर छाप लगवाता है। यह अध्याय दो बार बुद्धि, धीरज और विश्वास की मांग करता है। इसे इस बुलाहट के रूप में पढ़ें कि चाहे जो मूल्य हो, केवल परमेश्वर की उपासना करें।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 13: The Two Beasts'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 13: രണ്ടു മൃഗങ്ങൾ', 'വെളിപ്പാട് 13 വായിക്കുക. ദൂഷണനാമങ്ങളുള്ള ഒരു മൃഗം സമുദ്രത്തിൽനിന്നു കയറിവരുന്നു; മഹാസർപ്പം അതിനു തന്റെ ശക്തിയും സിംഹാസനവും നൽകുന്നു. ഭൂമി മുഴുവൻ ആശ്ചര്യപ്പെട്ടു അതിനെ നമസ്കരിക്കുന്നു; നിശ്ചിത കാലത്തേക്കു വമ്പുപറയാനും വിശുദ്ധന്മാരോടു യുദ്ധം ചെയ്യാനും അതിനു അനുവാദം ലഭിക്കുന്നു. പിന്നെ ഭൂമിയിൽനിന്നു രണ്ടാമതൊരു മൃഗം കയറിവന്നു അടയാളങ്ങൾ കാട്ടി ആദ്യമൃഗത്തിന്റെ പ്രതിമയെ ബഹുമാനിക്കാൻ ജനത്തെ നിർബന്ധിക്കുകയും അനുസരിക്കുന്നവരെ മുദ്രയിടുകയും ചെയ്യുന്നു. ഈ അധ്യായം രണ്ടു പ്രാവശ്യം ജ്ഞാനവും സഹിഷ്ണുതയും വിശ്വാസവും ആവശ്യപ്പെടുന്നു. എന്തു വിലകൊടുത്തും ദൈവത്തെ മാത്രം ആരാധിക്കാനുള്ള വിളിയായി ഇതു വായിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 13: The Two Beasts'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 12, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 13: The Two Beasts'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 14: The Lamb on Mount Zion', 'Read Revelation 14. The Lamb stands on Mount Zion with those who bear his name and his Father''s name on their foreheads, singing a new song that only the redeemed can learn. Three angels fly in midheaven: the first proclaims the eternal gospel, calling every nation to fear God and give him glory; the second announces that Babylon has fallen; the third warns against worshipping the beast. A voice declares the dead who die in the Lord blessed. Then the earth is harvested. Judgment is real, and so is the Lamb''s keeping of his own.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'the lamb', 'gospel', 'judgment']::text[], true, 50, 13
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 14: The Lamb on Mount Zion');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 14: सिय्योन पर्वत पर मेम्ना', 'प्रकाशितवाक्य 14 पढ़ें। मेम्ना सिय्योन पर्वत पर उनके साथ खड़ा है जिनके माथे पर उसका और उसके पिता का नाम लिखा है, और वे एक नया गीत गाते हैं जिसे केवल छुड़ाए हुए लोग सीख सकते हैं। तीन स्वर्गदूत आकाश के बीच में उड़ते हैं: पहला सनातन सुसमाचार सुनाता है और हर जाति को बुलाता है कि परमेश्वर का भय मानें और उसकी महिमा करें; दूसरा घोषित करता है कि बाबुल गिर गया; तीसरा पशु की उपासना से चिताता है। एक शब्द कहता है कि धन्य हैं वे मृतक जो प्रभु में मरते हैं। फिर पृथ्वी की कटनी होती है। न्याय सच्चा है, और मेम्ने का अपनों को थामे रहना भी।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 14: The Lamb on Mount Zion'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 14: സീയോൻ മലയിലെ കുഞ്ഞാട്', 'വെളിപ്പാട് 14 വായിക്കുക. തന്റെയും പിതാവിന്റെയും നാമം നെറ്റിയിൽ വഹിക്കുന്നവരോടുകൂടെ കുഞ്ഞാട് സീയോൻ മലയിൽ നിൽക്കുന്നു; വീണ്ടെടുക്കപ്പെട്ടവർക്കു മാത്രം പഠിക്കാവുന്ന പുതിയൊരു പാട്ട് അവർ പാടുന്നു. മൂന്നു ദൂതന്മാർ ആകാശമധ്യേ പറക്കുന്നു: ഒന്നാമൻ നിത്യസുവിശേഷം ഘോഷിച്ചു സകല ജാതികളോടും ദൈവത്തെ ഭയപ്പെട്ടു മഹത്വപ്പെടുത്താൻ വിളിക്കുന്നു; രണ്ടാമൻ ബാബിലോൺ വീണു എന്നു അറിയിക്കുന്നു; മൂന്നാമൻ മൃഗാരാധനയെക്കുറിച്ചു മുന്നറിയിപ്പു നൽകുന്നു. കർത്താവിൽ മരിക്കുന്നവർ ഭാഗ്യവാന്മാർ എന്നു ഒരു ശബ്ദം പ്രഖ്യാപിക്കുന്നു. പിന്നെ ഭൂമിയുടെ കൊയ്ത്തു നടക്കുന്നു. ന്യായവിധി യഥാർത്ഥമാണ്; കുഞ്ഞാട് തന്റെ സ്വന്തക്കാരെ കാത്തുകൊള്ളുന്നതും അങ്ങനെതന്നെ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 14: The Lamb on Mount Zion'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 13, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 14: The Lamb on Mount Zion'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 15: The Song of Moses and of the Lamb', 'Read Revelation 15. John sees another sign in heaven: seven angels holding the seven last plagues, in which the wrath of God is finished. Beside a sea of glass mixed with fire stand those who have come through the conflict with the beast, harps in hand, singing the song of Moses and the song of the Lamb: great and amazing are your deeds, just and true are your ways, King of the nations. All nations will come and worship. Then the heavenly temple opens and the seven bowls are given out. Even judgment moves toward worship.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'worship', 'holiness', 'judgment']::text[], true, 50, 14
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 15: The Song of Moses and of the Lamb');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 15: मूसा और मेम्ने का गीत', 'प्रकाशितवाक्य 15 पढ़ें। यूहन्ना स्वर्ग में एक और चिन्ह देखता है: सात स्वर्गदूत जिनके पास अन्तिम सात विपत्तियाँ हैं, जिनमें परमेश्वर का क्रोध पूरा होता है। आग से मिले हुए काँच के समुद्र के पास वे खड़े हैं जो पशु के साथ संघर्ष से पार आए; हाथों में वीणा लिए वे मूसा का और मेम्ने का गीत गाते हैं: हे जातियों के राजा, तेरे काम बड़े और अद्भुत हैं, तेरे मार्ग धर्ममय और सच्चे हैं। सब जातियाँ आकर दण्डवत करेंगी। फिर स्वर्गीय मन्दिर खुलता है और सात कटोरे सौंपे जाते हैं। न्याय भी आराधना की ओर ले जाता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 15: The Song of Moses and of the Lamb'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 15: മോശെയുടെയും കുഞ്ഞാടിന്റെയും പാട്ട്', 'വെളിപ്പാട് 15 വായിക്കുക. യോഹന്നാൻ സ്വർഗ്ഗത്തിൽ മറ്റൊരു അടയാളം കാണുന്നു: ദൈവക്രോധം തികയുന്ന അവസാനത്തെ ഏഴു ബാധകൾ വഹിക്കുന്ന ഏഴു ദൂതന്മാർ. തീ കലർന്ന സ്ഫടികക്കടലിനരികെ മൃഗത്തോടുള്ള പോരാട്ടത്തിൽനിന്നു ജയിച്ചുവന്നവർ വീണകളോടെ നിന്നു മോശെയുടെ പാട്ടും കുഞ്ഞാടിന്റെ പാട്ടും പാടുന്നു: ജാതികളുടെ രാജാവേ, നിന്റെ പ്രവൃത്തികൾ വലുതും അത്ഭുതവുമാകുന്നു, നിന്റെ വഴികൾ നീതിയും സത്യവുമാകുന്നു. സകല ജാതികളും വന്നു നമസ്കരിക്കും. പിന്നെ സ്വർഗ്ഗീയ ആലയം തുറക്കപ്പെട്ടു ഏഴു കലശങ്ങൾ ഏൽപ്പിക്കപ്പെടുന്നു. ന്യായവിധിപോലും ആരാധനയിലേക്കു നയിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 15: The Song of Moses and of the Lamb'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 14, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 15: The Song of Moses and of the Lamb'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 16: The Seven Bowls of Wrath', 'Read Revelation 16. A voice from the temple sends the seven angels out, and the bowls are poured on the earth, the sea, the rivers, the sun, the throne of the beast, the Euphrates and the air. The angel of the waters declares God just in his judgments, and the altar answers, true and just are your judgments. Yet those struck curse God and refuse to repent. Unclean spirits gather the kings to a place called Armageddon, and Christ warns that he comes like a thief. The seventh bowl brings the cry: it is done.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'judgment', 'repentance', 'justice']::text[], true, 50, 15
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 16: The Seven Bowls of Wrath');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 16: क्रोध के सात कटोरे', 'प्रकाशितवाक्य 16 पढ़ें। मन्दिर में से एक शब्द सातों स्वर्गदूतों को भेजता है, और कटोरे पृथ्वी, समुद्र, नदियों, सूर्य, पशु के सिंहासन, फरात और आकाश पर उंडेले जाते हैं। जल का स्वर्गदूत कहता है कि परमेश्वर अपने न्याय में धर्मी है, और वेदी उत्तर देती है कि तेरे न्याय सच्चे और ठीक हैं। तौभी मारे गए लोग परमेश्वर की निन्दा करते हैं और मन नहीं फिराते। अशुद्ध आत्माएँ राजाओं को उस स्थान पर इकट्ठा करती हैं जो हर-मगिदोन कहलाता है, और मसीह चिताता है कि वह चोर के समान आता है। सातवें कटोरे पर पुकार होती है: हो चुका।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 16: The Seven Bowls of Wrath'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 16: ക്രോധത്തിന്റെ ഏഴു കലശങ്ങൾ', 'വെളിപ്പാട് 16 വായിക്കുക. ആലയത്തിൽനിന്നുള്ള ഒരു ശബ്ദം ഏഴു ദൂതന്മാരെ അയയ്ക്കുന്നു; കലശങ്ങൾ ഭൂമിയിലും കടലിലും നദികളിലും സൂര്യനിലും മൃഗത്തിന്റെ സിംഹാസനത്തിലും യൂഫ്രട്ടീസിലും വായുവിലും പകരുന്നു. ജലങ്ങളുടെ ദൂതൻ ദൈവം തന്റെ ന്യായവിധികളിൽ നീതിമാൻ എന്നു പ്രഖ്യാപിക്കുന്നു; യാഗപീഠം നിന്റെ ന്യായവിധികൾ സത്യവും നീതിയുമാകുന്നു എന്നു മറുപടി പറയുന്നു. എങ്കിലും ബാധയേറ്റവർ ദൈവത്തെ ദുഷിക്കുകയും മാനസാന്തരപ്പെടാതിരിക്കുകയും ചെയ്യുന്നു. അശുദ്ധാത്മാക്കൾ രാജാക്കന്മാരെ അർമ്മഗെദ്ദോൻ എന്ന സ്ഥലത്തു കൂട്ടിവരുത്തുന്നു; താൻ കള്ളനെപ്പോലെ വരുന്നു എന്നു ക്രിസ്തു മുന്നറിയിപ്പു നൽകുന്നു. ഏഴാം കലശത്തിൽ വിളി മുഴങ്ങുന്നു: സംഭവിച്ചുതീർന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 16: The Seven Bowls of Wrath'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 15, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 16: The Seven Bowls of Wrath'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 17: The Woman on the Beast', 'Read Revelation 17. An angel shows John the judgment of the great prostitute seated on many waters, with whom the kings of the earth committed immorality. She rides a scarlet beast, dressed in purple and gold, holding a cup of abominations, drunk with the blood of the saints. The angel explains the mystery of the beast''s heads and horns, and of the kings who give it their power. They will make war on the Lamb, and the Lamb will conquer them, for he is Lord of lords and King of kings. Splendour that opposes God does not last.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'babylon', 'idolatry', 'the lamb']::text[], true, 50, 16
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 17: The Woman on the Beast');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 17: पशु पर बैठी स्त्री', 'प्रकाशितवाक्य 17 पढ़ें। एक स्वर्गदूत यूहन्ना को उस बड़ी वेश्या का दण्ड दिखाता है जो बहुत से जलों पर बैठी है, जिसके साथ पृथ्वी के राजाओं ने व्यभिचार किया। वह लाल रंग के पशु पर सवार है, बैंजनी और सोने से सजी है, हाथ में घृणित वस्तुओं से भरा कटोरा लिए है, और पवित्र लोगों के लहू से मतवाली है। स्वर्गदूत पशु के सिरों और सींगों का, और उन राजाओं का भेद समझाता है जो उसे अपनी सामर्थ्य देते हैं। वे मेम्ने से लड़ेंगे, और मेम्ना उन पर जय पाएगा, क्योंकि वह प्रभुओं का प्रभु और राजाओं का राजा है। परमेश्वर के विरुद्ध खड़ा वैभव टिकता नहीं।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 17: The Woman on the Beast'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 17: മൃഗത്തിന്മേൽ ഇരിക്കുന്ന സ്ത്രീ', 'വെളിപ്പാട് 17 വായിക്കുക. പെരുവെള്ളങ്ങളുടെ മേൽ ഇരിക്കുന്ന മഹാവേശ്യയുടെ ന്യായവിധി ഒരു ദൂതൻ യോഹന്നാനു കാണിക്കുന്നു; ഭൂമിയിലെ രാജാക്കന്മാർ അവളോടു വ്യഭിചാരം ചെയ്തു. ധൂമ്രവസ്ത്രവും സ്വർണ്ണവും അണിഞ്ഞ അവൾ മ്ലേച്ഛതകൾ നിറഞ്ഞ പാനപാത്രവുമായി ചുവന്ന മൃഗത്തിന്മേൽ സവാരി ചെയ്യുന്നു; വിശുദ്ധന്മാരുടെ രക്തത്താൽ അവൾ ലഹരിപിടിച്ചിരിക്കുന്നു. മൃഗത്തിന്റെ തലകളുടെയും കൊമ്പുകളുടെയും, അതിനു അധികാരം നൽകുന്ന രാജാക്കന്മാരുടെയും മർമ്മം ദൂതൻ വിശദീകരിക്കുന്നു. അവർ കുഞ്ഞാടിനോടു യുദ്ധം ചെയ്യും, കുഞ്ഞാട് അവരെ ജയിക്കും; അവൻ കർത്താധികർത്താവും രാജാധിരാജാവുമാകുന്നു. ദൈവത്തെ എതിർക്കുന്ന പ്രതാപം നിലനിൽക്കുകയില്ല.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 17: The Woman on the Beast'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 16, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 17: The Woman on the Beast'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 18: The Fall of Babylon', 'Read Revelation 18. An angel with great authority announces that Babylon the great has fallen, and another voice calls, come out of her, my people, so that you do not share in her sins. Kings, merchants and shipmasters stand at a distance and weep over the city that made them rich, mourning a cargo list that ends with human souls. A mighty angel throws a millstone into the sea: so violently the city will be thrown down, its music and craft and wedding joy silenced. What is built on greed and blood cannot stand before God.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'babylon', 'judgment', 'separation']::text[], true, 50, 17
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 18: The Fall of Babylon');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 18: बाबुल का पतन', 'प्रकाशितवाक्य 18 पढ़ें। बड़े अधिकार वाला एक स्वर्गदूत घोषित करता है कि बड़ा बाबुल गिर गया, और दूसरा शब्द पुकारता है, हे मेरी प्रजा, उसमें से निकल आ, कहीं ऐसा न हो कि तू उसके पापों में सहभागी हो जाए। राजा, व्यापारी और मल्लाह दूर खड़े होकर उस नगर पर रोते हैं जिसने उन्हें धनी बनाया, और उस माल की सूची पर विलाप करते हैं जो मनुष्यों के प्राणों पर समाप्त होती है। एक बलवन्त स्वर्गदूत चक्की का पाट समुद्र में फेंकता है: इसी प्रकार वह नगर गिराया जाएगा, उसका संगीत, शिल्प और विवाह का आनन्द चुप हो जाएगा। लोभ और लहू पर बना हुआ परमेश्वर के सामने ठहर नहीं सकता।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 18: The Fall of Babylon'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 18: ബാബിലോണിന്റെ വീഴ്ച', 'വെളിപ്പാട് 18 വായിക്കുക. വലിയ അധികാരമുള്ള ഒരു ദൂതൻ മഹാബാബിലോൺ വീണുപോയി എന്നു ഘോഷിക്കുന്നു; മറ്റൊരു ശബ്ദം വിളിക്കുന്നു: എന്റെ ജനമേ, അവളുടെ പാപങ്ങളിൽ കൂട്ടാളികളാകാതിരിക്കേണ്ടതിനു അവളിൽനിന്നു പുറത്തുവരുവിൻ. രാജാക്കന്മാരും വ്യാപാരികളും കപ്പൽക്കാരും ദൂരെ നിന്നു തങ്ങളെ സമ്പന്നരാക്കിയ നഗരത്തെച്ചൊല്ലി കരയുന്നു; മനുഷ്യരുടെ പ്രാണനിൽ അവസാനിക്കുന്ന ചരക്കുപട്ടികയെക്കുറിച്ചു വിലപിക്കുന്നു. ശക്തനായ ഒരു ദൂതൻ തിരികല്ലു കടലിൽ എറിയുന്നു: അങ്ങനെ ആ നഗരം തള്ളിയിടപ്പെടും, അതിന്റെ സംഗീതവും കൈത്തൊഴിലും വിവാഹസന്തോഷവും നിലയ്ക്കും. അത്യാഗ്രഹത്തിന്മേലും രക്തത്തിന്മേലും പണിതതു ദൈവമുമ്പാകെ നിലനിൽക്കുകയില്ല.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 18: The Fall of Babylon'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 17, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 18: The Fall of Babylon'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 19: The Marriage Supper and the Rider on the White Horse', 'Read Revelation 19. Heaven erupts in hallelujahs: salvation and glory and power belong to our God, whose judgments are true and just. The marriage of the Lamb has come, and his bride is granted fine linen to wear, the righteous deeds of the saints. Blessed are those invited to the supper. When John falls at the angel''s feet he is told to worship God, for the testimony of Jesus is the spirit of prophecy. Then heaven opens: a rider called Faithful and True, the Word of God, King of kings, comes to judge and make war.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'worship', 'the lamb', 'king of kings']::text[], true, 50, 18
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 19: The Marriage Supper and the Rider on the White Horse');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 19: मेम्ने का विवाह-भोज और श्वेत घोड़े का सवार', 'प्रकाशितवाक्य 19 पढ़ें। स्वर्ग हल्लिलूय्याह से गूँज उठता है: उद्धार, महिमा और सामर्थ्य हमारे परमेश्वर की है, जिसके न्याय सच्चे और ठीक हैं। मेम्ने का विवाह आ पहुँचा, और उसकी दुल्हिन को उजला मलमल पहनने के लिए दिया गया है, जो पवित्र लोगों के धर्म के काम हैं। धन्य हैं वे जो इस भोज में बुलाए गए हैं। जब यूहन्ना स्वर्गदूत के पाँवों पर गिरता है, तो उससे कहा जाता है कि परमेश्वर को दण्डवत कर, क्योंकि यीशु की गवाही भविष्यद्वाणी की आत्मा है। फिर स्वर्ग खुलता है: विश्वासयोग्य और सत्य कहलाने वाला सवार, परमेश्वर का वचन, राजाओं का राजा और प्रभुओं का प्रभु, न्याय करने और लड़ने आता है।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 19: The Marriage Supper and the Rider on the White Horse'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 19: കുഞ്ഞാടിന്റെ കല്യാണവിരുന്നും വെള്ളക്കുതിരപ്പുറത്തെ സവാരിക്കാരനും', 'വെളിപ്പാട് 19 വായിക്കുക. സ്വർഗ്ഗം ഹല്ലേലൂയ്യാ ഘോഷത്താൽ നിറയുന്നു: രക്ഷയും മഹത്വവും ശക്തിയും നമ്മുടെ ദൈവത്തിനുള്ളതു; അവന്റെ ന്യായവിധികൾ സത്യവും നീതിയുമാകുന്നു. കുഞ്ഞാടിന്റെ കല്യാണം വന്നിരിക്കുന്നു; വിശുദ്ധന്മാരുടെ നീതിപ്രവൃത്തികളാകുന്ന നിർമ്മലവസ്ത്രം ധരിപ്പാൻ അവന്റെ മണവാട്ടിക്കു നൽകപ്പെട്ടിരിക്കുന്നു. ആ വിരുന്നിനു ക്ഷണിക്കപ്പെട്ടവർ ഭാഗ്യവാന്മാർ. യോഹന്നാൻ ദൂതന്റെ കാൽക്കൽ വീണപ്പോൾ, ദൈവത്തെ നമസ്കരിക്ക എന്നു കല്പന ലഭിക്കുന്നു; യേശുവിന്റെ സാക്ഷ്യം പ്രവചനത്തിന്റെ ആത്മാവാകുന്നു. പിന്നെ സ്വർഗ്ഗം തുറക്കുന്നു: വിശ്വസ്തനും സത്യവാനും എന്നു പേരുള്ള, ദൈവവചനമായ, രാജാധിരാജാവും കർത്താധികർത്താവുമായവൻ ന്യായവിധിക്കും യുദ്ധത്തിനുമായി വരുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 19: The Marriage Supper and the Rider on the White Horse'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 18, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 19: The Marriage Supper and the Rider on the White Horse'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 20: The Thousand Years and the Great White Throne', 'Read Revelation 20. An angel binds the dragon and shuts him in the abyss, and John sees those who refused the beast reigning with Christ for a thousand years. Afterwards Satan is released, gathers the nations for a final assault, and is thrown into the lake of fire. Then a great white throne appears; the books are opened, and the dead are judged by what they had done, while those written in the book of life are safe in the Lamb. Christians have long read these thousand years differently; hold that humbly, and Christ''s certain victory firmly.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'judgment', 'hope', 'resurrection']::text[], true, 50, 19
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 20: The Thousand Years and the Great White Throne');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 20: हज़ार वर्ष और बड़ा श्वेत सिंहासन', 'प्रकाशितवाक्य 20 पढ़ें। एक स्वर्गदूत अजगर को बाँधकर अथाह कुण्ड में बन्द करता है, और यूहन्ना उन्हें देखता है जिन्होंने पशु को इन्कार किया और जो मसीह के साथ हज़ार वर्ष तक राज्य करते हैं। इसके बाद शैतान छोड़ा जाता है, जातियों को अन्तिम आक्रमण के लिए इकट्ठा करता है, और आग से भस्म होकर आग की झील में डाला जाता है। फिर एक बड़ा श्वेत सिंहासन दिखाई देता है; पुस्तकें खोली जाती हैं और मरे हुओं का न्याय उनके कामों के अनुसार होता है, पर जिनके नाम जीवन की पुस्तक में लिखे हैं वे मेम्ने में सुरक्षित हैं। मसीही लोग इन हज़ार वर्षों को लम्बे समय से भिन्न-भिन्न रीति से समझते आए हैं; इसे नम्रता से थामें, और मसीह की निश्चित जय को दृढ़ता से।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 20: The Thousand Years and the Great White Throne'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 20: ആയിരം വർഷവും വലിയ വെള്ളസിംഹാസനവും', 'വെളിപ്പാട് 20 വായിക്കുക. ഒരു ദൂതൻ മഹാസർപ്പത്തെ ബന്ധിച്ചു അഗാധത്തിൽ അടയ്ക്കുന്നു; മൃഗത്തെ നിരസിച്ചവർ ക്രിസ്തുവിനോടുകൂടെ ആയിരം വർഷം വാഴുന്നതു യോഹന്നാൻ കാണുന്നു. അതിനുശേഷം സാത്താൻ അഴിച്ചുവിടപ്പെട്ടു ജാതികളെ അവസാനത്തെ ആക്രമണത്തിനു കൂട്ടിവരുത്തുന്നു; തീ അവരെ ദഹിപ്പിക്കുന്നു, അവൻ അഗ്നിപ്പൊയ്കയിൽ തള്ളപ്പെടുന്നു. പിന്നെ ഒരു വലിയ വെള്ളസിംഹാസനം പ്രത്യക്ഷമാകുന്നു; പുസ്തകങ്ങൾ തുറക്കപ്പെട്ടു മരിച്ചവർ തങ്ങളുടെ പ്രവൃത്തികൾക്കൊത്തു ന്യായം വിധിക്കപ്പെടുന്നു, ജീവപുസ്തകത്തിൽ പേരെഴുതപ്പെട്ടവരോ കുഞ്ഞാടിൽ സുരക്ഷിതരാകുന്നു. ഈ ആയിരം വർഷത്തെ ക്രിസ്ത്യാനികൾ പണ്ടുമുതലേ വ്യത്യസ്തമായി മനസ്സിലാക്കിയിട്ടുണ്ട്; അതു താഴ്മയോടെ പിടിക്കുക, ക്രിസ്തുവിന്റെ ഉറപ്പുള്ള ജയം ഉറപ്പോടെ പിടിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 20: The Thousand Years and the Great White Throne'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 19, false, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 20: The Thousand Years and the Great White Throne'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 21: A New Heaven and a New Earth', 'Read Revelation 21. John sees a new heaven and a new earth, and the holy city coming down from God like a bride adorned for her husband. A loud voice announces the heart of the whole book: the dwelling place of God is with man, and he will wipe away every tear, and death and mourning and pain will be no more. He who sits on the throne says, behold, I am making all things new. The city is measured and described, radiant with God''s glory, with no temple, for the Lord and the Lamb are its temple.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'new creation', 'hope', 'gods presence']::text[], true, 50, 20
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 21: A New Heaven and a New Earth');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 21: नया आकाश और नई पृथ्वी', 'प्रकाशितवाक्य 21 पढ़ें। यूहन्ना एक नया आकाश और एक नई पृथ्वी देखता है, और पवित्र नगर को परमेश्वर के पास से उतरते हुए, मानो दुल्हन अपने दूल्हे के लिए सिंगारी गई हो। एक बड़ा शब्द इस पूरी पुस्तक का हृदय सुनाता है: परमेश्वर का डेरा मनुष्यों के बीच है, और वह उनकी आँखों से हर एक आँसू पोंछ देगा, और मृत्यु, शोक, विलाप और पीड़ा फिर न रहेंगे। सिंहासन पर बैठा हुआ कहता है, देख, मैं सब कुछ नया कर देता हूँ। नगर नापा और वर्णित किया जाता है, परमेश्वर की महिमा से जगमगाता हुआ, जिसमें कोई मन्दिर नहीं, क्योंकि प्रभु और मेम्ना ही उसका मन्दिर हैं।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 21: A New Heaven and a New Earth'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 21: പുതിയ ആകാശവും പുതിയ ഭൂമിയും', 'വെളിപ്പാട് 21 വായിക്കുക. യോഹന്നാൻ പുതിയ ആകാശവും പുതിയ ഭൂമിയും കാണുന്നു; ഭർത്താവിനായി അലങ്കരിക്കപ്പെട്ട മണവാട്ടിയെപ്പോലെ വിശുദ്ധനഗരം ദൈവസന്നിധിയിൽനിന്നു ഇറങ്ങിവരുന്നു. ഒരു വലിയ ശബ്ദം ഈ പുസ്തകത്തിന്റെ ഹൃദയം പ്രഖ്യാപിക്കുന്നു: ദൈവത്തിന്റെ കൂടാരം മനുഷ്യരോടുകൂടെയാകുന്നു; അവൻ അവരുടെ കണ്ണിൽനിന്നു കണ്ണുനീരെല്ലാം തുടച്ചുകളയും; മരണവും ദുഃഖവും കരച്ചിലും വേദനയും ഇനി ഉണ്ടാകയില്ല. സിംഹാസനത്തിൽ ഇരിക്കുന്നവൻ പറയുന്നു: ഇതാ, ഞാൻ സകലവും പുതുതാക്കുന്നു. നഗരം അളന്നു വർണ്ണിക്കപ്പെടുന്നു, ദൈവമഹത്വത്താൽ പ്രകാശിക്കുന്നു; അവിടെ ആലയമില്ല, കർത്താവും കുഞ്ഞാടും തന്നേ അതിന്റെ ആലയം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 21: A New Heaven and a New Earth'
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 20, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 21: A New Heaven and a New Earth'
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics
  (title, description, category, input_type, tags, is_active, xp_value, display_order)
SELECT 'Revelation 22: The River of Life and ''I Am Coming Soon''', 'Read Revelation 22. A river of the water of life flows from the throne of God and of the Lamb, and the tree of life yields its fruit, its leaves for the healing of the nations. Nothing accursed remains; his servants will see his face and reign forever. Three times Jesus says, behold, I am coming soon. John is told not to seal the words, and warned to worship God alone. The Spirit and the bride say, come, and whoever is thirsty may take the water of life without price. The book ends: come, Lord Jesus.', 'Foundations of Faith', 'topic',
       ARRAY['revelation', 'hope', 'the lamb', 'coming soon']::text[], true, 50, 21
 WHERE NOT EXISTS (SELECT 1 FROM public.recommended_topics WHERE title = 'Revelation 22: The River of Life and ''I Am Coming Soon''');

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'hi', 'प्रकाशितवाक्य 22: जीवन की नदी और ''मैं शीघ्र आता हूँ''', 'प्रकाशितवाक्य 22 पढ़ें। परमेश्वर और मेम्ने के सिंहासन से जीवन के जल की नदी बहती है, और जीवन का वृक्ष अपना फल देता है, जिसके पत्ते जातियों की चंगाई के लिए हैं। शाप की कोई वस्तु फिर न रहेगी; उसके दास उसका मुँह देखेंगे और युगानुयुग राज्य करेंगे। तीन बार यीशु कहता है, देख, मैं शीघ्र आता हूँ। यूहन्ना से कहा जाता है कि इन वचनों पर मुहर न लगा, और चिताया जाता है कि केवल परमेश्वर को दण्डवत कर। आत्मा और दुल्हिन कहते हैं, आ, और जो कोई प्यासा हो वह जीवन का जल सेंतमेंत ले। पुस्तक इसी पर समाप्त होती है: हे प्रभु यीशु, आ।', 'विश्वास की नींव'
  FROM public.recommended_topics WHERE title = 'Revelation 22: The River of Life and ''I Am Coming Soon'''
ON CONFLICT DO NOTHING;

INSERT INTO public.recommended_topics_translations
  (topic_id, language_code, title, description, category)
SELECT id, 'ml', 'വെളിപ്പാട് 22: ജീവജലനദിയും ''ഞാൻ വേഗം വരുന്നു'' എന്ന വാക്കും', 'വെളിപ്പാട് 22 വായിക്കുക. ദൈവത്തിന്റെയും കുഞ്ഞാടിന്റെയും സിംഹാസനത്തിൽനിന്നു ജീവജലനദി ഒഴുകുന്നു; ജീവവൃക്ഷം ഫലം നൽകുന്നു, അതിന്റെ ഇലകൾ ജാതികളുടെ സൗഖ്യത്തിനുള്ളതാകുന്നു. ശാപമുള്ളതൊന്നും ഇനി ഉണ്ടാകയില്ല; അവന്റെ ദാസന്മാർ അവന്റെ മുഖം കാണുകയും എന്നേക്കും വാഴുകയും ചെയ്യും. മൂന്നു പ്രാവശ്യം യേശു പറയുന്നു: ഇതാ, ഞാൻ വേഗം വരുന്നു. ഈ വചനങ്ങൾ മുദ്രയിടരുതെന്നു യോഹന്നാനോടു കല്പിക്കുന്നു; ദൈവത്തെ മാത്രം നമസ്കരിക്കാൻ മുന്നറിയിപ്പു നൽകുന്നു. ആത്മാവും മണവാട്ടിയും പറയുന്നു, വരിക; ദാഹിക്കുന്നവൻ ജീവജലം സൗജന്യമായി വാങ്ങട്ടെ. പുസ്തകം ഇങ്ങനെ അവസാനിക്കുന്നു: കർത്താവായ യേശുവേ, വരേണമേ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'
  FROM public.recommended_topics WHERE title = 'Revelation 22: The River of Life and ''I Am Coming Soon'''
ON CONFLICT DO NOTHING;

INSERT INTO public.learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
SELECT lp.id, rt.id, 21, true, true
  FROM public.learning_paths lp, public.recommended_topics rt
 WHERE lp.slug = 'revelation-the-lamb-who-reigns' AND rt.title = 'Revelation 22: The River of Life and ''I Am Coming Soon'''
ON CONFLICT DO NOTHING;
