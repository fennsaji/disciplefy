-- Migration: 20260904000000_add_learning_to_pray_translations
-- ============================================================================
-- The "Learning to Pray" topic (111e8400-e29b-41d4-a716-4466554400f2), added
-- in 20260721000006, was inserted into recommended_topics with only an
-- English title/description — no matching rows were added to
-- recommended_topics_translations for hi/ml.
--
-- rs-backend's blog_generator falls back to the English title whenever a
-- translation row is missing (LearningPathTopic.hi_title.unwrap_or(&title)),
-- so both the Hindi and Malayalam generated study guides and blog posts
-- carry an English title ("Learning to Pray") even though their body content
-- was correctly generated in-language. Reported via the marketing site's
-- /hi/blog learning-path listing on 4 Sept 2026.
--
-- This is a content gap, not a code bug: the fallback itself is reasonable
-- (show something rather than fail). Fixes: adds the missing translation
-- rows, and corrects the title on the two already-published blog posts
-- (their excerpt/content were already in-language and are left untouched).
--
-- Hindi/Malayalam text below is machine-translated by Claude, matching the
-- terminology the site's own live Hindi/Malayalam posts for this topic
-- already used ("प्रार्थना सीखना", "പ്രാർത്ഥിക്കാൻ പഠിക്കുക") and the
-- "Spiritual Disciplines" category convention used elsewhere in this file's
-- sibling migration (आत्मिक अनुशासन / ആത്മീയ അനുശാസനം). Worth a native
-- speaker's check before treating it as final.
--
-- IDEMPOTENT: safe to re-run (ON CONFLICT DO NOTHING keyed on the table's
-- existing UNIQUE(topic_id, language_code)).
-- ============================================================================

BEGIN;

INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  (
    '111e8400-e29b-41d4-a716-4466554400f2',
    'hi',
    'प्रार्थना सीखना',
    'यीशु के चेलों ने उनसे प्रचार करना या चंगा करना सिखाने के लिए नहीं, बल्कि प्रार्थना करना सिखाने के लिए कहा (लूका 11:1)। यह अध्ययन उस नमूने की जांच करता है जो उन्होंने दिया — प्रभु की प्रार्थना (मत्ती 6:9-13) — और इसे पंक्ति दर पंक्ति समझाता है: निवेदन से पहले आराधना, हमारी आवश्यकताओं से पहले परमेश्वर का राज्य, दैनिक निर्भरता, जैसे हमें क्षमा मिली वैसे ही क्षमा देना, और प्रलोभन से बचाव। आप सीखेंगे कि प्रार्थना प्रदर्शन नहीं है, कि परमेश्वर लंबाई या वाक्पटुता से प्रभावित नहीं होता (मत्ती 6:7-8), और जब आपके पास शब्द ही न हों तब आत्मा आपके लिए विनती करता है (रोमियों 8:26-27)। दैनिक आदत बनाने के लिए व्यावहारिक सहायता भी शामिल है, ताकि प्रार्थना एक कर्तव्य नहीं बल्कि पिता के साथ बातचीत बन जाए।',
    'आत्मिक अनुशासन'
  ),
  (
    '111e8400-e29b-41d4-a716-4466554400f2',
    'ml',
    'പ്രാർത്ഥിക്കാൻ പഠിക്കുക',
    'യേശുവിന്റെ ശിഷ്യന്മാർ അവനോട് പ്രസംഗിക്കാനോ സൗഖ്യമാക്കാനോ അല്ല, പ്രാർത്ഥിക്കാൻ പഠിപ്പിക്കാൻ ആവശ്യപ്പെട്ടു (ലൂക്കോസ് 11:1). ഈ പഠനം അവൻ നൽകിയ മാതൃക — കർത്താവിന്റെ പ്രാർത്ഥന (മത്തായി 6:9-13) — വരി വരിയായി പരിശോധിക്കുന്നു: അപേക്ഷയ്ക്ക് മുമ്പ് ആരാധന, നമ്മുടെ ആവശ്യങ്ങൾക്ക് മുമ്പ് ദൈവരാജ്യം, ദൈനംദിന ആശ്രയത്വം, നമുക്ക് ലഭിച്ചതുപോലെ ക്ഷമ നൽകൽ, പ്രലോഭനത്തിൽ നിന്നുള്ള രക്ഷ. പ്രാർത്ഥന ഒരു പ്രകടനമല്ലെന്നും, നീളമോ വാക്ചാതുര്യമോ കൊണ്ട് ദൈവത്തെ സ്വാധീനിക്കാനാവില്ലെന്നും (മത്തായി 6:7-8), വാക്കുകളില്ലാത്തപ്പോൾ ആത്മാവ് നമുക്കുവേണ്ടി പക്ഷവാദം ചെയ്യുന്നു എന്നും (റോമർ 8:26-27) നിങ്ങൾ പഠിക്കും. ദിനംപ്രതി ശീലം വളർത്തുന്നതിനുള്ള പ്രായോഗിക സഹായവും ഇതിലുൾപ്പെടുന്നു, അങ്ങനെ പ്രാർത്ഥന ഒരു കടമയല്ല, പിതാവുമായുള്ള സംഭാഷണമായി മാറുന്നു.',
    'ആത്മീയ അനുശാസനം'
  )
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Fix the title on the two posts already published under the English
-- fallback. Their excerpt and content were generated correctly in-language
-- (the LLM was given the right `locale`, independent of the title bug) and
-- are left untouched.
UPDATE blog_posts SET title = 'प्रार्थना सीखना', updated_at = now()
  WHERE slug = 'learning-to-pray-hi' AND title = 'Learning to Pray';

UPDATE blog_posts SET title = 'പ്രാർത്ഥിക്കാൻ പഠിക്കുക', updated_at = now()
  WHERE slug = 'learning-to-pray-ml' AND title = 'Learning to Pray';

COMMIT;
