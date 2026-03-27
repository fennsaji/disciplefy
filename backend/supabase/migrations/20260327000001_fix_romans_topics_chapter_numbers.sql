-- =====================================================
-- Migration: Fix Romans Topics - Chapter Numbers & Language Consistency
-- =====================================================
-- Root cause: ab300000...001-016 were first created as Evangelism topics
-- in 20260223000001_new_learning_paths.sql. The Romans v2 migration
-- (20260313000001) used ON CONFLICT DO NOTHING so base English content
-- was never updated. Hindi/ML translations were added correctly in
-- 20260316000003_learning_path_topic_translations.sql, causing a mismatch
-- where English shows Evangelism content and Hindi/ML shows Romans content.
--
-- Fix:
--   1. UPDATE base recommended_topics (English) to Romans content + chapter numbers
--   2. UPDATE Hindi translations to add chapter number prefix
--   3. UPDATE Malayalam translations to add chapter number prefix
--   4. Create new IDs for the 3 Evangelism topics that shared ab300000 IDs
--   5. Re-link Evangelism learning path (018) to new Evangelism topic IDs
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: Fix base English topics (recommended_topics)
-- =====================================================

UPDATE recommended_topics SET
  title = 'Romans 1: The Power of the Gospel and Universal Human Guilt',
  description = 'Paul opens his magnum opus by declaring the gospel''s power for salvation to everyone who believes. He then demonstrates why it is needed: from Adam onward, all humanity has suppressed the knowledge of God that creation declares, exchanged the glory of God for idols, and stands under divine wrath. The diagnosis is universal — Gentile and Jew alike are without excuse before a holy God.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'gospel', 'sin', 'judgment']
WHERE id = 'ab300000-e29b-41d4-a716-446655440001';

UPDATE recommended_topics SET
  title = 'Romans 2: God''s Impartial Judgment',
  description = 'Paul confronts the self-righteous moralizer who agrees with God''s condemnation of others while committing the same things. God''s judgment is based on truth and impartial — whether Jew or Gentile, the standard is the same. Those who have the Law will be judged by it; those without it will be judged by the law written on their hearts. No one can appeal to religious privilege before God.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'judgment', 'impartiality', 'law']
WHERE id = 'ab300000-e29b-41d4-a716-446655440002';

UPDATE recommended_topics SET
  title = 'Romans 3: Righteousness Through Faith',
  description = 'The prosecutorial argument of Romans 1-2 reaches its verdict in chapter 3: all have sinned and fall short of the glory of God — not one is righteous. But the same passage announces the stunning solution: justification freely by God''s grace, through the redemption in Christ Jesus, received through faith. This is the heart of the gospel: sinners are declared righteous not by works but by faith alone in Christ alone.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'justification', 'faith', 'grace']
WHERE id = 'ab300000-e29b-41d4-a716-446655440003';

UPDATE recommended_topics SET
  title = 'Romans 4: Abraham, Father of Faith',
  description = 'Paul turns to Abraham to demonstrate that justification by faith is not a Pauline innovation but the pattern of the Old Testament itself. Abraham was declared righteous before circumcision, before the Law existed. He believed God, and it was counted to him as righteousness. The children of Abraham are those who share his faith, not merely his bloodline.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'abraham', 'faith', 'justification']
WHERE id = 'ab300000-e29b-41d4-a716-446655440004';

UPDATE recommended_topics SET
  title = 'Romans 5: Peace with God Through Christ',
  description = 'Because we are justified by faith, we have peace with God through our Lord Jesus Christ. Romans 5 expands the blessings of justification — hope, suffering producing endurance, God''s love poured into our hearts by the Spirit. Paul introduces the two-Adams framework: as Adam''s one act of disobedience brought condemnation, so Christ''s one act of righteousness brings justification of life to all who are in him.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'justification', 'peace', 'adam and christ']
WHERE id = 'ab300000-e29b-41d4-a716-446655440005';

UPDATE recommended_topics SET
  title = 'Romans 6: Dead to Sin, Alive in Christ',
  description = 'Shall we go on sinning so that grace may increase? By no means! Paul explains that baptism into Christ is baptism into his death and resurrection — we have died to sin and are alive to God. The believer is no longer a slave to sin but a slave to righteousness. Union with Christ means the old self is crucified; the power of sin is broken.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'sanctification', 'union with christ', 'sin']
