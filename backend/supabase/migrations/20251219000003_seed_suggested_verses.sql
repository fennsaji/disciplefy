-- Migration: Seed Suggested Verses
-- Created: 2025-12-19
-- Purpose: Populate suggested_verses and suggested_verse_translations tables
--          with 40 popular Bible verses across 8 categories

BEGIN;

-- =============================================================================
-- CATEGORY: SALVATION (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000001-0000-0000-0000-000000000001', 'John 3:16', 'John', 3, 16, NULL, 'salvation', ARRAY['gospel', 'love', 'eternal life'], 1),
    ('a0000001-0000-0000-0000-000000000002', 'Romans 10:9', 'Romans', 10, 9, NULL, 'salvation', ARRAY['confession', 'belief', 'resurrection'], 2),
    ('a0000001-0000-0000-0000-000000000003', 'Ephesians 2:8-9', 'Ephesians', 2, 8, 9, 'salvation', ARRAY['grace', 'faith', 'gift'], 3),
    ('a0000001-0000-0000-0000-000000000004', 'Acts 16:31', 'Acts', 16, 31, NULL, 'salvation', ARRAY['believe', 'lord', 'saved'], 4),
    ('a0000001-0000-0000-0000-000000000005', 'Romans 6:23', 'Romans', 6, 23, NULL, 'salvation', ARRAY['sin', 'death', 'eternal life'], 5)
ON CONFLICT (id) DO NOTHING;

-- Salvation translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- John 3:16
    ('a0000001-0000-0000-0000-000000000001', 'en', 'For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.', 'John 3:16'),
    ('a0000001-0000-0000-0000-000000000001', 'hi', 'क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे वह नष्ट न हो, परन्तु अनन्त जीवन पाए।', 'यूहन्ना 3:16'),
    ('a0000001-0000-0000-0000-000000000001', 'ml', 'തന്റെ ഏകജാതനായ പുത്രനിൽ വിശ്വസിക്കുന്ന ഏവനും നശിച്ചുപോകാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്നു ദൈവം അവനെ നല്കുവാൻ തക്കവണ്ണം ലോകത്തെ സ്നേഹിച്ചു.', 'യോഹന്നാൻ 3:16'),
    -- Romans 10:9
    ('a0000001-0000-0000-0000-000000000002', 'en', 'Because, if you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved.', 'Romans 10:9'),
    ('a0000001-0000-0000-0000-000000000002', 'hi', 'क्योंकि यदि तू अपने मुंह से यीशु को प्रभु जानकर अंगीकार करे और अपने मन से विश्वास करे कि परमेश्वर ने उसे मरे हुओं में से जिलाया, तो तू निश्चय उद्धार पाएगा।', 'रोमियों 10:9'),
    ('a0000001-0000-0000-0000-000000000002', 'ml', 'യേശുവിനെ കർത്താവു എന്നു വായ്കൊണ്ടു ഏറ്റുപറകയും ദൈവം അവനെ മരിച്ചവരിൽനിന്നു ഉയിർത്തെഴുന്നേല്പിച്ചു എന്നു ഹൃദയംകൊണ്ടു വിശ്വസിക്കയും ചെയ്താൽ നീ രക്ഷിക്കപ്പെടും.', 'റോമർ 10:9'),
    -- Ephesians 2:8-9
    ('a0000001-0000-0000-0000-000000000003', 'en', 'For by grace you have been saved through faith. And this is not your own doing; it is the gift of God, not a result of works, so that no one may boast.', 'Ephesians 2:8-9'),
    ('a0000001-0000-0000-0000-000000000003', 'hi', 'क्योंकि विश्वास के द्वारा अनुग्रह ही से तुम्हारा उद्धार हुआ है; और यह तुम्हारी ओर से नहीं, वरन् परमेश्वर का दान है, और न कर्मों के कारण, ऐसा न हो कि कोई घमंड करे।', 'इफिसियों 2:8-9'),
    ('a0000001-0000-0000-0000-000000000003', 'ml', 'കൃപയാലല്ലോ നിങ്ങൾ വിശ്വാസംമൂലം രക്ഷിക്കപ്പെട്ടിരിക്കുന്നതു; അതിന്നും നിങ്ങൾ കാരണമല്ല; ദൈവത്തിന്റെ ദാനമത്രേ ആകുന്നു. പ്രവൃത്തികളാലല്ല, ആരും പ്രശംസിക്കാതിരിപ്പാൻ തന്നേ.', 'എഫെസ്യർ 2:8-9'),
    -- Acts 16:31
    ('a0000001-0000-0000-0000-000000000004', 'en', 'And they said, "Believe in the Lord Jesus, and you will be saved, you and your household."', 'Acts 16:31'),
    ('a0000001-0000-0000-0000-000000000004', 'hi', 'उन्होंने कहा, "प्रभु यीशु मसीह पर विश्वास कर, तो तू और तेरा घराना उद्धार पाएगा।"', 'प्रेरितों के काम 16:31'),
    ('a0000001-0000-0000-0000-000000000004', 'ml', 'കർത്താവായ യേശുവിൽ വിശ്വസിക്ക; എന്നാൽ നീയും നിന്റെ കുടുംബവും രക്ഷിക്കപ്പെടും എന്നു അവർ പറഞ്ഞു.', 'അപ്പൊ. പ്രവൃത്തികൾ 16:31'),
    -- Romans 6:23
    ('a0000001-0000-0000-0000-000000000005', 'en', 'For the wages of sin is death, but the free gift of God is eternal life in Christ Jesus our Lord.', 'Romans 6:23'),
    ('a0000001-0000-0000-0000-000000000005', 'hi', 'क्योंकि पाप की मजदूरी तो मृत्यु है, परन्तु परमेश्वर का वरदान हमारे प्रभु यीशु मसीह में अनन्त जीवन है।', 'रोमियों 6:23'),
    ('a0000001-0000-0000-0000-000000000005', 'ml', 'പാപത്തിന്റെ ശമ്പളം മരണമത്രേ; ദൈവത്തിന്റെ കൃപാവരമോ നമ്മുടെ കർത്താവായ യേശുക്രിസ്തുവിൽ നിത്യജീവൻ തന്നേ.', 'റോമർ 6:23')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

-- =============================================================================
-- CATEGORY: COMFORT (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000002-0000-0000-0000-000000000001', 'Psalm 23:1-3', 'Psalms', 23, 1, 3, 'comfort', ARRAY['shepherd', 'rest', 'peace'], 1),
    ('a0000002-0000-0000-0000-000000000002', 'Isaiah 41:10', 'Isaiah', 41, 10, NULL, 'comfort', ARRAY['fear not', 'strength', 'help'], 2),
    ('a0000002-0000-0000-0000-000000000003', 'Matthew 11:28-30', 'Matthew', 11, 28, 30, 'comfort', ARRAY['rest', 'burden', 'peace'], 3),
    ('a0000002-0000-0000-0000-000000000004', 'Philippians 4:6-7', 'Philippians', 4, 6, 7, 'comfort', ARRAY['anxiety', 'prayer', 'peace'], 4),
    ('a0000002-0000-0000-0000-000000000005', '2 Corinthians 1:3-4', '2 Corinthians', 1, 3, 4, 'comfort', ARRAY['comfort', 'affliction', 'mercy'], 5)
ON CONFLICT (id) DO NOTHING;

-- Comfort translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- Psalm 23:1-3
    ('a0000002-0000-0000-0000-000000000001', 'en', 'The Lord is my shepherd; I shall not want. He makes me lie down in green pastures. He leads me beside still waters. He restores my soul.', 'Psalm 23:1-3'),
    ('a0000002-0000-0000-0000-000000000001', 'hi', 'यहोवा मेरा चरवाहा है; मुझे कुछ घटी न होगी। वह मुझे हरी-हरी चराइयों में बैठाता है; वह मुझे सुखदाई जल के झरने के पास ले चलता है। वह मेरे प्राण में जान ले आता है।', 'भजन संहिता 23:1-3'),
    ('a0000002-0000-0000-0000-000000000001', 'ml', 'യഹോവ എന്റെ ഇടയനാകുന്നു; എനിക്കു മുട്ടുണ്ടാകയില്ല. പച്ചയായ പുല്പുറങ്ങളിൽ അവൻ എന്നെ കിടത്തുന്നു; സ്വസ്ഥതയുള്ള വെള്ളത്തിന്നരികത്തു അവൻ എന്നെ നടത്തുന്നു. എന്റെ പ്രാണനെ അവൻ തണുപ്പിക്കുന്നു.', 'സങ്കീർത്തനങ്ങൾ 23:1-3'),
    -- Isaiah 41:10
    ('a0000002-0000-0000-0000-000000000002', 'en', 'Fear not, for I am with you; be not dismayed, for I am your God; I will strengthen you, I will help you, I will uphold you with my righteous right hand.', 'Isaiah 41:10'),
    ('a0000002-0000-0000-0000-000000000002', 'hi', 'मत डर, क्योंकि मैं तेरे साथ हूं; इधर-उधर मत ताक, क्योंकि मैं तेरा परमेश्वर हूं; मैं तुझे दृढ़ करूंगा और तेरी सहायता करूंगा, और अपने धर्ममय दाहिने हाथ से तुझे सम्भाले रहूंगा।', 'यशायाह 41:10'),
    ('a0000002-0000-0000-0000-000000000002', 'ml', 'ഭയപ്പെടേണ്ടാ, ഞാൻ നിന്നോടുകൂടെ ഉണ്ടു; ഭ്രമിക്കേണ്ടാ, ഞാൻ നിന്റെ ദൈവം ആകുന്നു; ഞാൻ നിന്നെ ശക്തീകരിക്കും; ഞാൻ നിന്നെ സഹായിക്കും; എന്റെ നീതിയുള്ള വലങ്കൈകൊണ്ടു ഞാൻ നിന്നെ താങ്ങും.', 'യെശയ്യാവു 41:10'),
    -- Matthew 11:28-30
    ('a0000002-0000-0000-0000-000000000003', 'en', 'Come to me, all who labor and are heavy laden, and I will give you rest. Take my yoke upon you, and learn from me, for I am gentle and lowly in heart, and you will find rest for your souls. For my yoke is easy, and my burden is light.', 'Matthew 11:28-30'),
    ('a0000002-0000-0000-0000-000000000003', 'hi', 'हे सब परिश्रम करनेवालो और बोझ से दबे हुए लोगो, मेरे पास आओ; मैं तुम्हें विश्राम दूंगा। मेरा जूआ अपने ऊपर उठा लो और मुझ से सीखो, क्योंकि मैं नम्र और मन में दीन हूं; और तुम अपने मन में विश्राम पाओगे। क्योंकि मेरा जूआ सहज और मेरा बोझ हलका है।', 'मत्ती 11:28-30'),
    ('a0000002-0000-0000-0000-000000000003', 'ml', 'അദ്ധ്വാനിക്കുന്നവരും ഭാരം ചുമക്കുന്നവരും ആയുള്ളോരേ, എല്ലാവരും എന്റെ അടുക്കൽ വരുവിൻ; ഞാൻ നിങ്ങളെ ആശ്വസിപ്പിക്കാം. ഞാൻ സൗമ്യതയും താഴ്മയും ഉള്ളവൻ ആകയാൽ എന്റെ നുകം ഏറ്റുകൊണ്ടു എന്നോടു പഠിപ്പിൻ; എന്നാൽ നിങ്ങളുടെ ആത്മാക്കൾക്കു ആശ്വാസം കണ്ടെത്തും. എന്റെ നുകം മൃദുവും എന്റെ ചുമടു ലഘുവും ആകുന്നു.', 'മത്തായി 11:28-30'),
    -- Philippians 4:6-7
    ('a0000002-0000-0000-0000-000000000004', 'en', 'Do not be anxious about anything, but in everything by prayer and supplication with thanksgiving let your requests be made known to God. And the peace of God, which surpasses all understanding, will guard your hearts and your minds in Christ Jesus.', 'Philippians 4:6-7'),
    ('a0000002-0000-0000-0000-000000000004', 'hi', 'किसी भी बात की चिन्ता मत करो; परन्तु हर एक बात में तुम्हारे निवेदन प्रार्थना और बिनती के द्वारा धन्यवाद के साथ परमेश्वर के सामने उपस्थित किए जाएं। तब परमेश्वर की शान्ति जो सारी समझ से परे है, तुम्हारे हृदय और तुम्हारे विचारों को मसीह यीशु में सुरक्षित रखेगी।', 'फिलिप्पियों 4:6-7'),
    ('a0000002-0000-0000-0000-000000000004', 'ml', 'ഒന്നിനെക്കുറിച്ചും വിചാരപ്പെടരുതു; എല്ലാറ്റിലും പ്രാർത്ഥനയാലും യാചനയാലും നിങ്ങളുടെ അപേക്ഷകൾ സ്തോത്രത്തോടുകൂടെ ദൈവത്തോടു അറിയിപ്പിൻ. എന്നാൽ സകലബുദ്ധിയേയും കവിയുന്ന ദൈവസമാധാനം നിങ്ങളുടെ ഹൃദയങ്ങളെയും നിനവുകളെയും ക്രിസ്തുയേശുവിൽ കാത്തുകൊള്ളും.', 'ഫിലിപ്പിയർ 4:6-7'),
    -- 2 Corinthians 1:3-4
    ('a0000002-0000-0000-0000-000000000005', 'en', 'Blessed be the God and Father of our Lord Jesus Christ, the Father of mercies and God of all comfort, who comforts us in all our affliction, so that we may be able to comfort those who are in any affliction.', '2 Corinthians 1:3-4'),
    ('a0000002-0000-0000-0000-000000000005', 'hi', 'हमारे प्रभु यीशु मसीह के परमेश्वर और पिता का धन्यवाद हो, जो दया का पिता और सब प्रकार की शान्ति का परमेश्वर है। वह हमारे सब क्लेशों में शान्ति देता है ताकि हम उस शान्ति के कारण जो परमेश्वर हमें देता है, उन्हें भी शान्ति दे सकें जो किसी भी क्लेश में हों।', '2 कुरिन्थियों 1:3-4'),
    ('a0000002-0000-0000-0000-000000000005', 'ml', 'നമ്മുടെ കർത്താവായ യേശുക്രിസ്തുവിന്റെ പിതാവായ ദൈവം വാഴ്ത്തപ്പെട്ടവൻ. അവൻ കരുണയുടെ പിതാവും സകല ആശ്വാസത്തിന്റെയും ദൈവവും ആകുന്നു. ഞങ്ങൾക്കു ദൈവം നല്കുന്ന ആശ്വാസത്താൽ ഏതു കഷ്ടതയിലും ഉള്ളവരെ ആശ്വസിപ്പിപ്പാൻ കഴിയേണ്ടതിന്നു അവൻ ഞങ്ങളുടെ കഷ്ടതയിൽ ഒക്കെയും ഞങ്ങളെ ആശ്വസിപ്പിക്കുന്നു.', '2 കൊരിന്ത്യർ 1:3-4')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

-- =============================================================================
-- CATEGORY: STRENGTH (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000003-0000-0000-0000-000000000001', 'Philippians 4:13', 'Philippians', 4, 13, NULL, 'strength', ARRAY['all things', 'christ', 'power'], 1),
    ('a0000003-0000-0000-0000-000000000002', 'Isaiah 40:31', 'Isaiah', 40, 31, NULL, 'strength', ARRAY['wait', 'renew', 'soar'], 2),
    ('a0000003-0000-0000-0000-000000000003', 'Joshua 1:9', 'Joshua', 1, 9, NULL, 'strength', ARRAY['courage', 'fear not', 'command'], 3),
    ('a0000003-0000-0000-0000-000000000004', 'Psalm 46:1', 'Psalms', 46, 1, NULL, 'strength', ARRAY['refuge', 'help', 'trouble'], 4),
    ('a0000003-0000-0000-0000-000000000005', '2 Timothy 1:7', '2 Timothy', 1, 7, NULL, 'strength', ARRAY['spirit', 'power', 'love'], 5)
ON CONFLICT (id) DO NOTHING;

-- Strength translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- Philippians 4:13
    ('a0000003-0000-0000-0000-000000000001', 'en', 'I can do all things through him who strengthens me.', 'Philippians 4:13'),
    ('a0000003-0000-0000-0000-000000000001', 'hi', 'जो मुझे सामर्थ देता है उसमें मैं सब कुछ कर सकता हूं।', 'फिलिप्पियों 4:13'),
    ('a0000003-0000-0000-0000-000000000001', 'ml', 'എന്നെ ശക്തനാക്കുന്നവൻ മുഖാന്തരം എനിക്കു എല്ലാം കഴിയും.', 'ഫിലിപ്പിയർ 4:13'),
    -- Isaiah 40:31
    ('a0000003-0000-0000-0000-000000000002', 'en', 'But they who wait for the Lord shall renew their strength; they shall mount up with wings like eagles; they shall run and not be weary; they shall walk and not faint.', 'Isaiah 40:31'),
    ('a0000003-0000-0000-0000-000000000002', 'hi', 'परन्तु जो यहोवा की बाट जोहते हैं, वे नया बल प्राप्त करते जाएंगे; वे उकाबों की नाईं उड़ेंगे; वे दौड़ेंगे और थकित न होंगे; वे चलेंगे और शिथिल न होंगे।', 'यशायाह 40:31'),
    ('a0000003-0000-0000-0000-000000000002', 'ml', 'യഹോവയെ കാത്തിരിക്കുന്നവരോ ശക്തി പുതുക്കും; അവർ കഴുകന്മാരെപ്പോലെ ചിറകടിച്ചു പറക്കും; അവർ ഓടിയാലും ക്ഷീണിക്കയില്ല; നടന്നാലും തളർന്നുപോകയില്ല.', 'യെശയ്യാവു 40:31'),
    -- Joshua 1:9
    ('a0000003-0000-0000-0000-000000000003', 'en', 'Have I not commanded you? Be strong and courageous. Do not be frightened, and do not be dismayed, for the Lord your God is with you wherever you go.', 'Joshua 1:9'),
    ('a0000003-0000-0000-0000-000000000003', 'hi', 'क्या मैंने तुझे आज्ञा नहीं दी? हियाव बांध और दृढ़ हो। मत डर और भय मत खा, क्योंकि जहां कहीं तू जाएगा वहां तेरा परमेश्वर यहोवा तेरे साथ रहेगा।', 'यहोशू 1:9'),
    ('a0000003-0000-0000-0000-000000000003', 'ml', 'ഞാൻ നിന്നോടു കല്പിച്ചിട്ടില്ലയോ? ഉറച്ചും ധൈര്യമായും ഇരിക്ക; ഭയപ്പെടരുതു, ഭ്രമിക്കയും അരുതു; നീ പോകുന്നിടത്തൊക്കെയും നിന്റെ ദൈവമായ യഹോവ നിന്നോടുകൂടെ ഉണ്ടു.', 'യോശുവ 1:9'),
    -- Psalm 46:1
    ('a0000003-0000-0000-0000-000000000004', 'en', 'God is our refuge and strength, a very present help in trouble.', 'Psalm 46:1'),
    ('a0000003-0000-0000-0000-000000000004', 'hi', 'परमेश्वर हमारा शरणस्थान और बल है, संकट में अति सहज से मिलनेवाला सहायक।', 'भजन संहिता 46:1'),
    ('a0000003-0000-0000-0000-000000000004', 'ml', 'ദൈവം നമ്മുടെ സങ്കേതവും ബലവും ആകുന്നു; കഷ്ടങ്ങളിൽ അവൻ ഏറ്റവും അടുത്ത തുണയായിരിക്കുന്നു.', 'സങ്കീർത്തനങ്ങൾ 46:1'),
    -- 2 Timothy 1:7
    ('a0000003-0000-0000-0000-000000000005', 'en', 'For God gave us a spirit not of fear but of power and love and self-control.', '2 Timothy 1:7'),
    ('a0000003-0000-0000-0000-000000000005', 'hi', 'क्योंकि परमेश्वर ने हमें भय की आत्मा नहीं, पर सामर्थ और प्रेम और संयम की आत्मा दी है।', '2 तीमुथियुस 1:7'),
    ('a0000003-0000-0000-0000-000000000005', 'ml', 'ദൈവം നമുക്കു ഭീരുത്വത്തിന്റെ ആത്മാവിനെ അല്ല, ശക്തിയുടെയും സ്നേഹത്തിന്റെയും സുബോധത്തിന്റെയും ആത്മാവിനെ അത്രേ തന്നതു.', '2 തിമൊഥെയൊസ് 1:7')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

-- =============================================================================
-- CATEGORY: WISDOM (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000004-0000-0000-0000-000000000001', 'Proverbs 3:5-6', 'Proverbs', 3, 5, 6, 'wisdom', ARRAY['trust', 'understanding', 'paths'], 1),
    ('a0000004-0000-0000-0000-000000000002', 'James 1:5', 'James', 1, 5, NULL, 'wisdom', ARRAY['ask', 'generously', 'doubt'], 2),
    ('a0000004-0000-0000-0000-000000000003', 'Proverbs 2:6', 'Proverbs', 2, 6, NULL, 'wisdom', ARRAY['lord', 'knowledge', 'understanding'], 3),
    ('a0000004-0000-0000-0000-000000000004', 'Psalm 119:105', 'Psalms', 119, 105, NULL, 'wisdom', ARRAY['lamp', 'light', 'word'], 4),
    ('a0000004-0000-0000-0000-000000000005', 'Colossians 3:16', 'Colossians', 3, 16, NULL, 'wisdom', ARRAY['word', 'teach', 'thankfulness'], 5)
ON CONFLICT (id) DO NOTHING;

-- Wisdom translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- Proverbs 3:5-6
    ('a0000004-0000-0000-0000-000000000001', 'en', 'Trust in the Lord with all your heart, and do not lean on your own understanding. In all your ways acknowledge him, and he will make straight your paths.', 'Proverbs 3:5-6'),
    ('a0000004-0000-0000-0000-000000000001', 'hi', 'तू अपनी समझ का सहारा न लेना, वरन् सम्पूर्ण मन से यहोवा पर भरोसा रखना। उसी को स्मरण करके सब काम करना, तब वह तेरे लिये सीधा मार्ग निकालेगा।', 'नीतिवचन 3:5-6'),
    ('a0000004-0000-0000-0000-000000000001', 'ml', 'പൂർണ്ണഹൃദയത്തോടെ യഹോവയിൽ ആശ്രയിക്ക; സ്വന്ത വിവേകത്തിൽ ഊന്നരുതു. നിന്റെ എല്ലാവഴികളിലും അവനെ നിനച്ചുകൊൾക; അവൻ നിന്റെ പാതകളെ നേരെയാക്കും.', 'സദൃശവാക്യങ്ങൾ 3:5-6'),
    -- James 1:5
    ('a0000004-0000-0000-0000-000000000002', 'en', 'If any of you lacks wisdom, let him ask God, who gives generously to all without reproach, and it will be given him.', 'James 1:5'),
    ('a0000004-0000-0000-0000-000000000002', 'hi', 'यदि तुम में से किसी को बुद्धि की घटी हो तो परमेश्वर से मांगे, जो बिना उलाहना दिए सब को उदारता से देता है; और उसे दी जाएगी।', 'याकूब 1:5'),
    ('a0000004-0000-0000-0000-000000000002', 'ml', 'നിങ്ങളിൽ ഒരുത്തന്നു ജ്ഞാനം കുറവുണ്ടെങ്കിൽ ശാസിക്കാതെ എല്ലാവർക്കും ഔദാര്യമായി കൊടുക്കുന്ന ദൈവത്തോടു യാചിക്കട്ടെ; അപ്പോൾ അവന്നു ലഭിക്കും.', 'യാക്കോബ് 1:5'),
    -- Proverbs 2:6
    ('a0000004-0000-0000-0000-000000000003', 'en', 'For the Lord gives wisdom; from his mouth come knowledge and understanding.', 'Proverbs 2:6'),
    ('a0000004-0000-0000-0000-000000000003', 'hi', 'क्योंकि बुद्धि यहोवा ही देता है; ज्ञान और समझ की बातें उसी के मुंह से निकलती हैं।', 'नीतिवचन 2:6'),
    ('a0000004-0000-0000-0000-000000000003', 'ml', 'യഹോവ ജ്ഞാനം നല്കുന്നു; അവന്റെ വായിൽനിന്നു പരിജ്ഞാനവും വിവേകവും വരുന്നു.', 'സദൃശവാക്യങ്ങൾ 2:6'),
    -- Psalm 119:105
    ('a0000004-0000-0000-0000-000000000004', 'en', 'Your word is a lamp to my feet and a light to my path.', 'Psalm 119:105'),
    ('a0000004-0000-0000-0000-000000000004', 'hi', 'तेरा वचन मेरे पांव के लिए दीपक और मेरे मार्ग के लिए उजियाला है।', 'भजन संहिता 119:105'),
    ('a0000004-0000-0000-0000-000000000004', 'ml', 'നിന്റെ വചനം എന്റെ കാലിന്നു ദീപവും എന്റെ പാതെക്കു പ്രകാശവും ആകുന്നു.', 'സങ്കീർത്തനങ്ങൾ 119:105'),
    -- Colossians 3:16
    ('a0000004-0000-0000-0000-000000000005', 'en', 'Let the word of Christ dwell in you richly, teaching and admonishing one another in all wisdom, singing psalms and hymns and spiritual songs, with thankfulness in your hearts to God.', 'Colossians 3:16'),
    ('a0000004-0000-0000-0000-000000000005', 'hi', 'मसीह का वचन तुम्हारे हृदय में बहुतायत से बसा रहे; और तुम सब प्रकार की बुद्धि से एक दूसरे को सिखाते और चेतावनी देते रहो, और अपने-अपने मन में परमेश्वर का धन्यवाद करते हुए भजन और स्तुतिगान और आत्मिक गीत गाया करो।', 'कुलुस्सियों 3:16'),
    ('a0000004-0000-0000-0000-000000000005', 'ml', 'ക്രിസ്തുവിന്റെ വചനം സകല ജ്ഞാനത്തോടുംകൂടെ സമൃദ്ധിയായി നിങ്ങളിൽ വസിക്കട്ടെ; സങ്കീർത്തനങ്ങളാലും സ്തുതിഗീതങ്ങളാലും ആത്മികഗാനങ്ങളാലും തമ്മിൽ ഉപദേശിച്ചും ബുദ്ധിപറഞ്ഞുംകൊണ്ടു നിങ്ങളുടെ ഹൃദയങ്ങളിൽ കൃപയോടെ ദൈവത്തിന്നു പാടുവിൻ.', 'കൊലൊസ്സ്യർ 3:16')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

-- =============================================================================
-- CATEGORY: PROMISE (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000005-0000-0000-0000-000000000001', 'Jeremiah 29:11', 'Jeremiah', 29, 11, NULL, 'promise', ARRAY['plans', 'hope', 'future'], 1),
    ('a0000005-0000-0000-0000-000000000002', 'Romans 8:28', 'Romans', 8, 28, NULL, 'promise', ARRAY['good', 'purpose', 'love'], 2),
    ('a0000005-0000-0000-0000-000000000003', 'Psalm 37:4', 'Psalms', 37, 4, NULL, 'promise', ARRAY['delight', 'desires', 'heart'], 3),
    ('a0000005-0000-0000-0000-000000000004', 'Philippians 1:6', 'Philippians', 1, 6, NULL, 'promise', ARRAY['work', 'completion', 'day of christ'], 4),
    ('a0000005-0000-0000-0000-000000000005', 'Matthew 6:33', 'Matthew', 6, 33, NULL, 'promise', ARRAY['kingdom', 'seek', 'added'], 5)
ON CONFLICT (id) DO NOTHING;

-- Promise translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- Jeremiah 29:11
    ('a0000005-0000-0000-0000-000000000001', 'en', 'For I know the plans I have for you, declares the Lord, plans for welfare and not for evil, to give you a future and a hope.', 'Jeremiah 29:11'),
    ('a0000005-0000-0000-0000-000000000001', 'hi', 'क्योंकि मैं जानता हूं कि मैंने तुम्हारे लिए कैसी कल्पनाएं की हैं, यहोवा की यह वाणी है, अर्थात् कुशल ही की नहीं, विपत्ति की नहीं, कि तुम्हें भविष्य में आशा देने की।', 'यिर्मयाह 29:11'),
    ('a0000005-0000-0000-0000-000000000001', 'ml', 'നിങ്ങൾക്കു ഭാവിയും പ്രത്യാശയും ലഭിപ്പാൻ തക്കവണ്ണം ഞാൻ നിങ്ങളെക്കുറിച്ചു നിരൂപിക്കുന്ന വിചാരങ്ങൾ ഇന്നവ എന്നു ഞാൻ അറിയുന്നു; അവ തിന്മെക്കല്ല, നന്മെക്കുള്ള വിചാരങ്ങൾ തന്നേ എന്നു യഹോവയുടെ അരുളപ്പാടു.', 'യിരെമ്യാവു 29:11'),
    -- Romans 8:28
    ('a0000005-0000-0000-0000-000000000002', 'en', 'And we know that for those who love God all things work together for good, for those who are called according to his purpose.', 'Romans 8:28'),
    ('a0000005-0000-0000-0000-000000000002', 'hi', 'और हम जानते हैं कि जो लोग परमेश्वर से प्रेम रखते हैं, उनके लिए सब बातें मिलकर भलाई ही को उत्पन्न करती हैं; अर्थात् उन्हीं के लिए जो उसकी इच्छा के अनुसार बुलाए हुए हैं।', 'रोमियों 8:28'),
    ('a0000005-0000-0000-0000-000000000002', 'ml', 'ദൈവത്തെ സ്നേഹിക്കുന്നവർക്കു, നിർണ്ണയപ്രകാരം വിളിക്കപ്പെട്ടവർക്കു തന്നേ, സകലവും നന്മെക്കായി കൂടി വ്യാപരിക്കുന്നു എന്നു നാം അറിയുന്നു.', 'റോമർ 8:28'),
    -- Psalm 37:4
    ('a0000005-0000-0000-0000-000000000003', 'en', 'Delight yourself in the Lord, and he will give you the desires of your heart.', 'Psalm 37:4'),
    ('a0000005-0000-0000-0000-000000000003', 'hi', 'यहोवा को अपने सुख का मूल जान, और वह तेरे मनोरथों को पूरा करेगा।', 'भजन संहिता 37:4'),
    ('a0000005-0000-0000-0000-000000000003', 'ml', 'യഹോവയിൽ തന്നേ രസിച്ചുകൊൾക; അവൻ നിന്റെ ഹൃദയത്തിലെ ആഗ്രഹങ്ങളെ നിനക്കു തരും.', 'സങ്കീർത്തനങ്ങൾ 37:4'),
    -- Philippians 1:6
    ('a0000005-0000-0000-0000-000000000004', 'en', 'And I am sure of this, that he who began a good work in you will bring it to completion at the day of Jesus Christ.', 'Philippians 1:6'),
    ('a0000005-0000-0000-0000-000000000004', 'hi', 'मुझे इस बात का भरोसा है कि जिसने तुम में अच्छा काम आरम्भ किया है वही उसे यीशु मसीह के दिन तक पूरा करेगा।', 'फिलिप्पियों 1:6'),
    ('a0000005-0000-0000-0000-000000000004', 'ml', 'നിങ്ങളിൽ നല്ല പ്രവൃത്തി ആരംഭിച്ചവൻ അതു യേശുക്രിസ്തുവിന്റെ നാളോളം തികയ്ക്കും എന്നു ഞാൻ ഉറച്ചിരിക്കുന്നു.', 'ഫിലിപ്പിയർ 1:6'),
    -- Matthew 6:33
    ('a0000005-0000-0000-0000-000000000005', 'en', 'But seek first the kingdom of God and his righteousness, and all these things will be added to you.', 'Matthew 6:33'),
    ('a0000005-0000-0000-0000-000000000005', 'hi', 'इसलिए पहले तुम परमेश्वर के राज्य और उसकी धार्मिकता की खोज करो तो ये सब वस्तुएं भी तुम्हें मिल जाएंगी।', 'मत्ती 6:33'),
    ('a0000005-0000-0000-0000-000000000005', 'ml', 'മുമ്പെ അവന്റെ രാജ്യവും നീതിയും അന്വേഷിപ്പിൻ; അതോടുകൂടെ ഇതൊക്കെയും നിങ്ങൾക്കു കിട്ടും.', 'മത്തായി 6:33')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

-- =============================================================================
-- CATEGORY: GUIDANCE (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000006-0000-0000-0000-000000000001', 'Psalm 32:8', 'Psalms', 32, 8, NULL, 'guidance', ARRAY['instruct', 'teach', 'eye'], 1),
    ('a0000006-0000-0000-0000-000000000002', 'Proverbs 16:9', 'Proverbs', 16, 9, NULL, 'guidance', ARRAY['heart', 'plans', 'steps'], 2),
    ('a0000006-0000-0000-0000-000000000003', 'Isaiah 30:21', 'Isaiah', 30, 21, NULL, 'guidance', ARRAY['ears', 'voice', 'way'], 3),
    ('a0000006-0000-0000-0000-000000000004', 'Psalm 25:4-5', 'Psalms', 25, 4, 5, 'guidance', ARRAY['ways', 'paths', 'teach'], 4),
    ('a0000006-0000-0000-0000-000000000005', 'Proverbs 16:3', 'Proverbs', 16, 3, NULL, 'guidance', ARRAY['commit', 'works', 'established'], 5)
ON CONFLICT (id) DO NOTHING;

-- Guidance translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- Psalm 32:8
    ('a0000006-0000-0000-0000-000000000001', 'en', 'I will instruct you and teach you in the way you should go; I will counsel you with my eye upon you.', 'Psalm 32:8'),
    ('a0000006-0000-0000-0000-000000000001', 'hi', 'मैं तुझे बुद्धि दूंगा, और जिस मार्ग में तुझे चलना है उसमें तेरी अगुवाई करूंगा; मैं तुझ पर दृष्टि रखकर तुझे सम्मति दूंगा।', 'भजन संहिता 32:8'),
    ('a0000006-0000-0000-0000-000000000001', 'ml', 'ഞാൻ നിനക്കു ഉപദേശം തരും; നീ പോകേണ്ടുന്ന വഴി നിന്നെ പഠിപ്പിക്കും; എന്റെ കണ്ണു നിന്റെമേൽ വെച്ചു ഞാൻ നിനക്കു ആലോചന പറഞ്ഞുതരും.', 'സങ്കീർത്തനങ്ങൾ 32:8'),
    -- Proverbs 16:9
    ('a0000006-0000-0000-0000-000000000002', 'en', 'The heart of man plans his way, but the Lord establishes his steps.', 'Proverbs 16:9'),
    ('a0000006-0000-0000-0000-000000000002', 'hi', 'मनुष्य मन में अपने मार्ग की कल्पना करता है, परन्तु यहोवा ही उसके पग को स्थिर करता है।', 'नीतिवचन 16:9'),
    ('a0000006-0000-0000-0000-000000000002', 'ml', 'മനുഷ്യന്റെ ഹൃദയം അവന്റെ വഴി ആലോചിക്കുന്നു; യഹോവയോ അവന്റെ കാലടികളെ നേരെയാക്കുന്നു.', 'സദൃശവാക്യങ്ങൾ 16:9'),
    -- Isaiah 30:21
    ('a0000006-0000-0000-0000-000000000003', 'en', 'And your ears shall hear a word behind you, saying, "This is the way, walk in it," when you turn to the right or when you turn to the left.', 'Isaiah 30:21'),
    ('a0000006-0000-0000-0000-000000000003', 'hi', 'और जब तुम दाहिने या बाएं मुड़ो, तब तुम्हारे पीछे से यह वचन तुम्हारे कानों में पड़ेगा: "मार्ग यही है, इसी पर चलो।"', 'यशायाह 30:21'),
    ('a0000006-0000-0000-0000-000000000003', 'ml', 'നിങ്ങൾ വലത്തോട്ടോ ഇടത്തോട്ടോ തിരിയുമ്പോൾ: ഇതാകുന്നു വഴി, ഇതിൽ നടപ്പിൻ എന്നു നിങ്ങളുടെ പിന്നിൽനിന്നു ഒരു വാക്കു നിങ്ങളുടെ ചെവികൾ കേൾക്കും.', 'യെശയ്യാവു 30:21'),
    -- Psalm 25:4-5
    ('a0000006-0000-0000-0000-000000000004', 'en', 'Make me to know your ways, O Lord; teach me your paths. Lead me in your truth and teach me, for you are the God of my salvation; for you I wait all the day long.', 'Psalm 25:4-5'),
    ('a0000006-0000-0000-0000-000000000004', 'hi', 'हे यहोवा, अपने मार्ग मुझे दिखा; अपने पथ मुझे सिखा। मुझे अपने सत्य पर चला और मुझे शिक्षा दे, क्योंकि तू मेरा उद्धारकर्ता परमेश्वर है; मैं दिन भर तेरी बाट जोहता रहता हूं।', 'भजन संहिता 25:4-5'),
    ('a0000006-0000-0000-0000-000000000004', 'ml', 'യഹോവേ, നിന്റെ വഴികളെ എനിക്കു കാണിച്ചുതരേണമേ; നിന്റെ പാതകളെ എന്നെ പഠിപ്പിക്കേണമേ. നിന്റെ സത്യത്തിൽ എന്നെ നടത്തി പഠിപ്പിക്കേണമേ; നീ എന്റെ രക്ഷയുടെ ദൈവം; ഞാൻ ദിവസം മുഴുവനും നിന്നെ കാത്തിരിക്കുന്നു.', 'സങ്കീർത്തനങ്ങൾ 25:4-5'),
    -- Proverbs 16:3
    ('a0000006-0000-0000-0000-000000000005', 'en', 'Commit your work to the Lord, and your plans will be established.', 'Proverbs 16:3'),
    ('a0000006-0000-0000-0000-000000000005', 'hi', 'अपने कामों को यहोवा को सौंप दे, तब तेरी योजनाएं सफल होंगी।', 'नीतिवचन 16:3'),
    ('a0000006-0000-0000-0000-000000000005', 'ml', 'നിന്റെ പ്രവൃത്തികളെ യഹോവയിങ്കൽ സമർപ്പിക്ക; എന്നാൽ നിന്റെ ആലോചനകൾ സാധിക്കും.', 'സദൃശവാക്യങ്ങൾ 16:3')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

-- =============================================================================
-- CATEGORY: FAITH (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000007-0000-0000-0000-000000000001', 'Hebrews 11:1', 'Hebrews', 11, 1, NULL, 'faith', ARRAY['substance', 'evidence', 'hope'], 1),
    ('a0000007-0000-0000-0000-000000000002', 'Romans 10:17', 'Romans', 10, 17, NULL, 'faith', ARRAY['hearing', 'word', 'christ'], 2),
    ('a0000007-0000-0000-0000-000000000003', 'Mark 11:24', 'Mark', 11, 24, NULL, 'faith', ARRAY['prayer', 'believe', 'receive'], 3),
    ('a0000007-0000-0000-0000-000000000004', 'Matthew 17:20', 'Matthew', 17, 20, NULL, 'faith', ARRAY['mustard seed', 'mountain', 'nothing impossible'], 4),
    ('a0000007-0000-0000-0000-000000000005', '2 Corinthians 5:7', '2 Corinthians', 5, 7, NULL, 'faith', ARRAY['walk', 'sight', 'faith'], 5)
ON CONFLICT (id) DO NOTHING;

-- Faith translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- Hebrews 11:1
    ('a0000007-0000-0000-0000-000000000001', 'en', 'Now faith is the assurance of things hoped for, the conviction of things not seen.', 'Hebrews 11:1'),
    ('a0000007-0000-0000-0000-000000000001', 'hi', 'विश्वास आशा की हुई वस्तुओं का निश्चय और अनदेखी वस्तुओं का प्रमाण है।', 'इब्रानियों 11:1'),
    ('a0000007-0000-0000-0000-000000000001', 'ml', 'വിശ്വാസം എന്നതോ, ആശിക്കുന്നവയുടെ ഉറപ്പും കാണാത്ത കാര്യങ്ങളുടെ നിശ്ചയവും ആകുന്നു.', 'എബ്രായർ 11:1'),
    -- Romans 10:17
    ('a0000007-0000-0000-0000-000000000002', 'en', 'So faith comes from hearing, and hearing through the word of Christ.', 'Romans 10:17'),
    ('a0000007-0000-0000-0000-000000000002', 'hi', 'सो विश्वास सुनने से और सुनना मसीह के वचन से होता है।', 'रोमियों 10:17'),
    ('a0000007-0000-0000-0000-000000000002', 'ml', 'ആകയാൽ വിശ്വാസം കേൾവിയാലും കേൾവി ക്രിസ്തുവിന്റെ വചനത്താലും വരുന്നു.', 'റോമർ 10:17'),
    -- Mark 11:24
    ('a0000007-0000-0000-0000-000000000003', 'en', 'Therefore I tell you, whatever you ask in prayer, believe that you have received it, and it will be yours.', 'Mark 11:24'),
    ('a0000007-0000-0000-0000-000000000003', 'hi', 'इसलिए मैं तुम से कहता हूं कि जो कुछ तुम प्रार्थना में मांगो, प्रतीति करो कि तुम्हें मिल गया; और वह तुम्हें मिल जाएगा।', 'मरकुस 11:24'),
    ('a0000007-0000-0000-0000-000000000003', 'ml', 'അതുകൊണ്ടു നിങ്ങൾ പ്രാർത്ഥിക്കുമ്പോൾ യാചിക്കുന്നതൊക്കെയും ലഭിച്ചു എന്നു വിശ്വസിപ്പിൻ; എന്നാൽ അതു നിങ്ങൾക്കു ഉണ്ടാകും എന്നു ഞാൻ നിങ്ങളോടു പറയുന്നു.', 'മർക്കൊസ് 11:24'),
    -- Matthew 17:20
    ('a0000007-0000-0000-0000-000000000004', 'en', 'He said to them, "Because of your little faith. For truly, I say to you, if you have faith like a grain of mustard seed, you will say to this mountain, ''Move from here to there,'' and it will move, and nothing will be impossible for you."', 'Matthew 17:20'),
    ('a0000007-0000-0000-0000-000000000004', 'hi', 'उसने उनसे कहा, "अपने अविश्वास के कारण; क्योंकि मैं तुम से सच कहता हूं, यदि तुम्हारा विश्वास राई के दाने के बराबर भी हो, तो इस पहाड़ से कह सकोगे, ''यहां से सरककर वहां चला जा,'' और वह चला जाएगा; और कोई बात तुम्हारे लिए अनहोनी न होगी।"', 'मत्ती 17:20'),
    ('a0000007-0000-0000-0000-000000000004', 'ml', 'അവൻ അവരോടു: നിങ്ങളുടെ അല്പവിശ്വാസം നിമിത്തം തന്നേ; കടുകുമണിയോളം വിശ്വാസം ഉണ്ടെങ്കിൽ ഈ മലയോടു: ഇവിടെനിന്നു അവിടേക്കു നീങ്ങുക എന്നു പറഞ്ഞാൽ അതു നീങ്ങും; നിങ്ങൾക്കു ഒന്നും അസാദ്ധ്യമാകയുമില്ല എന്നു ഞാൻ സത്യമായി നിങ്ങളോടു പറയുന്നു.', 'മത്തായി 17:20'),
    -- 2 Corinthians 5:7
    ('a0000007-0000-0000-0000-000000000005', 'en', 'For we walk by faith, not by sight.', '2 Corinthians 5:7'),
    ('a0000007-0000-0000-0000-000000000005', 'hi', 'क्योंकि हम विश्वास से चलते हैं, न कि देखने से।', '2 कुरिन्थियों 5:7'),
    ('a0000007-0000-0000-0000-000000000005', 'ml', 'കാഴ്ചയാലല്ല വിശ്വാസത്താലത്രേ നാം നടക്കുന്നതു.', '2 കൊരിന്ത്യർ 5:7')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

-- =============================================================================
-- CATEGORY: LOVE (5 verses)
-- =============================================================================

INSERT INTO suggested_verses (id, reference, book, chapter, verse_start, verse_end, category, tags, display_order)
VALUES
    ('a0000008-0000-0000-0000-000000000001', '1 Corinthians 13:4-7', '1 Corinthians', 13, 4, 7, 'love', ARRAY['patient', 'kind', 'endures'], 1),
    ('a0000008-0000-0000-0000-000000000002', 'John 15:13', 'John', 15, 13, NULL, 'love', ARRAY['greater love', 'lay down', 'friends'], 2),
    ('a0000008-0000-0000-0000-000000000003', 'Romans 8:38-39', 'Romans', 8, 38, 39, 'love', ARRAY['nothing', 'separate', 'god''s love'], 3),
    ('a0000008-0000-0000-0000-000000000004', '1 John 4:19', '1 John', 4, 19, NULL, 'love', ARRAY['we love', 'first loved'], 4),
    ('a0000008-0000-0000-0000-000000000005', '1 John 4:7-8', '1 John', 4, 7, 8, 'love', ARRAY['love one another', 'god is love'], 5)
ON CONFLICT (id) DO NOTHING;

-- Love translations
INSERT INTO suggested_verse_translations (suggested_verse_id, language_code, verse_text, localized_reference)
VALUES
    -- 1 Corinthians 13:4-7
    ('a0000008-0000-0000-0000-000000000001', 'en', 'Love is patient and kind; love does not envy or boast; it is not arrogant or rude. It does not insist on its own way; it is not irritable or resentful; it does not rejoice at wrongdoing, but rejoices with the truth. Love bears all things, believes all things, hopes all things, endures all things.', '1 Corinthians 13:4-7'),
    ('a0000008-0000-0000-0000-000000000001', 'hi', 'प्रेम धीरजवन्त है, और कृपालु है; प्रेम डाह नहीं करता; प्रेम अपनी बड़ाई नहीं करता, और फूलता नहीं। वह अनरीति नहीं चलता, वह अपनी भलाई नहीं चाहता, झुंझलाता नहीं, बुरा नहीं मानता। कुकर्म से आनन्दित नहीं होता, परन्तु सत्य से आनन्दित होता है। वह सब बातें सह लेता है, सब बातों पर विश्वास करता है, सब बातों की आशा रखता है, सब बातों में धीरज धरता है।', '1 कुरिन्थियों 13:4-7'),
    ('a0000008-0000-0000-0000-000000000001', 'ml', 'സ്നേഹം ദീർഘക്ഷമയും ദയയും ഉള്ളതു; സ്നേഹം അസൂയപ്പെടുന്നില്ല; സ്നേഹം നിഗളിക്കുന്നില്ല, ചീർക്കുന്നില്ല, അയോഗ്യമായി നടക്കുന്നില്ല, സ്വാർത്ഥം അന്വേഷിക്കുന്നില്ല, ദ്വേഷ്യപ്പെടുന്നില്ല, ദോഷം കണക്കിടുന്നില്ല; അനീതിയിൽ സന്തോഷിക്കാതെ സത്യത്തിൽ സന്തോഷിക്കുന്നു; എല്ലാം പൊറുക്കുന്നു, എല്ലാം വിശ്വസിക്കുന്നു, എല്ലാം പ്രത്യാശിക്കുന്നു, എല്ലാം സഹിക്കുന്നു.', '1 കൊരിന്ത്യർ 13:4-7'),
    -- John 15:13
    ('a0000008-0000-0000-0000-000000000002', 'en', 'Greater love has no one than this, that someone lay down his life for his friends.', 'John 15:13'),
    ('a0000008-0000-0000-0000-000000000002', 'hi', 'इससे बड़ा प्रेम किसी का नहीं कि कोई अपने मित्रों के लिए अपना प्राण दे।', 'यूहन्ना 15:13'),
    ('a0000008-0000-0000-0000-000000000002', 'ml', 'സ്നേഹിതന്മാർക്കുവേണ്ടി ജീവനെ കൊടുക്കുന്നതിലും അധികമായ സ്നേഹം ആർക്കും ഇല്ല.', 'യോഹന്നാൻ 15:13'),
    -- Romans 8:38-39
    ('a0000008-0000-0000-0000-000000000003', 'en', 'For I am sure that neither death nor life, nor angels nor rulers, nor things present nor things to come, nor powers, nor height nor depth, nor anything else in all creation, will be able to separate us from the love of God in Christ Jesus our Lord.', 'Romans 8:38-39'),
    ('a0000008-0000-0000-0000-000000000003', 'hi', 'क्योंकि मुझे निश्चय है कि न मृत्यु, न जीवन, न स्वर्गदूत, न प्रधानताएं, न वर्तमान, न भविष्य, न सामर्थ, न ऊंचाई, न गहराई और न कोई दूसरी सृष्टि हमें परमेश्वर के प्रेम से जो हमारे प्रभु मसीह यीशु में है, अलग कर सकेगी।', 'रोमियों 8:38-39'),
    ('a0000008-0000-0000-0000-000000000003', 'ml', 'മരണത്തിന്നോ ജീവന്നോ ദൂതന്മാർക്കോ വാഴ്ചകൾക്കോ ഇപ്പോഴുള്ളവെക്കോ വരുവാനുള്ളവെക്കോ ശക്തികൾക്കോ ഉയരത്തിന്നോ ആഴത്തിന്നോ മറ്റു യാതൊരു സൃഷ്ടിക്കും നമ്മുടെ കർത്താവായ ക്രിസ്തുയേശുവിലുള്ള ദൈവസ്നേഹത്തിൽനിന്നു നമ്മെ വേർപിരിപ്പാൻ കഴികയില്ല എന്നു ഞാൻ ഉറച്ചിരിക്കുന്നു.', 'റോമർ 8:38-39'),
    -- 1 John 4:19
    ('a0000008-0000-0000-0000-000000000004', 'en', 'We love because he first loved us.', '1 John 4:19'),
    ('a0000008-0000-0000-0000-000000000004', 'hi', 'हम इसलिए प्रेम करते हैं क्योंकि पहले उसने हमसे प्रेम किया।', '1 यूहन्ना 4:19'),
    ('a0000008-0000-0000-0000-000000000004', 'ml', 'അവൻ ആദ്യം നമ്മെ സ്നേഹിച്ചതുകൊണ്ടു നാം സ്നേഹിക്കുന്നു.', '1 യോഹന്നാൻ 4:19'),
    -- 1 John 4:7-8
    ('a0000008-0000-0000-0000-000000000005', 'en', 'Beloved, let us love one another, for love is from God, and whoever loves has been born of God and knows God. Anyone who does not love does not know God, because God is love.', '1 John 4:7-8'),
    ('a0000008-0000-0000-0000-000000000005', 'hi', 'हे प्रियो, हम आपस में प्रेम रखें, क्योंकि प्रेम परमेश्वर से है; और जो कोई प्रेम करता है वह परमेश्वर से जन्मा है और परमेश्वर को जानता है। जो प्रेम नहीं करता वह परमेश्वर को नहीं जानता, क्योंकि परमेश्वर प्रेम है।', '1 यूहन्ना 4:7-8'),
    ('a0000008-0000-0000-0000-000000000005', 'ml', 'പ്രിയമുള്ളവരേ, നാം അന്യോന്യം സ്നേഹിക്ക; സ്നേഹം ദൈവത്തിൽനിന്നു ഉത്ഭവിക്കുന്നു; സ്നേഹിക്കുന്നവൻ എല്ലാം ദൈവത്തിൽനിന്നു ജനിച്ചവനും ദൈവത്തെ അറിയുന്നവനും ആകുന്നു. സ്നേഹിക്കാത്തവൻ ദൈവത്തെ അറിയുന്നില്ല; ദൈവം സ്നേഹം ആകുന്നുവല്ലോ.', '1 യോഹന്നാൻ 4:7-8')
ON CONFLICT ON CONSTRAINT unique_verse_language DO NOTHING;

COMMIT;
