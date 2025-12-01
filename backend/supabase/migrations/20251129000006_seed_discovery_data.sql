-- =====================================================
-- Phase 4: Seed Discovery Data
-- =====================================================
-- Seeds:
-- 1. Seasonal translations (labels for seasons)
-- 2. Seasonal topic mappings (Christmas/Advent season)
-- 3. Life situations with translations
-- 4. Life situation topic mappings
-- 5. Initial trending data (sample engagement)
-- =====================================================

-- =====================================================
-- 1. SEASONAL TRANSLATIONS
-- =====================================================

INSERT INTO seasonal_translations (season, language_code, title, subtitle, description, icon_name) VALUES
-- Advent
('advent', 'en', 'Advent Season', 'Prepare your heart for Christmas', 'Explore topics that help you prepare spiritually for celebrating the birth of Christ.', 'card_giftcard'),
('advent', 'hi', 'आगमन का मौसम', 'क्रिसमस के लिए अपना दिल तैयार करें', 'ऐसे विषयों का अन्वेषण करें जो आपको मसीह के जन्म का उत्सव मनाने के लिए आध्यात्मिक रूप से तैयार करने में मदद करें।', 'card_giftcard'),
('advent', 'ml', 'ആഗമന കാലം', 'ക്രിസ്മസിനായി നിങ്ങളുടെ ഹൃദയം ഒരുക്കുക', 'ക്രിസ്തുവിന്റെ ജനനം ആഘോഷിക്കാൻ ആത്മീയമായി തയ്യാറാകാൻ സഹായിക്കുന്ന വിഷയങ്ങൾ പര്യവേക്ഷണം ചെയ്യുക.', 'card_giftcard'),

-- Christmas
('christmas', 'en', 'Christmas', 'Celebrate the birth of Jesus', 'Deepen your understanding and celebration of Christ''s coming into the world.', 'star'),
('christmas', 'hi', 'क्रिसमस', 'यीशु के जन्म का जश्न मनाएं', 'मसीह के दुनिया में आने की अपनी समझ और उत्सव को गहरा करें।', 'star'),
('christmas', 'ml', 'ക്രിസ്മസ്', 'യേശുവിന്റെ ജനനം ആഘോഷിക്കുക', 'ക്രിസ്തു ലോകത്തിലേക്ക് വന്നതിനെക്കുറിച്ചുള്ള നിങ്ങളുടെ ധാരണയും ആഘോഷവും ആഴമാക്കുക.', 'star'),

-- Lent
('lent', 'en', 'Lent', 'A season of reflection and renewal', 'Journey through 40 days of spiritual preparation before Easter.', 'water_drop'),
('lent', 'hi', 'लेंट', 'चिंतन और नवीनीकरण का मौसम', 'ईस्टर से पहले आध्यात्मिक तैयारी के 40 दिनों की यात्रा।', 'water_drop'),
('lent', 'ml', 'നോമ്പുകാലം', 'പ്രതിഫലനത്തിന്റെയും പുതുക്കലിന്റെയും കാലം', 'ഈസ്റ്ററിന് മുമ്പ് 40 ദിവസത്തെ ആത്മീയ തയ്യാറെടുപ്പിലൂടെ യാത്ര ചെയ്യുക.', 'water_drop'),

-- Easter
('easter', 'en', 'Easter', 'Celebrate the resurrection', 'Explore the power and meaning of Christ''s victory over death.', 'brightness_7'),
('easter', 'hi', 'ईस्टर', 'पुनरुत्थान का जश्न मनाएं', 'मृत्यु पर मसीह की विजय की शक्ति और अर्थ का अन्वेषण करें।', 'brightness_7'),
('easter', 'ml', 'ഈസ്റ്റർ', 'ഉയിർത്തെഴുന്നേൽപ്പ് ആഘോഷിക്കുക', 'മരണത്തിന്മേലുള്ള ക്രിസ്തുവിന്റെ വിജയത്തിന്റെ ശക്തിയും അർത്ഥവും പര്യവേക്ഷണം ചെയ്യുക.', 'brightness_7'),