WHERE id = 'ab300000-e29b-41d4-a716-446655440006';

UPDATE recommended_topics SET
  title = 'Romans 7: The Struggle with Sin and the Law',
  description = '"I do not do what I want, but I do the very thing I hate." The strong Reformed tradition, following Augustine, Luther, and Calvin, understands this as describing Paul''s ongoing experience as a regenerate believer. The believer genuinely delights in God''s law in the inner person, while experiencing the ongoing pull of indwelling sin. This internal conflict is the mark of genuine regeneration, not its absence.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'sin', 'law', 'struggle']
WHERE id = 'ab300000-e29b-41d4-a716-446655440007';

UPDATE recommended_topics SET
  title = 'Romans 8: Life in the Spirit',
  description = 'There is therefore now no condemnation for those who are in Christ Jesus. Romans 8 is the greatest single chapter on the Christian life — life in the Spirit, adoption as children of God, the Spirit''s intercession in our weakness, and the unshakeable promise that all things work together for good for those who love God and are called according to his purpose. Nothing in all creation can separate us from the love of God in Christ Jesus.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'holy spirit', 'assurance', 'no condemnation']
WHERE id = 'ab300000-e29b-41d4-a716-446655440008';

UPDATE recommended_topics SET
  title = 'Romans 9: God''s Sovereign Election',
  description = 'Romans 9 contains the New Testament''s clearest statement of unconditional election. Before Jacob and Esau were born or had done anything good or evil, God chose Jacob — not on the basis of works but of his call. Paul quotes God: "I will have mercy on whom I have mercy," and concludes: "It depends not on human will or exertion, but on God, who has mercy." This sovereign freedom in grace is not injustice but the very foundation of all hope.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'election', 'sovereignty', 'grace']
WHERE id = 'ab300000-e29b-41d4-a716-446655440009';

UPDATE recommended_topics SET
  title = 'Romans 10: Salvation for All Who Call',
  description = 'If you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved. Romans 10 moves from divine sovereignty to human responsibility without dissolving the tension. Everyone who calls on the name of the Lord will be saved — Jew and Greek alike. But how will they call on one they have not heard? This chapter carries the church''s missionary mandate.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'salvation', 'faith', 'mission']
WHERE id = 'ab300000-e29b-41d4-a716-446655440010';

UPDATE recommended_topics SET
  title = 'Romans 11: The Mystery of Israel''s Future',
  description = 'Has God abandoned his promises to Israel? By no means. Paul reveals a mystery: a partial hardening has come upon Israel until the fullness of the Gentiles comes in, and then all Israel will be saved. This chapter holds together divine faithfulness to covenant promises and the present Gentile mission, concluding with a doxology: "Oh, the depth of the riches and wisdom and knowledge of God!"',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'israel', 'eschatology', 'covenant']
WHERE id = 'ab300000-e29b-41d4-a716-446655440011';

UPDATE recommended_topics SET
  title = 'Romans 12: Living Sacrifices and Kingdom Ethics',
  description = '"I appeal to you therefore, brothers, by the mercies of God, to present your bodies as a living sacrifice." The therefore connects the ethics of Romans 12 to the gospel of Romans 1-11. Transformed living is the reasonable response to God''s grace. Paul unfolds what this looks like: humble service, love without hypocrisy, blessing enemies, overcoming evil with good.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'ethics', 'spiritual gifts', 'love']
WHERE id = 'ab300000-e29b-41d4-a716-446655440012';

UPDATE recommended_topics SET
  title = 'Romans 13: Governing Authorities and the Debt of Love',
  description = 'Paul addresses submission to governing authorities as God''s servants for justice, and the ongoing debt of love — the only debt that grows larger the more it is paid. The governing authorities passage does not mandate blind obedience but recognizes government''s God-given role in restraining evil. The love passage reframes the entire Law: love your neighbor as yourself and you have fulfilled it.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'government', 'love', 'neighbors']
WHERE id = 'ab300000-e29b-41d4-a716-446655440013';

UPDATE recommended_topics SET
  title = 'Romans 14: Receiving One Another',
  description = 'The strong in faith should not despise those with weaker consciences; the weak should not judge the strong. Paul addresses tensions over food and holy days in the Roman church, calling each group to stop judging and to act in love so as not to cause a brother to stumble. The goal is mutual acceptance after the pattern of Christ, who received both the strong and the weak.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'conscience', 'unity', 'love']
