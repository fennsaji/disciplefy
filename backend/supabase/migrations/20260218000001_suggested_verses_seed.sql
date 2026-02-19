-- =============================================================================
-- Seed: Suggested Bible Verses with EN / HI / ML Translations
-- 40 verses · 8 categories · 5 per category
-- Idempotent: safe to re-run (upserts on reference + category)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Helper function (dropped at the end of this migration)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._seed_suggested_verse(
  p_reference   TEXT,
  p_book        TEXT,
  p_chapter     INT,
  p_verse_start INT,
  p_verse_end   INT,
  p_category    TEXT,
  p_tags        TEXT[],
  p_order       INT,
  p_en_text     TEXT,
  p_hi_ref      TEXT,
  p_hi_text     TEXT,
  p_ml_ref      TEXT,
  p_ml_text     TEXT
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id
  FROM public.suggested_verses
  WHERE reference = p_reference AND category = p_category;

  IF v_id IS NULL THEN
    INSERT INTO public.suggested_verses
      (reference, book, chapter, verse_start, verse_end, category, tags, display_order)
    VALUES
      (p_reference, p_book, p_chapter, p_verse_start, p_verse_end, p_category, p_tags, p_order)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.suggested_verses
    SET tags = p_tags, display_order = p_order, is_active = TRUE
    WHERE id = v_id;
  END IF;

  INSERT INTO public.suggested_verse_translations
    (suggested_verse_id, language_code, verse_text, localized_reference)
  VALUES (v_id, 'en', p_en_text, p_reference)
  ON CONFLICT (suggested_verse_id, language_code) DO UPDATE
    SET verse_text = EXCLUDED.verse_text,
        localized_reference = EXCLUDED.localized_reference;

  INSERT INTO public.suggested_verse_translations
    (suggested_verse_id, language_code, verse_text, localized_reference)
  VALUES (v_id, 'hi', p_hi_text, p_hi_ref)
  ON CONFLICT (suggested_verse_id, language_code) DO UPDATE
    SET verse_text = EXCLUDED.verse_text,
        localized_reference = EXCLUDED.localized_reference;

  INSERT INTO public.suggested_verse_translations
    (suggested_verse_id, language_code, verse_text, localized_reference)
  VALUES (v_id, 'ml', p_ml_text, p_ml_ref)
  ON CONFLICT (suggested_verse_id, language_code) DO UPDATE
    SET verse_text = EXCLUDED.verse_text,
        localized_reference = EXCLUDED.localized_reference;
END;
$$;

-- =============================================================================
-- SALVATION (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  'John 3:16','John',3,16,NULL,'salvation',ARRAY['popular','gospel'],1,
  'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
  'यूहन्ना 3:16','क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे, वह नष्ट न हो, परन्तु अनन्त जीवन पाए।',
  'യോഹന്നാൻ 3:16','ദൈവം ലോകത്തെ അത്രമേൽ സ്നേഹിച്ചു, അവൻ തന്റെ ഏകജാതനായ പുത്രനെ നൽകി; അവനിൽ വിശ്വസിക്കുന്ന ഏവനും നശിച്ചുപോകാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്നു തന്നേ.'
);

SELECT public._seed_suggested_verse(
  'Romans 10:9','Romans',10,9,NULL,'salvation',ARRAY['gospel'],2,
  'If you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved.',
  'रोमियों 10:9','कि यदि तू अपने मुँह से यीशु को प्रभु जानकर अंगीकार करे और अपने मन में विश्वास करे कि परमेश्वर ने उसे मरे हुओं में से जिलाया, तो तू उद्धार पाएगा।',
  'റോമർ 10:9','യേശു കർത്താവു എന്നു നിന്റെ വായ്കൊണ്ടു അംഗീകരിക്കയും ദൈവം അവനെ മരിച്ചവരിൽ നിന്നു ഉയിർത്തെഴുന്നേൽപ്പിച്ചു എന്നു നിന്റെ ഹൃദയത്തിൽ വിശ്വസിക്കയും ചെയ്താൽ നീ രക്ഷിക്കപ്പെടും.'
);

SELECT public._seed_suggested_verse(
  'Ephesians 2:8','Ephesians',2,8,NULL,'salvation',ARRAY['grace','gospel'],3,
  'For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God.',
  'इफिसियों 2:8','क्योंकि विश्वास के द्वारा अनुग्रह ही से तुम्हारा उद्धार हुआ है, और यह तुम्हारी ओर से नहीं, वरन् परमेश्वर का दान है।',
  'എഫേസ്യർ 2:8','കൃപയാൽ വിശ്വാസം മൂലം നിങ്ങൾ രക്ഷിക്കപ്പെട്ടിരിക്കുന്നു; അതു നിങ്ങളാൽ അല്ല, ദൈവത്തിന്റെ ദാനമത്രേ.'
);

SELECT public._seed_suggested_verse(
  'Acts 4:12','Acts',4,12,NULL,'salvation',ARRAY['gospel'],4,
  'Salvation is found in no one else, for there is no other name under heaven given to mankind by which we must be saved.',
  'प्रेरितों 4:12','किसी दूसरे के द्वारा उद्धार नहीं; क्योंकि स्वर्ग के नीचे मनुष्यों में कोई दूसरा नाम नहीं दिया गया, जिसके द्वारा हम उद्धार पा सकें।',
  'അ.പ്ര. 4:12','മറ്റൊരുത്തനിൽ രക്ഷ ഇല്ല; ആകാശത്തിൻ കീഴിൽ മനുഷ്യരുടെ ഇടയിൽ നമുക്കു രക്ഷിക്കപ്പെടേണ്ടതിനു ശക്തിയുള്ള മറ്റൊരു നാമവും നൽകപ്പെട്ടിട്ടില്ല.'
);

SELECT public._seed_suggested_verse(
  'Romans 6:23','Romans',6,23,NULL,'salvation',ARRAY['gospel'],5,
  'For the wages of sin is death, but the gift of God is eternal life in Christ Jesus our Lord.',
  'रोमियों 6:23','क्योंकि पाप की मजदूरी तो मृत्यु है, परन्तु परमेश्वर का वरदान हमारे प्रभु यीशु मसीह में अनन्त जीवन है।',
  'റോമർ 6:23','പാപത്തിന്റെ ശമ്പളം മരണം; ദൈവത്തിന്റെ കൃപാദാനമോ നമ്മുടെ കർത്താവായ യേശുക്രിസ്തുവിൽ നിത്യജീവൻ.'
);

-- =============================================================================
-- COMFORT (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  'Matthew 11:28','Matthew',11,28,NULL,'comfort',ARRAY['popular','rest'],1,
  'Come to me, all you who are weary and burdened, and I will give you rest.',
  'मत्ती 11:28','हे सब परिश्रम करने वालो और बोझ से दबे हुए लोगो, मेरे पास आओ; मैं तुम्हें विश्राम दूँगा।',
  'മത്തായി 11:28','അദ്ധ്വാനിക്കുന്നവരും ഭാരം ചുമക്കുന്നവരുമായ നിങ്ങൾ എല്ലാവരും എന്റെ അടുക്കൽ വരുവിൻ; ഞാൻ നിങ്ങൾക്കു ആശ്വാസം നൽകും.'
);

SELECT public._seed_suggested_verse(
  'Psalm 23:4','Psalms',23,4,NULL,'comfort',ARRAY['popular','peace'],2,
  'Even though I walk through the darkest valley, I will fear no evil, for you are with me; your rod and your staff, they comfort me.',
  'भजन संहिता 23:4','चाहे मैं मृत्यु की छाया की तराई में से होकर चलूँ, तौभी बुराई से न डरूँगा, क्योंकि तू मेरे साथ है; तेरे सोंटे और तेरी लाठी से मुझे शान्ति मिलती है।',
  'സങ്കീർത്തനങ്ങൾ 23:4','ഞാൻ മരണനിഴൽ താഴ്‌വരയിൽ നടന്നാലും ദോഷം ഭയപ്പെടുകയില്ല; നീ എന്നോടു കൂടെ ഇരിക്കുന്നു; നിന്റെ വടിയും കോലും എനിക്കു ആശ്വാസം നൽകുന്നു.'
);

SELECT public._seed_suggested_verse(
  'Isaiah 41:10','Isaiah',41,10,NULL,'comfort',ARRAY['popular','fear'],3,
  'So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.',
  'यशायाह 41:10','मत डर, क्योंकि मैं तेरे साथ हूँ; इधर-उधर मत देख, क्योंकि मैं तेरा परमेश्वर हूँ। मैं तुझे दृढ़ करूँगा और तेरी सहायता करूँगा; अपने धर्ममय दाहिने हाथ से मैं तुझे सम्भाले रहूँगा।',
  'യെശയ്യാ 41:10','ഭയപ്പെടേണ്ടാ, ഞാൻ നിന്നോടു കൂടെ ഉണ്ടു; ഭ്രമിച്ചു നോക്കേണ്ടാ, ഞാൻ നിന്റെ ദൈവം ആകുന്നു; ഞാൻ നിന്നെ ശക്തിപ്പെടുത്തും; ഞാൻ നിനക്കു സഹായിക്കും; എന്റെ നീതിയുള്ള വലങ്കൈകൊണ്ടു ഞാൻ നിന്നെ താങ്ങും.'
);

SELECT public._seed_suggested_verse(
  'John 14:27','John',14,27,NULL,'comfort',ARRAY['peace'],4,
  'Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.',
  'यूहन्ना 14:27','मैं तुम्हें शान्ति देता हूँ, अपनी शान्ति तुम्हें देता हूँ; जैसे संसार देता है, मैं तुम्हें वैसे नहीं देता। तुम्हारा मन न घबराए और न डरे।',
  'യോഹന്നാൻ 14:27','സമാധാനം ഞാൻ നിങ്ങൾക്കു വിട്ടേക്കുന്നു; എന്റെ സമാധാനം ഞാൻ നിങ്ങൾക്കു തരുന്നു; ലോകം തരുന്നതുപോലെ ഞാൻ തരുന്നില്ല; നിങ്ങളുടെ ഹൃദയം കലങ്ങരുതു, ഭ്രമിക്കയുമരുതു.'
);

SELECT public._seed_suggested_verse(
  '2 Corinthians 1:3','2 Corinthians',1,3,NULL,'comfort',ARRAY['compassion'],5,
  'Praise be to the God and Father of our Lord Jesus Christ, the Father of compassion and the God of all comfort.',
  '2 कुरिन्थियों 1:3','हमारे प्रभु यीशु मसीह के परमेश्वर और पिता की जय हो, जो दया का पिता और सब प्रकार की शान्ति का परमेश्वर है।',
  '2 കൊരിന്ത്യർ 1:3','കരുണയുടെ പിതാവും സകലാശ്വാസത്തിന്റെ ദൈവവുമായ നമ്മുടെ കർത്താവായ യേശുക്രിസ്തുവിന്റെ ദൈവവും പിതാവുമായവൻ വാഴ്ത്തപ്പെട്ടവൻ.'
);

-- =============================================================================
-- STRENGTH (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  'Philippians 4:13','Philippians',4,13,NULL,'strength',ARRAY['popular'],1,
  'I can do all this through him who gives me strength.',
  'फिलिप्पियों 4:13','जो मुझे सामर्थ्य देता है उसके द्वारा मैं सब कुछ कर सकता हूँ।',
  'ഫിലിപ്പ്യർ 4:13','എനിക്കു ശക്തി നൽകുന്നവൻ മുഖേന ഞാൻ സകലത്തിനും മതിയാകുന്നു.'
);

SELECT public._seed_suggested_verse(
  'Isaiah 40:31','Isaiah',40,31,NULL,'strength',ARRAY['popular','hope'],2,
  'But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.',
  'यशायाह 40:31','परन्तु जो यहोवा की बाट जोहते हैं, वे नई शक्ति पाते जाएँगे; वे उकाब की नाईं उड़ेंगे, वे दौड़ेंगे और थकेंगे नहीं, चलेंगे और श्रांत न होंगे।',
  'യെശയ്യാ 40:31','എന്നാൽ യഹോവയിൽ പ്രത്യാശ വക്കുന്നവർ ശക്തി പുതുതായ് വരും; കഴുകിനെ പ്പോലെ ചിറകടിക്കും; ഓടിയാലും ക്ഷീണിക്കുകയില്ല, നടന്നാലും തളരുകയില്ല.'
);

SELECT public._seed_suggested_verse(
  'Psalm 46:1','Psalms',46,1,NULL,'strength',ARRAY['refuge'],3,
  'God is our refuge and strength, an ever-present help in trouble.',
  'भजन संहिता 46:1','परमेश्वर हमारा शरणस्थान और बल है, संकट में अति सहज मिलने वाला सहायक।',
  'സങ്കീർത്തനങ്ങൾ 46:1','ദൈവം നമ്മുടെ സങ്കേതവും ബലവും, കഷ്ടകാലത്തു അതി സന്നദ്ധനായ സഹായകൻ.'
);

SELECT public._seed_suggested_verse(
  '2 Corinthians 12:9','2 Corinthians',12,9,NULL,'strength',ARRAY['grace','weakness'],4,
  'But he said to me, ''My grace is sufficient for you, for my power is made perfect in weakness.''',
  '2 कुरिन्थियों 12:9','परन्तु उसने मुझसे कहा कि मेरा अनुग्रह तेरे लिये बहुत है, क्योंकि मेरी सामर्थ्य निर्बलता में सिद्ध होती है।',
  '2 കൊരിന്ത്യർ 12:9','അവൻ എന്നോടു അരുളിച്ചെയ്തു: എന്റെ കൃപ നിനക്കു മതി; എന്റെ ശക്തി ബലഹീനതയിൽ തികഞ്ഞുവരുന്നു.'
);

SELECT public._seed_suggested_verse(
  'Nehemiah 8:10','Nehemiah',8,10,NULL,'strength',ARRAY['joy'],5,
  'Do not grieve, for the joy of the Lord is your strength.',
  'नहेम्याह 8:10','यहोवा का आनन्द तुम्हारा बल है।',
  'നെഹെമ്യാ 8:10','യഹോവയ്ക്കുള്ള സന്തോഷം നിങ്ങളുടെ ബലം ആകുന്നു.'
);

-- =============================================================================
-- WISDOM (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  'Proverbs 3:5','Proverbs',3,5,NULL,'wisdom',ARRAY['popular','trust'],1,
  'Trust in the Lord with all your heart and lean not on your own understanding.',
  'नीतिवचन 3:5','अपने सम्पूर्ण मन से यहोवा पर भरोसा रख, और अपनी समझ का सहारा न ले।',
  'സദൃശ്യവാക്യങ്ങൾ 3:5','നിന്റെ പൂർണ്ണ ഹൃദയത്തോടെ യഹോവയിൽ ആശ്രയിക്ക; നിന്റെ സ്വന്ത വിവേകത്തിൽ ഊന്നരുതു.'
);

SELECT public._seed_suggested_verse(
  'James 1:5','James',1,5,NULL,'wisdom',ARRAY['prayer'],2,
  'If any of you lacks wisdom, you should ask God, who gives generously to all without finding fault, and it will be given to you.',
  'याकूब 1:5','पर यदि तुम में से किसी को बुद्धि की घटी हो, तो परमेश्वर से माँगे, जो बिना उलाहना दिए सब को उदारता से देता है; और उसे दी जाएगी।',
  'യാക്കോബ് 1:5','നിങ്ങളിൽ ആർക്കെങ്കിലും ജ്ഞാനം കുറവുള്ളുവോ, അവൻ ദൈവത്തോടു ചോദിക്കട്ടെ; ദൈവം ആർക്കും കുറ്റം ചുമത്താതെ ഔദാര്യത്തോടെ കൊടുക്കും; അവൻ ലഭിക്കും.'
);

SELECT public._seed_suggested_verse(
  'Proverbs 9:10','Proverbs',9,10,NULL,'wisdom',ARRAY['fear'],3,
  'The fear of the Lord is the beginning of wisdom, and knowledge of the Holy One is understanding.',
  'नीतिवचन 9:10','यहोवा का भय मानना बुद्धि का मूल है, और पवित्र परमेश्वर को जानना ही समझ है।',
  'സദൃശ്യവാക്യങ്ങൾ 9:10','യഹോവഭക്തി ജ്ഞാനത്തിന്റെ ആരംഭം; പരിശുദ്ധനെ അറിയുന്നതു ബുദ്ധി ആകുന്നു.'
);

SELECT public._seed_suggested_verse(
  'Psalm 119:105','Psalms',119,105,NULL,'wisdom',ARRAY['scripture','light'],4,
  'Your word is a lamp for my feet, a light on my path.',
  'भजन संहिता 119:105','तेरा वचन मेरे पाँव के लिये दीपक, और मेरे मार्ग के लिये उजियाला है।',
  'സങ്കീർത്തനങ്ങൾ 119:105','നിന്റെ വചനം എന്റെ കാലിനു ദീപവും, എന്റെ പാതെക്കു പ്രകാശവും ആകുന്നു.'
);

SELECT public._seed_suggested_verse(
  'Colossians 2:3','Colossians',2,3,NULL,'wisdom',ARRAY['christ'],5,
  'In him are hidden all the treasures of wisdom and knowledge.',
  'कुलुस्सियों 2:3','जिसमें बुद्धि और ज्ञान के सारे खजाने छिपे हुए हैं।',
  'കൊലൊസ്സ്യർ 2:3','അവനിൽ ജ്ഞാനത്തിന്റെയും പരിജ്ഞാനത്തിന്റെയും നിക്ഷേപങ്ങൾ ഒക്കെയും ഗൂഢമായിരിക്കുന്നു.'
);

-- =============================================================================
-- PROMISE (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  'Jeremiah 29:11','Jeremiah',29,11,NULL,'promise',ARRAY['popular','hope','future'],1,
  'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.',
  'यिर्मयाह 29:11','यहोवा की यह वाणी है, कि जो कल्पनाएँ मैं तुम्हारे विषय करता हूँ उन्हें मैं जानता हूँ, वे हानि की नहीं, वरन् कुशल ही की हैं, और अपेक्षित भविष्य देने की हैं।',
  'യിരെമ്യാ 29:11','നിങ്ങൾക്കു ഭാവിയും പ്രത്യാശയും നൽകുവാൻ നിങ്ങൾക്കു ദോഷമല്ല, ശുഭമത്രേ ഞാൻ കരുതുന്നതു. ഇതു യഹോവയുടെ അരുളപ്പാടു.'
);

SELECT public._seed_suggested_verse(
  'Romans 8:28','Romans',8,28,NULL,'promise',ARRAY['popular','purpose'],2,
  'And we know that in all things God works for the good of those who love him, who have been called according to his purpose.',
  'रोमियों 8:28','और हम जानते हैं कि जो लोग परमेश्वर से प्रेम रखते हैं, उनके लिये सब बातें मिलकर भलाई ही को उत्पन्न करती हैं।',
  'റോമർ 8:28','ദൈവത്തെ സ്നേഹിക്കുന്നവർക്കു, അതായതു തന്റെ നിർണ്ണയപ്രകാരം വിളിക്കപ്പെട്ടവർക്കു, സകലവും നന്മെക്കായി കൂടി വ്യാപരിക്കുന്നു എന്നു നാം അറിയുന്നു.'
);

SELECT public._seed_suggested_verse(
  'Psalm 37:4','Psalms',37,4,NULL,'promise',ARRAY['delight'],3,
  'Take delight in the Lord, and he will give you the desires of your heart.',
  'भजन संहिता 37:4','यहोवा में आनन्दित रह, और वह तेरे मन की इच्छाएँ पूरी करेगा।',
  'സങ്കീർത്തനങ്ങൾ 37:4','യഹോവയിൽ ആനന്ദിക്ക; അവൻ നിന്റെ ഹൃദയത്തിന്റെ ആഗ്രഹങ്ങളെ നിനക്കു തരും.'
);

SELECT public._seed_suggested_verse(
  'Joshua 1:9','Joshua',1,9,NULL,'promise',ARRAY['courage','fear'],4,
  'Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.',
  'यहोशू 1:9','क्या मैंने तुझे आज्ञा नहीं दी? हियाव बाँध और दृढ़ हो; मत डर और तेरा मन कच्चा न हो; क्योंकि जहाँ कहीं तू जाए, तेरा परमेश्वर यहोवा तेरे साथ है।',
  'യോശുവ 1:9','ഞാൻ നിന്നോടു ആജ്ഞാപിച്ചിട്ടില്ലയോ? ശക്തിപ്പെടുക, ധൈര്യമുള്ളവനാക; ഭ്രമിക്കരുതു, ഭ്രമിച്ചു നോക്കരുതു; നീ പോകുന്ന ഇടത്തൊക്കെ നിന്റെ ദൈവമായ യഹോവ നിന്നോടുകൂടെ ഉണ്ടു.'
);

SELECT public._seed_suggested_verse(
  'Hebrews 13:5','Hebrews',13,5,NULL,'promise',ARRAY['presence'],5,
  'God has said, ''Never will I leave you; never will I forsake you.''',
  'इब्रानियों 13:5','मैं तुझे कभी न छोड़ूँगा, और न कभी तुझे त्यागूँगा।',
  'എബ്രായർ 13:5','ഞാൻ നിന്നെ ഒരുനാളും കൈവിടുകയില്ല, ഉപേക്ഷിക്കയും ഇല്ല.'
);

-- =============================================================================
-- GUIDANCE (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  'Proverbs 3:6','Proverbs',3,6,NULL,'guidance',ARRAY['popular','paths'],1,
  'In all your ways submit to him, and he will make your paths straight.',
  'नीतिवचन 3:6','अपने सारे मार्गों में उसको स्वीकार कर, तो वह तेरे मार्गों को सीधा करेगा।',
  'സദൃശ്യവാക്യങ്ങൾ 3:6','നിന്റെ എല്ലാ വഴികളിലും അവനെ നോക്കുക; അവൻ നിന്റെ പാതകളെ നേരെയാക്കും.'
);

SELECT public._seed_suggested_verse(
  'John 16:13','John',16,13,NULL,'guidance',ARRAY['holy spirit','truth'],2,
  'But when he, the Spirit of truth, comes, he will guide you into all the truth.',
  'यूहन्ना 16:13','परन्तु जब वह अर्थात् सत्य का आत्मा आएगा, तो तुम्हें सब सत्य का मार्ग बताएगा।',
  'യോഹന്നാൻ 16:13','സത്യത്തിന്റെ ആത്മാവു വരുമ്പോൾ, അവൻ സകല സത്യത്തിലേക്കും നിങ്ങൾക്കു വഴി കാണിക്കും.'
);

SELECT public._seed_suggested_verse(
  'Psalm 32:8','Psalms',32,8,NULL,'guidance',ARRAY['counsel','instruction'],3,
  'I will instruct you and teach you in the way you should go; I will counsel you with my loving eye on you.',
  'भजन संहिता 32:8','मैं तुझे बुद्धि देता और जिस मार्ग में तुझे चलना होगा उसमें तेरी अगुवाई करूँगा; मैं तुझ पर कृपादृष्टि रखकर तुझे सम्मति दूँगा।',
  'സങ്കീർത്തനങ്ങൾ 32:8','ഞാൻ നിന്നെ ഉപദേശിക്കും, ഞാൻ നിനക്കു ചൊല്ലിക്കൊടുക്കും; നീ നടക്കേണ്ടുന്ന വഴിയിൽ ഞാൻ നിന്നെ നോക്കിക്കൊണ്ടു ആലോചന നൽകും.'
);

SELECT public._seed_suggested_verse(
  'Isaiah 30:21','Isaiah',30,21,NULL,'guidance',ARRAY['voice','direction'],4,
  'Whether you turn to the right or to the left, your ears will hear a voice behind you, saying, ''This is the way; walk in it.''',
  'यशायाह 30:21','और जब कभी तुम दाहिनी वा बाईं ओर मुड़ो, तब तुम्हारे पीछे से यह वचन सुनाई देगा कि मार्ग यही है, इसी पर चलो।',
  'യെശയ്യാ 30:21','നീ വലത്തോട്ടോ ഇടത്തോട്ടോ തിരിയുമ്പോൾ, ഇതാ, വഴി; ഇതിൽ നടക്ക എന്നു നിന്റെ ചെവിക്ക് ഒരു വചനം ഉണ്ടാകും.'
);

SELECT public._seed_suggested_verse(
  'Psalm 25:4','Psalms',25,4,NULL,'guidance',ARRAY['paths','teach'],5,
  'Show me your ways, Lord, teach me your paths.',
  'भजन संहिता 25:4','हे यहोवा, अपने मार्ग मुझे दिखा, अपने रास्ते मुझे सिखा।',
  'സങ്കീർത്തനങ്ങൾ 25:4','യഹോവേ, നിന്റെ വഴികൾ എനിക്കു കാണിക്ക; നിന്റെ പാതകൾ എന്നെ ഉപദേശിക്ക.'
);

-- =============================================================================
-- FAITH (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  'Hebrews 11:1','Hebrews',11,1,NULL,'faith',ARRAY['popular','hope'],1,
  'Now faith is confidence in what we hope for and assurance about what we do not see.',
  'इब्रानियों 11:1','अब विश्वास आशा की हुई वस्तुओं का निश्चय, और अनदेखी वस्तुओं का प्रमाण है।',
  'എബ്രായർ 11:1','വിശ്വാസം ആശിക്കുന്നവയുടെ ഉറപ്പും കാണാത്ത കാര്യങ്ങളുടെ നിശ്ചയവും ആകുന്നു.'
);

SELECT public._seed_suggested_verse(
  'Matthew 17:20','Matthew',17,20,NULL,'faith',ARRAY['mustard seed','prayer'],2,
  'Truly I tell you, if you have faith as small as a mustard seed, you can say to this mountain, ''Move from here to there,'' and it will move. Nothing will be impossible for you.',
  'मत्ती 17:20','यदि तुम में राई के दाने के बराबर भी विश्वास हो, तो इस पहाड़ से कह सकते हो कि यहाँ से वहाँ चला जा, तो वह चला जाएगा; और कुछ भी तुम्हारे लिये अनहोना न होगा।',
  'മത്തായി 17:20','നിങ്ങൾക്കു കടുകുമണിയോളം വിശ്വാസം ഉണ്ടെങ്കിൽ, ഈ മലയോടു ഇവിടം വിട്ടു ആവിടേക്കു നീങ്ങിക്കൊൾക എന്നു പറഞ്ഞാൽ, അതു നീങ്ങും; ഒന്നും നിങ്ങൾക്കു അസാദ്ധ്യമാകില്ല.'
);

SELECT public._seed_suggested_verse(
  'Romans 10:17','Romans',10,17,NULL,'faith',ARRAY['scripture','hearing'],3,
  'Consequently, faith comes from hearing the message, and the message is heard through the word about Christ.',
  'रोमियों 10:17','सो विश्वास सुनने से, और सुनना मसीह के वचन से होता है।',
  'റോമർ 10:17','ആകയാൽ വിശ്വാസം കേൾക്കുന്നതിൽ നിന്നും കേൾക്കുന്നതു ക്രിസ്തുവിന്റെ വചനത്തിൽ നിന്നും ഉളവാകുന്നു.'
);

SELECT public._seed_suggested_verse(
  '2 Corinthians 5:7','2 Corinthians',5,7,NULL,'faith',ARRAY['walk'],4,
  'For we live by faith, not by sight.',
  '2 कुरिन्थियों 5:7','क्योंकि हम दृष्टि से नहीं, परन्तु विश्वास से चलते हैं।',
  '2 കൊരിന്ത്യർ 5:7','കാണ്മാനല്ല, വിശ്വാസത്താൽ നടക്കുന്നു.'
);

SELECT public._seed_suggested_verse(
  '1 John 5:14','1 John',5,14,NULL,'faith',ARRAY['prayer','confidence','will-of-god'],5,
  'This is the confidence we have in approaching God: that if we ask anything according to his will, he hears us.',
  '1 यूहन्ना 5:14','और जो हम उसके सामने हियाव रखते हैं, वह यह है, कि यदि हम उसकी इच्छा के अनुसार कुछ माँगते हैं, तो वह हमारी सुनता है।',
  '1 യോഹന്നാൻ 5:14','അവന്റെ ഇഷ്ടപ്രകാരം നാം ഇരക്കുന്നതൊക്കെ അവൻ കേൾക്കുന്നു എന്നതത്രേ അവനോടു നമുക്കുള്ള പ്രത്യാശ.'
);

-- =============================================================================
-- LOVE (5 verses)
-- =============================================================================

SELECT public._seed_suggested_verse(
  '1 Corinthians 13:4','1 Corinthians',13,4,NULL,'love',ARRAY['popular','patience','kindness'],1,
  'Love is patient, love is kind. It does not envy, it does not boast, it is not proud.',
  '1 कुरिन्थियों 13:4','प्रेम धीरजवन्त है, और कृपालु है; प्रेम डाह नहीं करता; प्रेम अपनी बड़ाई नहीं करता, फूलता नहीं।',
  '1 കൊരിന്ത്യർ 13:4','സ്നേഹം ദീർഘക്ഷമയുള്ളതും ദയയുള്ളതും ആകുന്നു; സ്നേഹം അസൂയപ്പെടുന്നില്ല; സ്നേഹം നിഗളിക്കുന്നില്ല; ദർപ്പിക്കുന്നതുമില്ല.'
);

SELECT public._seed_suggested_verse(
  'Romans 5:8','Romans',5,8,NULL,'love',ARRAY['popular','gospel','sacrifice'],2,
  'But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.',
  'रोमियों 5:8','परन्तु परमेश्वर हम पर अपने प्रेम की भलाई इस रीति से प्रगट करता है, कि जब हम पापी ही थे तभी मसीह हमारे लिये मरा।',
  'റോമർ 5:8','ദൈവം നമ്മോടുള്ള സ്വന്ത സ്നേഹത്തെ, ഇനിയും നാം പാപികൾ ആയിരിക്കുമ്പോൾ, ക്രിസ്തു നമുക്കുവേണ്ടി മരിക്കയാൽ, തെളിയിക്കുന്നു.'
);

SELECT public._seed_suggested_verse(
  '1 John 4:8','1 John',4,8,NULL,'love',ARRAY['God is love'],3,
  'Whoever does not love does not know God, because God is love.',
  '1 यूहन्ना 4:8','जो प्रेम नहीं रखता, वह परमेश्वर को नहीं जानता, क्योंकि परमेश्वर प्रेम है।',
  '1 യോഹന്നാൻ 4:8','സ്നേഹിക്കാത്തവൻ ദൈവത്തെ അറിയുന്നില്ല; ദൈവം സ്നേഹം ആകുന്നു.'
);

SELECT public._seed_suggested_verse(
  '1 John 4:19','1 John',4,19,NULL,'love',ARRAY['response'],4,
  'We love because he first loved us.',
  '1 यूहन्ना 4:19','हम इसलिये प्रेम करते हैं, क्योंकि पहले उसने हम से प्रेम किया।',
  '1 യോഹന്നാൻ 4:19','അവൻ ആദ്യം നമ്മെ സ്നേഹിക്കയാൽ നാം സ്നേഹിക്കുന്നു.'
);

SELECT public._seed_suggested_verse(
  'John 15:13','John',15,13,NULL,'love',ARRAY['sacrifice','friendship'],5,
  'Greater love has no one than this, that someone lay down his life for his friends.',
  'यूहन्ना 15:13','इससे बड़ा प्रेम किसी का नहीं, कि कोई अपने मित्रों के लिये अपना प्राण दे।',
  'യോഹന്നാൻ 15:13','ഒരുവൻ തന്റെ സ്നേഹിതർക്കു വേണ്ടി ജീവനെ കൊടുക്കുന്നതിനേക്കാൾ ഏറ്റം വലിയ സ്നേഹം ഒരുത്തർക്കും ഇല്ല.'
);

-- ---------------------------------------------------------------------------
-- Clean up helper function
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public._seed_suggested_verse(
  TEXT,TEXT,INT,INT,INT,TEXT,TEXT[],INT,TEXT,TEXT,TEXT,TEXT,TEXT
);