-- New Year
('new_year', 'en', 'New Year', 'Start fresh with God', 'Begin the year with purpose and spiritual intention.', 'celebration'),
('new_year', 'hi', 'नया साल', 'परमेश्वर के साथ नई शुरुआत', 'उद्देश्य और आध्यात्मिक इरादे के साथ वर्ष की शुरुआत करें।', 'celebration'),
('new_year', 'ml', 'പുതുവർഷം', 'ദൈവത്തോടൊപ്പം പുതിയ തുടക്കം', 'ലക്ഷ്യത്തോടും ആത്മീയ ഉദ്ദേശ്യത്തോടും കൂടി വർഷം ആരംഭിക്കുക.', 'celebration')
ON CONFLICT (season, language_code) DO NOTHING;

-- =====================================================
-- 2. SEASONAL TOPIC MAPPINGS
-- =====================================================

-- Advent/Christmas topics (December - early January)
INSERT INTO seasonal_topics (topic_id, season, priority, start_month, end_month, start_day, end_day) VALUES
-- Who is Jesus Christ? - Core Christmas topic
('111e8400-e29b-41d4-a716-446655440001', 'advent', 100, 12, 12, 1, 24),
('111e8400-e29b-41d4-a716-446655440001', 'christmas', 100, 12, 1, 25, 6),
-- What is the Gospel? - Foundation for understanding Christmas
('111e8400-e29b-41d4-a716-446655440002', 'advent', 90, 12, 12, 1, 24),
-- Giving and Generosity - Christmas spirit
('222e8400-e29b-41d4-a716-446655440005', 'christmas', 85, 12, 1, 25, 6),
-- The Importance of Fellowship - Gathering with family
('222e8400-e29b-41d4-a716-446655440004', 'christmas', 80, 12, 1, 25, 6),
-- Worship as a Lifestyle
('555e8400-e29b-41d4-a716-446655440003', 'advent', 75, 12, 12, 1, 24),
-- Unity in Christ - Holiday gatherings
('333e8400-e29b-41d4-a716-446655440004', 'christmas', 70, 12, 1, 25, 6)
ON CONFLICT (topic_id, season) DO NOTHING;

-- New Year topics (late December - January)
INSERT INTO seasonal_topics (topic_id, season, priority, start_month, end_month, start_day, end_day) VALUES
-- Walking with God Daily - New Year resolution
('222e8400-e29b-41d4-a716-446655440001', 'new_year', 100, 12, 1, 26, 31),
-- Daily Devotions - Start the year right
('555e8400-e29b-41d4-a716-446655440001', 'new_year', 95, 12, 1, 26, 31),
-- What is Discipleship?
('444e8400-e29b-41d4-a716-446655440001', 'new_year', 90, 12, 1, 26, 31),
-- Journaling Your Walk with God
('555e8400-e29b-41d4-a716-446655440005', 'new_year', 85, 12, 1, 26, 31),
-- Living a Holy Life
('222e8400-e29b-41d4-a716-446655440006', 'new_year', 80, 12, 1, 26, 31)
ON CONFLICT (topic_id, season) DO NOTHING;

-- =====================================================
-- 3. LIFE SITUATIONS
-- =====================================================