WHERE id = 'ab300000-e29b-41d4-a716-446655440014';

UPDATE recommended_topics SET
  title = 'Romans 15: United in Christ''s Mission',
  description = 'Paul grounds Christian unity in the example of Christ, who did not please himself. He then unveils his apostolic strategy — to proclaim the gospel where Christ has not yet been named — and his desire to extend this mission to Spain via Rome. The gospel is inherently missional; salvation draws every believer into God''s worldwide redemptive project.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'unity', 'mission', 'gentiles']
WHERE id = 'ab300000-e29b-41d4-a716-446655440015';

UPDATE recommended_topics SET
  title = 'Romans 16: Greetings and the Community of Faith',
  description = 'Paul''s closing chapter is a portrait of the early Christian community — diverse, multiethnic, including men and women in ministry service, marked by warmth and mutual care. It also contains his final warning: watch out for those who cause divisions contrary to the doctrine you have been taught (16:17-20). The unity of the church is maintained not by silence about doctrine but by shared faithfulness to the apostolic gospel.',
  category = 'Foundations of Faith',
  tags = ARRAY['romans', 'community', 'doctrinal faithfulness', 'warning']
WHERE id = 'ab300000-e29b-41d4-a716-446655440016';


-- =====================================================
-- PART 2: Update Hindi translations — add chapter numbers
-- =====================================================

UPDATE recommended_topics_translations
SET title = 'रोमियों 1: सुसमाचार की शक्ति और मानव का पाप'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440001' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 2: परमेश्वर का निष्पक्ष न्याय'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440002' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 3: विश्वास द्वारा धार्मिकता'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440003' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 4: अब्राहम — विश्वास का पिता'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440004' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 5: मसीह के द्वारा परमेश्वर के साथ शांति'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440005' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 6: पाप के प्रति मरे, मसीह में जीवित'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440006' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 7: पाप और व्यवस्था से संघर्ष'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440007' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 8: आत्मा में जीवन'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440008' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 9: परमेश्वर का चुनाव'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440009' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 10: बुलाने वाले सभी के लिए उद्धार'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440010' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 11: इस्राएल के भविष्य का रहस्य'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440011' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 12: जीवित बलिदान — परमेश्वर की सेवा'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440012' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 13: अधिकारियों का आदर और प्रेम का ऋण'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440013' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 14: एक दूसरे को स्वीकार करना'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440014' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 15: मसीह के मिशन में एकजुट'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440015' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'रोमियों 16: अभिवादन और विश्वास का समुदाय'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440016' AND language_code = 'hi';


-- =====================================================
-- PART 3: Update Malayalam translations — add chapter numbers
-- =====================================================

UPDATE recommended_topics_translations
SET title = 'റോമർ 1: സുവിശേഷത്തിന്റെ ശക്തിയും മനുഷ്യന്റെ പാപവും'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440001' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 2: ദൈവത്തിന്റെ നീതിയുള്ള വിധി'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440002' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 3: വിശ്വാസത്തിലൂടെ നീതി'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440003' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 4: അബ്രഹാം — വിശ്വാസത്തിന്റെ പിതാവ്'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440004' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 5: ക്രിസ്തുവിലൂടെ ദൈവവുമായി സമാധാനം'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440005' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 6: പാപത്തോട് മരിച്ചവർ, ക്രിസ്തുവിൽ ജീവിക്കുന്നവർ'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440006' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 7: പാപവും ന്യായപ്രമാണവുമായുള്ള പോരാട്ടം'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440007' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 8: ആത്മാവിലുള്ള ജീവിതം'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440008' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 9: ദൈവത്തിന്റെ തിരഞ്ഞെടുപ്പ്'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440009' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 10: വിളിക്കുന്ന എല്ലാവർക്കും രക്ഷ'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440010' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 11: ഇസ്രായേലിന്റെ ഭാവിയുടെ രഹസ്യം'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440011' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 12: ജീവനുള്ള ബലി — ദൈവത്തിനുള്ള സേവനം'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440012' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 13: അധികാരികളോടുള്ള ബഹുമാനവും സ്നേഹത്തിന്റെ കടവും'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440013' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 14: പരസ്പരം സ്വീകരിക്കൽ'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440014' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 15: ക്രിസ്തുവിന്റെ ദൗത്യത്തിൽ ഒന്നിച്ച്'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440015' AND language_code = 'ml';

UPDATE recommended_topics_translations
SET title = 'റോമർ 16: അഭിവാദനങ്ങളും വിശ്വാസ സമൂഹവും'
WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440016' AND language_code = 'ml';


-- =====================================================
-- PART 4: Fix Evangelism path — create replacement topic IDs
-- =====================================================
-- The Evangelism path (018) uses ab300000...001-003 which now hold Romans
-- content. Create new IDs (ae300000) for the Evangelism topics.

INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ae300000-e29b-41d4-a716-446655440001', 'Overcoming Fear of Evangelism',
   'Most Christians want to share their faith but are paralyzed by fear — of rejection, of not knowing what to say, of damaging relationships. This study diagnoses where that fear comes from, applies gospel truth to it, and equips believers with the confidence that comes not from perfect words but from the Spirit''s power and God''s sovereign work in hearts.',
   'Mission & Evangelism', ARRAY['evangelism', 'fear', 'boldness', 'holy spirit'], 271, 50),

  ('ae300000-e29b-41d4-a716-446655440002', 'Answering Common Objections to Faith',
   'People raise real questions: "What about suffering?" "Isn''t Christianity exclusive?" "Can''t I be moral without God?" This study equips you to respond to the most common objections with gentleness and respect — not winning arguments but opening doors for the gospel. You don''t need all the answers; you need to point to the One who is the Answer.',
   'Mission & Evangelism', ARRAY['objections', 'apologetics', 'evangelism', 'questions'], 272, 50),

  ('ae300000-e29b-41d4-a716-446655440003', 'The Role of the Holy Spirit in Evangelism',
   'Evangelism is a partnership: we speak, God saves. Study how the Holy Spirit convicts, draws, and regenerates — why only God can open blind eyes — and how this truth frees us from the pressure of needing to "close the deal." Learn to pray with urgency, speak with boldness, and trust God with the results.',
   'Mission & Evangelism', ARRAY['holy spirit', 'evangelism', 'conviction', 'mission'], 273, 50)
ON CONFLICT (id) DO NOTHING;