INSERT INTO life_situations (id, slug, icon_name, color_hex, display_order, is_active) VALUES
('a1111111-0000-0000-0000-000000000001', 'going-through-trials', 'healing', '#E57373', 1, TRUE),
('a1111111-0000-0000-0000-000000000002', 'new-believer', 'auto_awesome', '#81C784', 2, TRUE),
('a1111111-0000-0000-0000-000000000003', 'seeking-direction', 'explore', '#64B5F6', 3, TRUE),
('a1111111-0000-0000-0000-000000000004', 'growing-in-prayer', 'self_improvement', '#FFB74D', 4, TRUE),
('a1111111-0000-0000-0000-000000000005', 'family-challenges', 'family_restroom', '#BA68C8', 5, TRUE),
('a1111111-0000-0000-0000-000000000006', 'serving-others', 'volunteer_activism', '#4DB6AC', 6, TRUE),
('a1111111-0000-0000-0000-000000000007', 'doubt-and-questions', 'psychology', '#90A4AE', 7, TRUE),
('a1111111-0000-0000-0000-000000000008', 'workplace-faith', 'work', '#7986CB', 8, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- =====================================================
-- 4. LIFE SITUATION TRANSLATIONS
-- =====================================================

INSERT INTO life_situation_translations (life_situation_id, language_code, title, subtitle, description) VALUES
-- Going through trials
('a1111111-0000-0000-0000-000000000001', 'en', 'Going Through Trials', 'Finding strength in difficult times', 'Topics to help you find hope, comfort, and strength when facing challenges.'),
('a1111111-0000-0000-0000-000000000001', 'hi', 'कठिनाइयों से गुजरना', 'कठिन समय में शक्ति पाना', 'चुनौतियों का सामना करते समय आशा, सुख और शक्ति पाने में मदद करने वाले विषय।'),
('a1111111-0000-0000-0000-000000000001', 'ml', 'പരീക്ഷണങ്ങളിലൂടെ കടന്നുപോകുന്നു', 'ബുദ്ധിമുട്ടുള്ള സമയങ്ങളിൽ ശക്തി കണ്ടെത്തുന്നു', 'വെല്ലുവിളികൾ നേരിടുമ്പോൾ പ്രത്യാശയും ആശ്വാസവും ശക്തിയും കണ്ടെത്താൻ സഹായിക്കുന്ന വിഷയങ്ങൾ.'),

-- New believer
('a1111111-0000-0000-0000-000000000002', 'en', 'New to Faith', 'Starting your journey with Jesus', 'Essential foundations for those beginning their walk with Christ.'),
('a1111111-0000-0000-0000-000000000002', 'hi', 'विश्वास में नया', 'यीशु के साथ अपनी यात्रा शुरू करना', 'मसीह के साथ अपनी यात्रा शुरू करने वालों के लिए आवश्यक आधार।'),
('a1111111-0000-0000-0000-000000000002', 'ml', 'വിശ്വാസത്തിൽ പുതിയത്', 'യേശുവിനോടൊപ്പം നിങ്ങളുടെ യാത്ര ആരംഭിക്കുന്നു', 'ക്രിസ്തുവിനോടൊപ്പം നടക്കാൻ തുടങ്ങുന്നവർക്കുള്ള അവശ്യ അടിസ്ഥാനങ്ങൾ.'),

-- Seeking direction
('a1111111-0000-0000-0000-000000000003', 'en', 'Seeking Direction', 'Finding God''s will for your life', 'Topics to help you discern God''s guidance and make wise decisions.'),
('a1111111-0000-0000-0000-000000000003', 'hi', 'दिशा की तलाश', 'अपने जीवन के लिए परमेश्वर की इच्छा ढूंढना', 'परमेश्वर के मार्गदर्शन को समझने और बुद्धिमानी से निर्णय लेने में मदद करने वाले विषय।'),
('a1111111-0000-0000-0000-000000000003', 'ml', 'ദിശ തേടുന്നു', 'നിങ്ങളുടെ ജീവിതത്തിനായി ദൈവഹിതം കണ്ടെത്തുന്നു', 'ദൈവത്തിന്റെ മാർഗ്ഗനിർദ്ദേശം തിരിച്ചറിയാനും ജ്ഞാനപൂർണ്ണമായ തീരുമാനങ്ങൾ എടുക്കാനും സഹായിക്കുന്ന വിഷയങ്ങൾ.'),

-- Growing in prayer
('a1111111-0000-0000-0000-000000000004', 'en', 'Growing in Prayer', 'Deepening your conversation with God', 'Develop a richer, more meaningful prayer life.'),
('a1111111-0000-0000-0000-000000000004', 'hi', 'प्रार्थना में बढ़ना', 'परमेश्वर के साथ अपनी बातचीत को गहरा करना', 'एक समृद्ध, अधिक सार्थक प्रार्थना जीवन विकसित करें।'),
('a1111111-0000-0000-0000-000000000004', 'ml', 'പ്രാർത്ഥനയിൽ വളരുന്നു', 'ദൈവവുമായുള്ള നിങ്ങളുടെ സംഭാഷണം ആഴമാക്കുന്നു', 'കൂടുതൽ സമ്പന്നവും അർത്ഥവത്തായതുമായ പ്രാർത്ഥനാ ജീവിതം വികസിപ്പിക്കുക.'),

-- Family challenges
('a1111111-0000-0000-0000-000000000005', 'en', 'Family Challenges', 'Building a Christ-centered home', 'Biblical wisdom for navigating family relationships and parenting.'),
('a1111111-0000-0000-0000-000000000005', 'hi', 'पारिवारिक चुनौतियाँ', 'मसीह-केंद्रित घर बनाना', 'पारिवारिक रिश्तों और पालन-पोषण को नेविगेट करने के लिए बाइबिल की बुद्धि।'),
('a1111111-0000-0000-0000-000000000005', 'ml', 'കുടുംബ വെല്ലുവിളികൾ', 'ക്രിസ്തു-കേന്ദ്രീകൃത ഭവനം നിർമ്മിക്കുന്നു', 'കുടുംബ ബന്ധങ്ങളും രക്ഷാകർതൃത്വവും നാവിഗേറ്റ് ചെയ്യുന്നതിനുള്ള ബൈബിൾ ജ്ഞാനം.'),

-- Serving others
('a1111111-0000-0000-0000-000000000006', 'en', 'Called to Serve', 'Making an impact for the Kingdom', 'Discover how to use your gifts to serve God and others.'),
('a1111111-0000-0000-0000-000000000006', 'hi', 'सेवा के लिए बुलाए गए', 'राज्य के लिए प्रभाव डालना', 'जानें कि परमेश्वर और दूसरों की सेवा के लिए अपने उपहारों का उपयोग कैसे करें।'),
('a1111111-0000-0000-0000-000000000006', 'ml', 'സേവിക്കാൻ വിളിക്കപ്പെട്ടു', 'രാജ്യത്തിനായി സ്വാധീനം ചെലുത്തുന്നു', 'ദൈവത്തെയും മറ്റുള്ളവരെയും സേവിക്കാൻ നിങ്ങളുടെ വരങ്ങൾ എങ്ങനെ ഉപയോഗിക്കാമെന്ന് കണ്ടെത്തുക.'),

-- Doubt and questions
('a1111111-0000-0000-0000-000000000007', 'en', 'Doubt & Questions', 'Finding answers to hard questions', 'Explore topics that address common questions and strengthen your faith.'),
('a1111111-0000-0000-0000-000000000007', 'hi', 'संदेह और प्रश्न', 'कठिन सवालों के जवाब खोजना', 'ऐसे विषयों का अन्वेषण करें जो सामान्य प्रश्नों को संबोधित करते हैं और आपके विश्वास को मजबूत करते हैं।'),
('a1111111-0000-0000-0000-000000000007', 'ml', 'സംശയവും ചോദ്യങ്ങളും', 'കഠിനമായ ചോദ്യങ്ങൾക്ക് ഉത്തരം കണ്ടെത്തുന്നു', 'സാധാരണ ചോദ്യങ്ങൾ അഭിസംബോധന ചെയ്യുകയും നിങ്ങളുടെ വിശ്വാസം ശക്തിപ്പെടുത്തുകയും ചെയ്യുന്ന വിഷയങ്ങൾ പര്യവേക്ഷണം ചെയ്യുക.'),

-- Workplace faith
('a1111111-0000-0000-0000-000000000008', 'en', 'Faith at Work', 'Living out your faith professionally', 'Topics for integrating faith into your career and workplace relationships.'),
('a1111111-0000-0000-0000-000000000008', 'hi', 'काम पर विश्वास', 'अपने विश्वास को पेशेवर रूप से जीना', 'अपने करियर और कार्यस्थल के रिश्तों में विश्वास को एकीकृत करने के विषय।'),
('a1111111-0000-0000-0000-000000000008', 'ml', 'ജോലിസ്ഥലത്ത് വിശ്വാസം', 'നിങ്ങളുടെ വിശ്വാസം പ്രൊഫഷണലായി ജീവിക്കുന്നു', 'നിങ്ങളുടെ കരിയറിലും ജോലിസ്ഥല ബന്ധങ്ങളിലും വിശ്വാസം സംയോജിപ്പിക്കുന്നതിനുള്ള വിഷയങ്ങൾ.')
ON CONFLICT (life_situation_id, language_code) DO NOTHING;

-- =====================================================
-- 5. LIFE SITUATION TOPIC MAPPINGS
-- =====================================================

-- Going through trials
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000001', '666e8400-e29b-41d4-a716-446655440005', 100, 1), -- Standing Firm in Persecution
('a1111111-0000-0000-0000-000000000001', '222e8400-e29b-41d4-a716-446655440003', 95, 2),  -- Forgiveness and Reconciliation
('a1111111-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440003', 90, 3),  -- Assurance of Salvation
('a1111111-0000-0000-0000-000000000001', '555e8400-e29b-41d4-a716-446655440002', 85, 4),  -- Fasting and Prayer
('a1111111-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440006', 80, 5)   -- The Role of the Holy Spirit
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- New believer
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000002', '111e8400-e29b-41d4-a716-446655440001', 100, 1), -- Who is Jesus Christ?
('a1111111-0000-0000-0000-000000000002', '111e8400-e29b-41d4-a716-446655440002', 98, 2),  -- What is the Gospel?
('a1111111-0000-0000-0000-000000000002', '111e8400-e29b-41d4-a716-446655440003', 95, 3),  -- Assurance of Salvation
('a1111111-0000-0000-0000-000000000002', '111e8400-e29b-41d4-a716-446655440004', 92, 4),  -- Why Read the Bible?
('a1111111-0000-0000-0000-000000000002', '111e8400-e29b-41d4-a716-446655440005', 90, 5),  -- Importance of Prayer
('a1111111-0000-0000-0000-000000000002', '444e8400-e29b-41d4-a716-446655440001', 85, 6)   -- What is Discipleship?
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- Seeking direction
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000003', '222e8400-e29b-41d4-a716-446655440001', 100, 1), -- Walking with God Daily
('a1111111-0000-0000-0000-000000000003', '111e8400-e29b-41d4-a716-446655440005', 95, 2),  -- Importance of Prayer
('a1111111-0000-0000-0000-000000000003', '555e8400-e29b-41d4-a716-446655440004', 90, 3),  -- Meditation on God's Word
('a1111111-0000-0000-0000-000000000003', '111e8400-e29b-41d4-a716-446655440006', 85, 4),  -- The Role of the Holy Spirit
('a1111111-0000-0000-0000-000000000003', '444e8400-e29b-41d4-a716-446655440002', 80, 5)   -- The Cost of Following Jesus
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- Growing in prayer
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000004', '111e8400-e29b-41d4-a716-446655440005', 100, 1), -- Importance of Prayer
('a1111111-0000-0000-0000-000000000004', '555e8400-e29b-41d4-a716-446655440002', 98, 2),  -- Fasting and Prayer
('a1111111-0000-0000-0000-000000000004', '555e8400-e29b-41d4-a716-446655440001', 95, 3),  -- Daily Devotions
('a1111111-0000-0000-0000-000000000004', '555e8400-e29b-41d4-a716-446655440004', 90, 4),  -- Meditation on God's Word
('a1111111-0000-0000-0000-000000000004', '888e8400-e29b-41d4-a716-446655440005', 85, 5)   -- Praying for the Nations
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- Family challenges
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440001', 100, 1), -- Marriage and Faith
('a1111111-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440002', 98, 2),  -- Raising Children in Christ
('a1111111-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440003', 95, 3),  -- Honoring Parents
('a1111111-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440005', 92, 4),  -- Resolving Conflicts Biblically
('a1111111-0000-0000-0000-000000000005', '222e8400-e29b-41d4-a716-446655440003', 88, 5)   -- Forgiveness and Reconciliation
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- Serving others
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000006', '888e8400-e29b-41d4-a716-446655440003', 100, 1), -- Serving the Poor and Needy
('a1111111-0000-0000-0000-000000000006', '333e8400-e29b-41d4-a716-446655440003', 98, 2),  -- Serving in the Church
('a1111111-0000-0000-0000-000000000006', '333e8400-e29b-41d4-a716-446655440005', 95, 3),  -- Spiritual Gifts and Their Use
('a1111111-0000-0000-0000-000000000006', '444e8400-e29b-41d4-a716-446655440004', 92, 4),  -- The Great Commission
('a1111111-0000-0000-0000-000000000006', '222e8400-e29b-41d4-a716-446655440005', 88, 5)   -- Giving and Generosity
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- Doubt and questions
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000007', '666e8400-e29b-41d4-a716-446655440003', 100, 1), -- Is the Bible Reliable?
('a1111111-0000-0000-0000-000000000007', '666e8400-e29b-41d4-a716-446655440001', 98, 2),  -- Why We Believe in One God
('a1111111-0000-0000-0000-000000000007', '666e8400-e29b-41d4-a716-446655440002', 95, 3),  -- The Uniqueness of Jesus
('a1111111-0000-0000-0000-000000000007', '666e8400-e29b-41d4-a716-446655440004', 92, 4),  -- Responding to Common Questions
('a1111111-0000-0000-0000-000000000007', '111e8400-e29b-41d4-a716-446655440003', 88, 5)   -- Assurance of Salvation
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- Workplace faith
INSERT INTO life_situation_topics (life_situation_id, topic_id, relevance_score, display_order) VALUES
('a1111111-0000-0000-0000-000000000008', '888e8400-e29b-41d4-a716-446655440001', 100, 1), -- Being the Light in Your Community
('a1111111-0000-0000-0000-000000000008', '888e8400-e29b-41d4-a716-446655440002', 95, 2),  -- Sharing Your Testimony
('a1111111-0000-0000-0000-000000000008', '222e8400-e29b-41d4-a716-446655440006', 90, 3),  -- Living a Holy Life
('a1111111-0000-0000-0000-000000000008', '777e8400-e29b-41d4-a716-446655440004', 85, 4),  -- Healthy Friendships
('a1111111-0000-0000-0000-000000000008', '222e8400-e29b-41d4-a716-446655440002', 80, 5)   -- Overcoming Temptation
ON CONFLICT (life_situation_id, topic_id) DO NOTHING;

-- =====================================================
-- 6. INITIAL TRENDING DATA (Sample engagement metrics)
-- =====================================================
-- Seed some initial engagement data to have trending topics work immediately

INSERT INTO topic_engagement_metrics (topic_id, date, study_count, completion_count, save_count, share_count) VALUES
-- Most popular topics (simulated engagement from past week)
('111e8400-e29b-41d4-a716-446655440001', CURRENT_DATE - 1, 45, 28, 15, 8),  -- Who is Jesus Christ?
('111e8400-e29b-41d4-a716-446655440001', CURRENT_DATE - 2, 38, 22, 12, 5),
('111e8400-e29b-41d4-a716-446655440002', CURRENT_DATE - 1, 42, 25, 14, 7),  -- What is the Gospel?
('111e8400-e29b-41d4-a716-446655440002', CURRENT_DATE - 3, 35, 20, 10, 4),
('111e8400-e29b-41d4-a716-446655440005', CURRENT_DATE - 1, 38, 24, 12, 6),  -- Importance of Prayer
('111e8400-e29b-41d4-a716-446655440005', CURRENT_DATE - 2, 32, 18, 10, 3),
('222e8400-e29b-41d4-a716-446655440001', CURRENT_DATE - 1, 35, 22, 11, 5),  -- Walking with God Daily
('555e8400-e29b-41d4-a716-446655440001', CURRENT_DATE - 1, 30, 18, 9, 4),   -- Daily Devotions
('222e8400-e29b-41d4-a716-446655440003', CURRENT_DATE - 1, 28, 16, 8, 3),   -- Forgiveness and Reconciliation
('444e8400-e29b-41d4-a716-446655440001', CURRENT_DATE - 2, 25, 14, 7, 2)    -- What is Discipleship?
ON CONFLICT (topic_id, date) DO NOTHING;