-- Hindi translations for the new Evangelism topics
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('ae300000-e29b-41d4-a716-446655440001', 'hi',
   'सुसमाचार सुनाने के डर को पार करना',
   'ज्यादातर मसीही विश्वासी अपना विश्वास बांटना चाहते हैं, लेकिन अस्वीकृति और गलत बातें कहने के डर से रुक जाते हैं। यह अध्ययन उस डर के कारणों को समझने और पवित्र आत्मा की शक्ति से साहस पाने में मदद करता है।',
   'मिशन और सुसमाचार'),
  ('ae300000-e29b-41d4-a716-446655440002', 'hi',
   'विश्वास पर सामान्य आपत्तियों का जवाब',
   'लोग कई सवाल पूछते हैं: "दुख क्यों है?" "क्या मसीही धर्म बहुत संकीर्ण नहीं है?" यह अध्ययन आपको सामान्य सवालों का जवाब विनम्रता और सम्मान के साथ देने के लिए तैयार करता है।',
   'मिशन और सुसमाचार'),
  ('ae300000-e29b-41d4-a716-446655440003', 'hi',
   'प्रचार में पवित्र आत्मा की भूमिका',
   'प्रचार एक साझेदारी है: हम बोलते हैं, परमेश्वर बचाता है। पवित्र आत्मा कैसे लोगों को पाप का बोध कराता और खींचता है, यह समझें। यह सच्चाई हमें नतीजों के बोझ से मुक्त करती है।',
   'मिशन और सुसमाचार')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam translations for the new Evangelism topics
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('ae300000-e29b-41d4-a716-446655440001', 'ml',
   'സുവിശേഷ പ്രഘോഷണത്തിലുള്ള ഭയം മറികടക്കൽ',
   'ഭൂരിഭാഗം ക്രിസ്ത്യാനികളും തങ്ങളുടെ വിശ്വാസം പങ്കുവെക്കാൻ ആഗ്രഹിക്കുന്നു, പക്ഷേ നിരസ്കരണ ഭയം മൂലം നിൽക്കുന്നു. ഈ പഠനം ആ ഭയത്തിന്റെ കാരണം മനസ്സിലാക്കി പരിശുദ്ധാത്മ ശക്തിയിൽ ധൈര്യം നേടാൻ സഹായിക്കുന്നു.',
   'ദൗത്യവും സുവിശേഷ പ്രഘോഷണവും'),
  ('ae300000-e29b-41d4-a716-446655440002', 'ml',
   'വിശ്വാസത്തെ കുറിച്ചുള്ള പൊതു ആക്ഷേപങ്ങൾക്ക് ഉത്തരം',
   'ആളുകൾ പലതും ചോദിക്കുന്നു: "ദൈവം ദുഃഖം അനുവദിക്കുന്നതെന്ത്?" "ക്രിസ്തീയം ഇടുങ്ങിയതല്ലേ?" ഈ പഠനം സൗമ്യതയോടും ബഹുമാനത്തോടും കൂടെ ഉത്തരം നൽകാൻ തയ്യാറാക്കുന്നു.',
   'ദൗത്യവും സുവിശേഷ പ്രഘോഷണവും'),
  ('ae300000-e29b-41d4-a716-446655440003', 'ml',
   'സുവിശേഷ പ്രഘോഷണത്തിൽ പരിശുദ്ധാത്മാവിന്റെ പങ്ക്',
   'സുവിശേഷ പ്രഘോഷണം ഒരു പങ്കാളിത്തമാണ്: നാം സംസാരിക്കുന്നു, ദൈവം രക്ഷിക്കുന്നു. പരിശുദ്ധാത്മാവ് എങ്ങനെ ബോധ്യപ്പെടുത്തുകയും ആകർഷിക്കുകയും ചെയ്യുന്നു എന്ന് മനസ്സിലാക്കി ഫലത്തിനോടുള്ള ആകുലത വിടൻ പഠിക്കണം.',
   'ദൗത്യവും സുവിശേഷ പ്രഘോഷണവും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Update Evangelism learning path (018) to use new IDs
UPDATE learning_path_topics
SET topic_id = 'ae300000-e29b-41d4-a716-446655440001'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000018'
  AND topic_id = 'ab300000-e29b-41d4-a716-446655440001';

UPDATE learning_path_topics
SET topic_id = 'ae300000-e29b-41d4-a716-446655440002'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000018'
  AND topic_id = 'ab300000-e29b-41d4-a716-446655440002';

UPDATE learning_path_topics
SET topic_id = 'ae300000-e29b-41d4-a716-446655440003'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000018'
  AND topic_id = 'ab300000-e29b-41d4-a716-446655440003';


-- =====================================================
-- Verification
-- =====================================================

DO $$
DECLARE
  romans_en_title TEXT;
  romans_hi_title TEXT;
  romans_ml_title TEXT;
  evang_id UUID;
BEGIN
  -- Check Romans topic 1 English title has chapter number
  SELECT title INTO romans_en_title
  FROM recommended_topics
  WHERE id = 'ab300000-e29b-41d4-a716-446655440001';
  ASSERT romans_en_title LIKE 'Romans 1:%', 'Romans topic 1 English title missing chapter number: ' || romans_en_title;

  -- Check Romans topic 1 Hindi title has chapter number
  SELECT title INTO romans_hi_title
  FROM recommended_topics_translations
  WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440001' AND language_code = 'hi';
  ASSERT romans_hi_title LIKE 'रोमियों 1:%', 'Romans topic 1 Hindi title missing chapter number: ' || romans_hi_title;

  -- Check Romans topic 1 Malayalam title has chapter number
  SELECT title INTO romans_ml_title
  FROM recommended_topics_translations
  WHERE topic_id = 'ab300000-e29b-41d4-a716-446655440001' AND language_code = 'ml';
  ASSERT romans_ml_title LIKE 'റോമർ 1:%', 'Romans topic 1 Malayalam title missing chapter number: ' || romans_ml_title;

  -- Check new Evangelism topic exists
  SELECT id INTO evang_id
  FROM recommended_topics
  WHERE id = 'ae300000-e29b-41d4-a716-446655440001';
  ASSERT evang_id IS NOT NULL, 'New Evangelism topic ae300000...001 not found';

  RAISE NOTICE 'Romans topic fix verified: English, Hindi, Malayalam all have chapter numbers. Evangelism path fixed.';
END $$;

COMMIT;
